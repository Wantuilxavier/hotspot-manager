# Hotspot Manager

Sistema de gerenciamento de Hotspot para roteadores **MikroTik** com backend **FreeRADIUS 3** e **MySQL/MariaDB**.

**Repositório:** `https://github.com/Wantuilxavier/hotspot-manager`

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Backend | PHP 8.2+ / Laravel 11 |
| Database | MySQL 8+ / MariaDB 11.4+ |
| RADIUS | FreeRADIUS 3.x |
| Frontend | Blade + Tailwind CSS |
| Integração MikroTik | RADIUS VSA + RouterOS API (opcional) |
| Instalação | Debian 12 (Bookworm) / Debian 13 (Trixie) |

## Funcionalidades

- **Dashboard** — usuários online em tempo real, histórico de autenticações, top consumidores
- **Gestão de Usuários** — CRUD completo com suspensão/reativação e desconexão via API
- **Gestão de Planos** — cria grupos no RADIUS com `Mikrotik-Rate-Limit` automático
- **Captive Portal** — auto-cadastro responsivo, compatível com o redirect do MikroTik
- **Controle de Banda** — queues dinâmicas via atributo VSA `Mikrotik-Rate-Limit`
- **Accounting** — log completo de sessões na tabela `radacct`
- **Expiração automática** — cron marca usuários expirados via `hotspot:expire-users`

## Instalação Automatizada (Recomendada)

Para Debian 12 / 13, execute como root:

```bash
git clone https://github.com/Wantuilxavier/hotspot-manager.git /tmp/hotspot-manager
bash /tmp/hotspot-manager/install.sh
```

O instalador cuida de tudo: PHP 8.2, MariaDB 11.4, FreeRADIUS 3, Nginx, UFW, cron e logrotate.
Ao final exibe as credenciais de acesso e os comandos MikroTik prontos para copiar.

### Atualização

Rodar o mesmo script novamente detecta a instalação existente e executa apenas o update:

```bash
bash install.sh
```

### Desinstalação

```bash
bash uninstall.sh              # Remove aplicação, banco, FreeRADIUS e configs
bash uninstall.sh --purge-packages  # Remove também PHP, MariaDB e Nginx
```

## Instalação Manual (Desenvolvimento)

### 1. Clone e instale dependências

```bash
git clone https://github.com/Wantuilxavier/hotspot-manager.git
cd hotspot-manager
composer install
cp .env.example .env
php artisan key:generate
```

### 2. Configure o banco de dados

Edite `.env`:
```env
DB_HOST=127.0.0.1
DB_DATABASE=radius
DB_USERNAME=radius
DB_PASSWORD=SuaSenhaAqui
```

### 3. Rode as migrations e seeds

```bash
php artisan migrate --seed
# Cria: tabelas RADIUS + planos padrão + admin (admin@hotspot.local / Admin@123)
```

### 4. Configure o FreeRADIUS

```bash
# Copia configs
sudo cp freeradius/mods-available/sql /etc/freeradius/3.0/mods-available/sql
sudo cp freeradius/sites-available/hotspot /etc/freeradius/3.0/sites-available/hotspot
sudo cp freeradius/dictionary.mikrotik /usr/share/freeradius/
echo '$INCLUDE dictionary.mikrotik' | sudo tee -a /usr/share/freeradius/dictionary

# Ativa módulos
sudo ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/
sudo ln -sf /etc/freeradius/3.0/sites-available/hotspot /etc/freeradius/3.0/sites-enabled/
sudo rm -f /etc/freeradius/3.0/sites-enabled/default

# Adiciona MikroTik em clients.conf e edite a senha no módulo SQL
sudo systemctl restart freeradius
```

Ver guia completo: [docs/freeradius-install.md](docs/freeradius-install.md)

### 5. Configure o MikroTik

```routeros
/radius add service=hotspot address=IP_DO_SERVIDOR secret=SEU_SECRET
/ip hotspot profile set [find] use-radius=yes radius-accounting=yes
```

Ver guia completo: [docs/mikrotik-setup.md](docs/mikrotik-setup.md)

### 6. Inicie o servidor

```bash
php artisan serve
# Painel Admin:   http://localhost:8000/admin
# Captive Portal: http://localhost:8000/portal
```

## Estrutura do Projeto

```
hotspot-manager/
├── app/
│   ├── Console/Commands/
│   │   └── ExpireHotspotUsers.php  # Artisan: hotspot:expire-users
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── Admin/          # DashboardController, UserController, PlanController
│   │   │   ├── Auth/           # LoginController
│   │   │   └── Portal/         # CaptivePortalController (auto-cadastro)
│   │   ├── Middleware/         # AdminAuthenticate
│   │   └── Requests/           # Form Requests com validação
│   ├── Models/
│   │   ├── RadCheck.php        # Tabela radcheck (senhas, expiração)
│   │   ├── RadReply.php        # Tabela radreply (Rate-Limit por usuário)
│   │   ├── RadGroupCheck.php   # Tabela radgroupcheck
│   │   ├── RadGroupReply.php   # Tabela radgroupreply (Rate-Limit por grupo/plano)
│   │   ├── RadUserGroup.php    # Tabela radusergroup (usuário → grupo)
│   │   ├── RadAcct.php         # Tabela radacct (sessões/accounting)
│   │   ├── Plan.php            # Planos do Hotspot
│   │   ├── HotspotUser.php     # Dados complementares dos usuários
│   │   └── AdminUser.php       # Administradores do painel
│   └── Services/
│       ├── RadiusService.php   # Toda a lógica de escrita no RADIUS
│       └── MikrotikService.php # API RouterOS (desconexão em tempo real)
├── config/
│   ├── mikrotik.php            # Configurações da API RouterOS
│   └── portal.php              # Configurações do captive portal
├── database/
│   ├── migrations/             # Schema RADIUS + tabelas customizadas
│   └── seeders/                # Planos padrão + admin inicial
├── resources/views/
│   ├── layouts/                # admin.blade.php, portal.blade.php
│   ├── admin/                  # Dashboard, Users, Plans
│   ├── auth/                   # Login
│   └── portal/                 # Register (captive), Success
├── freeradius/
│   ├── mods-available/sql      # Config do módulo SQL
│   ├── sites-available/hotspot # Virtual server
│   └── dictionary.mikrotik     # Atributos VSA MikroTik
├── docs/
│   ├── mikrotik-setup.md       # Comandos RouterOS + fluxo completo
│   └── freeradius-install.md   # Instalação e configuração FreeRADIUS
├── install.sh                  # Instalador/atualizador automático
└── uninstall.sh                # Desinstalador
```

## Como funciona o controle de banda

```
Plano "Premium 20MB" (group_name: premium_20mb)
    │
    ├─► radgroupreply:
    │       groupname  = "premium_20mb"
    │       attribute  = "Mikrotik-Rate-Limit"
    │       value      = "10M/20M"   ← upload/download
    │
    └─► radusergroup:
            username   = "joao.silva"
            groupname  = "premium_20mb"

Quando joao.silva faz login no Hotspot:
  FreeRADIUS → Access-Accept + Mikrotik-Rate-Limit = "10M/20M"
  MikroTik   → cria queue dinâmica: 10Mbps up / 20Mbps down ✓
```

## Cron e Agendamentos

O instalador configura automaticamente:

| Schedule | Comando | Descrição |
|----------|---------|-----------|
| `* * * * *` | `artisan schedule:run` | Laravel Scheduler |
| `0 1 * * *` | `artisan hotspot:expire-users` | Marca usuários expirados |
| `0 3 * * 0` | `DELETE FROM radacct > 90d` | Purga accounting antigo |

## Variáveis de Ambiente Principais

```env
# Banco de dados
DB_DATABASE=radius
DB_USERNAME=radius
DB_PASSWORD=

# FreeRADIUS
RADIUS_SECRET=         # Mesmo valor do clients.conf

# MikroTik (API opcional — para desconexão em tempo real)
MIKROTIK_HOST=192.168.88.1
MIKROTIK_ENABLED=false

# Captive Portal
PORTAL_DEFAULT_PLAN=basic_5mb   # group_name do plano padrão
PORTAL_REQUIRE_PHONE=false      # Exigir telefone no cadastro
```

## Credenciais Padrão

| Recurso | Valor |
|---------|-------|
| Admin email | `admin@hotspot.local` |
| Admin senha | Gerada aleatoriamente pelo install.sh |
| RADIUS secret | Gerado aleatoriamente pelo install.sh |

> As credenciais ficam em `/root/hotspot-manager-credentials.txt` após a instalação.

## Licença

MIT

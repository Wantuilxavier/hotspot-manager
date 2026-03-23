# Hotspot Manager

Sistema de gerenciamento de Hotspot para roteadores **MikroTik** com backend **FreeRADIUS 3** e **MySQL/MariaDB**.

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Backend | PHP 8.2+ / Laravel 11 |
| Database | MySQL 8+ / MariaDB 10.6+ |
| RADIUS | FreeRADIUS 3.x |
| Frontend | Blade + Tailwind CSS |
| Integração MikroTik | RADIUS VSA + RouterOS API (opcional) |

## Funcionalidades

- **Dashboard** — usuários online em tempo real, histórico de autenticações, top consumidores
- **Gestão de Usuários** — CRUD completo com suspensão/reativação e desconexão via API
- **Gestão de Planos** — cria grupos no RADIUS com `Mikrotik-Rate-Limit` automático
- **Captive Portal** — auto-cadastro responsivo, compatível com o redirect do MikroTik
- **Controle de Banda** — queues dinâmicas via atributo VSA `Mikrotik-Rate-Limit`
- **Accounting** — log completo de sessões na tabela `radacct`

## Estrutura do Projeto

```
hotspot-manager/
├── app/
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
└── docs/
    ├── mikrotik-setup.md       # Comandos RouterOS + fluxo completo
    └── freeradius-install.md   # Instalação Ubuntu/Debian
```

## Instalação Rápida

### 1. Clone e instale dependências

```bash
git clone <repo> hotspot-manager
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
# Cria: todas as tabelas RADIUS + planos padrão + admin (admin@hotspot.local / Admin@123)
```

### 4. Configure o FreeRADIUS

```bash
# Copia configs
sudo cp freeradius/mods-available/sql /etc/freeradius/3.0/mods-available/sql
sudo cp freeradius/sites-available/hotspot /etc/freeradius/3.0/sites-available/hotspot
sudo cp freeradius/dictionary.mikrotik /usr/share/freeradius/

# Ativa
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/
sudo ln -s /etc/freeradius/3.0/sites-available/hotspot /etc/freeradius/3.0/sites-enabled/

# Adiciona o MikroTik em clients.conf (veja docs/freeradius-install.md)
sudo systemctl restart freeradius
```

### 5. Configure o MikroTik

```routeros
/radius add service=hotspot address=IP_DO_SERVIDOR secret=testing123
/ip hotspot profile set [find] use-radius=yes radius-accounting=yes
```

Ver guia completo: [docs/mikrotik-setup.md](docs/mikrotik-setup.md)

### 6. Inicie o servidor

```bash
php artisan serve
# Painel Admin:   http://localhost:8000/admin
# Captive Portal: http://localhost:8000/portal
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

## Credenciais Padrão

| Recurso | Valor |
|---------|-------|
| Admin email | `admin@hotspot.local` |
| Admin senha | `Admin@123` |
| RADIUS secret | `testing123` (altere!) |

## Licença

MIT

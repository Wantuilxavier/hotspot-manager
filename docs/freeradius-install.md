# Instalação e Configuração do FreeRADIUS 3

> **Nota:** Para Debian 12/13 use o `install.sh` do projeto — ele automatiza todos os passos abaixo, incluindo geração de senhas seguras e configuração do UFW.

## Instalação Automática (Recomendada)

```bash
bash install.sh
```

## Instalação Manual — Debian 12/13

```bash
# Instala FreeRADIUS + módulo MySQL
sudo apt update
sudo apt install -y freeradius freeradius-mysql freeradius-utils freeradius-common mariadb-server

# Cria banco de dados e usuário
# Substitua 'senha_segura' por uma senha forte
sudo mariadb <<'EOF'
CREATE DATABASE IF NOT EXISTS radius CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE OR REPLACE USER 'radius'@'localhost'  IDENTIFIED BY 'senha_segura';
CREATE OR REPLACE USER 'radius'@'127.0.0.1' IDENTIFIED BY 'senha_segura';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

# Roda as migrations do Laravel (cria todas as tabelas RADIUS + hotspot_users + plans)
cd /var/www/hotspot-manager
php artisan migrate --seed

# Instala o dicionário MikroTik
sudo cp freeradius/dictionary.mikrotik /usr/share/freeradius/dictionary.mikrotik
grep -q "dictionary.mikrotik" /usr/share/freeradius/dictionary \
    || echo '$INCLUDE dictionary.mikrotik' | sudo tee -a /usr/share/freeradius/dictionary

# Configura o módulo SQL (ajuste login/password/radius_db se necessário)
sudo cp freeradius/mods-available/sql /etc/freeradius/3.0/mods-available/sql
sudo sed -i "s|password = \"[^\"]*\"|password = \"senha_segura\"|g" \
    /etc/freeradius/3.0/mods-available/sql

# Ativa o módulo SQL
sudo ln -sf /etc/freeradius/3.0/mods-available/sql \
            /etc/freeradius/3.0/mods-enabled/sql

# Habilita módulos necessários
for mod in preprocess pap chap acct_unique attr_filter; do
    sudo ln -sf /etc/freeradius/3.0/mods-available/${mod} \
                /etc/freeradius/3.0/mods-enabled/${mod} 2>/dev/null || true
done

# Configura o virtual server hotspot
sudo cp freeradius/sites-available/hotspot /etc/freeradius/3.0/sites-available/hotspot
sudo ln -sf /etc/freeradius/3.0/sites-available/hotspot \
            /etc/freeradius/3.0/sites-enabled/hotspot

# Desabilita o site 'default' (evita conflito de porta com 'hotspot')
sudo rm -f /etc/freeradius/3.0/sites-enabled/default

# Adiciona o MikroTik como cliente autorizado
# Substitua 192.168.88.1 pelo IP do seu MikroTik
# Substitua 'seu_secret_seguro' pelo mesmo valor usado em /radius add no RouterOS
sudo tee -a /etc/freeradius/3.0/clients.conf <<'EOF'

client mikrotik_hotspot {
    ipaddr    = 192.168.88.1
    secret    = seu_secret_seguro
    shortname = mikrotik
    nastype   = other
    require_message_authenticator = no
}
EOF

# Ajusta permissões
sudo chown -R freerad:freerad /etc/freeradius/3.0

# Valida a configuração antes de iniciar
sudo freeradius -XC

# Inicia o serviço
sudo systemctl enable --now freeradius
sudo systemctl status freeradius
```

## Verificação Rápida

```bash
# Testa com um usuário criado pelo Hotspot Manager
# Substitua 'seu_secret_seguro' pelo RADIUS_SECRET configurado
radtest joao.silva senha123 127.0.0.1 0 seu_secret_seguro

# Resposta esperada:
# Received Access-Accept Id 1 from 127.0.0.1:1812 to ...
#   Mikrotik-Rate-Limit = "2M/5M"
```

## Problemas Comuns

### FreeRADIUS não inicia no Debian 13

```bash
# O ExecStartPre pode falhar com exit code 1 mesmo quando a config está correta.
# Solução: override do service
sudo mkdir -p /etc/systemd/system/freeradius.service.d/
echo -e '[Service]\nExecStartPre=' | sudo tee /etc/systemd/system/freeradius.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart freeradius
```

### Estrutura de /etc/freeradius incompleta

```bash
# Se mods-available/ ou radiusd.conf estiverem ausentes (dpkg conffile state):
sudo apt-get purge -y "freeradius*"
sudo apt-get install -y freeradius freeradius-mysql freeradius-utils freeradius-common
```

### Teste de conexão com o banco

```bash
# Verifica se FreeRADIUS consegue conectar ao MariaDB via TCP
mariadb -u radius -p'senha_segura' -h 127.0.0.1 --protocol=tcp radius \
    -e "SELECT COUNT(*) FROM radcheck;"
```

### Logs do FreeRADIUS

```bash
# Modo debug (verbose — pare o serviço antes)
sudo systemctl stop freeradius
sudo freeradius -X

# Via journalctl (serviço rodando)
sudo journalctl -u freeradius -f
```

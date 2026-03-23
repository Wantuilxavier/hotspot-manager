# Instalação e Configuração do FreeRADIUS 3

## Ubuntu/Debian

```bash
# Instala FreeRADIUS + módulo MySQL
sudo apt update
sudo apt install -y freeradius freeradius-mysql mariadb-server

# Cria banco de dados e usuário
sudo mysql -u root <<'EOF'
CREATE DATABASE IF NOT EXISTS radius CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'radius'@'localhost' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
FLUSH PRIVILEGES;
EOF

# Roda as migrations do Laravel (cria todas as tabelas)
cd /var/www/hotspot-manager
php artisan migrate --seed

# Instala o dicionário MikroTik
sudo cp freeradius/dictionary.mikrotik /usr/share/freeradius/dictionary.mikrotik

# Adiciona ao dicionário principal (se não existir)
grep -q "dictionary.mikrotik" /usr/share/freeradius/dictionary || \
    echo '$INCLUDE dictionary.mikrotik' | sudo tee -a /usr/share/freeradius/dictionary

# Configura o módulo SQL
sudo cp freeradius/mods-available/sql /etc/freeradius/3.0/mods-available/sql
# Edite /etc/freeradius/3.0/mods-available/sql e ajuste: login, password, radius_db

# Ativa o módulo SQL
sudo ln -sf /etc/freeradius/3.0/mods-available/sql \
            /etc/freeradius/3.0/mods-enabled/sql

# Configura o virtual server
sudo cp freeradius/sites-available/hotspot /etc/freeradius/3.0/sites-available/hotspot
sudo ln -sf /etc/freeradius/3.0/sites-available/hotspot \
            /etc/freeradius/3.0/sites-enabled/hotspot

# Desabilita o site default (opcional, se usar apenas o hotspot)
# sudo rm /etc/freeradius/3.0/sites-enabled/default

# Adiciona o MikroTik como cliente
sudo tee -a /etc/freeradius/3.0/clients.conf <<'EOF'

client mikrotik {
    ipaddr    = 192.168.88.1   # IP do seu MikroTik
    secret    = testing123      # Mesmo do /radius add no RouterOS
    shortname = mikrotik
    nastype   = other
}
EOF

# Testa a configuração
sudo freeradius -XC

# Inicia o serviço
sudo systemctl enable --now freeradius
sudo systemctl status freeradius
```

## CentOS/RHEL/Rocky Linux

```bash
sudo dnf install -y freeradius freeradius-mysql mariadb-server
sudo systemctl enable --now mariadb
# ...mesmos passos acima
```

## Verificação rápida

```bash
# Testa com um usuário criado pelo Hotspot Manager
radtest joao.silva senha123 127.0.0.1 0 testing123

# Resposta esperada:
# Received Access-Accept Id 1 from 127.0.0.1:1812 to ...
#   Mikrotik-Rate-Limit = "2M/5M"
```

#!/usr/bin/env bash
# ==============================================================================
#  Hotspot Manager — Script de Instalação Completa
#  Alvo: Debian 13 (Trixie) / Debian 12 (Bookworm)
#  Autor: Hotspot Manager
#  Uso:   sudo bash install.sh
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Cores ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Helpers ────────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERRO]${NC}  $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}"; }
ask()     { echo -e "${YELLOW}[?]${NC} $*"; }

# ── Banner ─────────────────────────────────────────────────────────────────────
banner() {
cat << 'EOF'

  ██╗  ██╗ ██████╗ ████████╗███████╗██████╗  ██████╗ ████████╗
  ██║  ██║██╔═══██╗╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝
  ███████║██║   ██║   ██║   ███████╗██████╔╝██║   ██║   ██║
  ██╔══██║██║   ██║   ██║   ╚════██║██╔═══╝ ██║   ██║   ██║
  ██║  ██║╚██████╔╝   ██║   ███████║██║     ╚██████╔╝   ██║
  ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝╚═╝      ╚═════╝    ╚═╝
            MikroTik Hotspot Manager — Instalador v1.0
              Debian 13 (Trixie) / Debian 12 (Bookworm)

EOF
}

# ══════════════════════════════════════════════════════════════════════════════
# VERIFICAÇÕES INICIAIS
# ══════════════════════════════════════════════════════════════════════════════
check_root() {
    [[ $EUID -eq 0 ]] || error "Execute como root: sudo bash $0"
}

check_os() {
    if [[ ! -f /etc/debian_version ]]; then
        error "Sistema não suportado. Este script requer Debian 12 ou 13."
    fi
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
    info "Debian detectado: versão $DEBIAN_VERSION ($(lsb_release -cs 2>/dev/null || echo 'unknown'))"
    if [[ "$DEBIAN_VERSION" -lt 12 ]]; then
        error "Requer Debian 12 (Bookworm) ou superior."
    fi
}

check_internet() {
    info "Verificando conexão com a internet..."
    curl -s --max-time 5 https://packages.debian.org > /dev/null \
        || error "Sem acesso à internet. Verifique a conectividade."
    success "Internet disponível."
}

# ══════════════════════════════════════════════════════════════════════════════
# COLETA DE CONFIGURAÇÕES
# ══════════════════════════════════════════════════════════════════════════════
collect_config() {
    step "Configuração da Instalação"

    # Diretório de instalação
    ask "Diretório de instalação [/var/www/hotspot-manager]:"
    read -r INSTALL_DIR
    INSTALL_DIR="${INSTALL_DIR:-/var/www/hotspot-manager}"

    # Domínio / IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    ask "Domínio ou IP do servidor [$SERVER_IP]:"
    read -r APP_HOST
    APP_HOST="${APP_HOST:-$SERVER_IP}"

    # Banco de dados
    ask "Senha do usuário RADIUS no MySQL [gera automático]:"
    read -rs DB_PASS
    DB_PASS="${DB_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)}"
    echo ""

    ask "Senha root do MySQL [gera automático]:"
    read -rs MYSQL_ROOT_PASS
    MYSQL_ROOT_PASS="${MYSQL_ROOT_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)}"
    echo ""

    # RADIUS Secret
    ask "RADIUS Shared Secret [gera automático]:"
    read -r RADIUS_SECRET
    RADIUS_SECRET="${RADIUS_SECRET:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 28)}"

    # IP do MikroTik
    ask "IP do roteador MikroTik [192.168.88.1]:"
    read -r MIKROTIK_IP
    MIKROTIK_IP="${MIKROTIK_IP:-192.168.88.1}"

    # Web server
    ask "Web server — (1) Nginx  (2) Apache2  [1]:"
    read -r WEB_CHOICE
    WEB_CHOICE="${WEB_CHOICE:-1}"
    [[ "$WEB_CHOICE" == "2" ]] && WEB_SERVER="apache2" || WEB_SERVER="nginx"

    # Senha do admin
    ADMIN_EMAIL="admin@hotspot.local"
    ask "Senha do administrador do painel [Admin@123]:"
    read -rs ADMIN_PASS
    ADMIN_PASS="${ADMIN_PASS:-Admin@123}"
    echo ""

    echo ""
    echo -e "${BOLD}┌─────────────────────────────────────────┐"
    echo -e "│         Resumo da Instalação            │"
    echo -e "├─────────────────────────────────────────┤"
    echo -e "│ Diretório : ${INSTALL_DIR}"
    echo -e "│ Host/IP   : ${APP_HOST}"
    echo -e "│ DB user   : radius / ***"
    echo -e "│ RADIUS    : secret configurado"
    echo -e "│ MikroTik  : ${MIKROTIK_IP}"
    echo -e "│ Web server: ${WEB_SERVER}"
    echo -e "│ Admin     : ${ADMIN_EMAIL}"
    echo -e "└─────────────────────────────────────────┘${NC}"
    echo ""
    ask "Confirmar e iniciar instalação? [s/N]:"
    read -r CONFIRM
    [[ "${CONFIRM,,}" == "s" ]] || { info "Instalação cancelada."; exit 0; }
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 1 — ATUALIZAÇÃO DO SISTEMA
# ══════════════════════════════════════════════════════════════════════════════
update_system() {
    step "1/9 — Atualizando o sistema"
    apt-get update -qq
    apt-get upgrade -y -qq
    apt-get install -y -qq \
        curl wget git unzip gnupg2 lsb-release ca-certificates \
        software-properties-common apt-transport-https \
        openssl ufw logrotate cron
    success "Sistema atualizado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 2 — PHP 8.2
# ══════════════════════════════════════════════════════════════════════════════
install_php() {
    step "2/9 — Instalando PHP 8.2+"

    # Adiciona repositório Sury (PHP moderno no Debian)
    if ! apt-cache show php8.2 &>/dev/null 2>&1; then
        curl -sSL https://packages.sury.org/php/apt.gpg \
            | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
        echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" \
            > /etc/apt/sources.list.d/sury-php.list
        apt-get update -qq
    fi

    apt-get install -y -qq \
        php8.2 php8.2-fpm php8.2-cli php8.2-common \
        php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl \
        php8.2-zip php8.2-bcmath php8.2-intl php8.2-gd \
        php8.2-tokenizer php8.2-pdo php8.2-readline

    PHP_VERSION=$(php -r 'echo PHP_VERSION;')
    success "PHP $PHP_VERSION instalado."

    # Configurações otimizadas para produção
    PHP_INI="/etc/php/8.2/fpm/php.ini"
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 20M/'   "$PHP_INI"
    sed -i 's/^post_max_size.*/post_max_size = 25M/'               "$PHP_INI"
    sed -i 's/^memory_limit.*/memory_limit = 256M/'                "$PHP_INI"
    sed -i 's/^max_execution_time.*/max_execution_time = 60/'       "$PHP_INI"
    sed -i 's/^expose_php.*/expose_php = Off/'                      "$PHP_INI"

    systemctl enable --now php8.2-fpm
    success "PHP-FPM configurado e iniciado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 3 — COMPOSER
# ══════════════════════════════════════════════════════════════════════════════
install_composer() {
    step "3/9 — Instalando Composer"
    if command -v composer &>/dev/null; then
        COMPOSER_VER=$(composer --version --no-ansi | awk '{print $3}')
        info "Composer $COMPOSER_VER já instalado."
        return
    fi

    EXPECTED_CHECKSUM="$(curl -sS https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"

    [[ "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]] \
        || error "Checksum do Composer inválido. Abortando por segurança."

    php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    rm /tmp/composer-setup.php
    success "Composer $(composer --version --no-ansi | awk '{print $3}') instalado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 4 — MARIADB
# ══════════════════════════════════════════════════════════════════════════════
install_mariadb() {
    step "4/9 — Instalando MariaDB"

    # Repositório oficial MariaDB 11.x (LTS)
    if ! apt-cache show mariadb-server &>/dev/null || \
       [[ "$(mariadb --version 2>/dev/null | grep -oP '[\d]+\.[\d]+' | head -1 || echo '0.0')" < "10.6" ]]; then
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup \
            | bash -s -- --mariadb-server-version="mariadb-11.4" --skip-maxscale
        apt-get update -qq
    fi

    apt-get install -y -qq mariadb-server mariadb-client

    systemctl enable --now mariadb
    success "MariaDB instalado e iniciado."

    # Segurança: define senha root e remove anônimos
    mariadb -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    success "MariaDB configurado e seguro."

    # Cria banco e usuário RADIUS
    mariadb -u root -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS radius
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'radius'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
FLUSH PRIVILEGES;
EOF
    success "Banco 'radius' e usuário criados."

    # Salva credenciais
    cat > /root/.hotspot_db_credentials <<EOF
# Hotspot Manager — Credenciais do Banco de Dados
# Geradas em: $(date)
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS}
DB_PASS=${DB_PASS}
EOF
    chmod 600 /root/.hotspot_db_credentials
    info "Credenciais do banco salvas em /root/.hotspot_db_credentials"
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 5 — FREERADIUS 3
# ══════════════════════════════════════════════════════════════════════════════
install_freeradius() {
    step "5/9 — Instalando FreeRADIUS 3"

    apt-get install -y -qq \
        freeradius freeradius-mysql freeradius-utils \
        freeradius-common

    FR_VERSION=$(freeradius -v 2>&1 | head -1 | grep -oP '[\d]+\.[\d]+\.[\d]+' || echo '3.x')
    success "FreeRADIUS $FR_VERSION instalado."

    FR_DIR="/etc/freeradius/3.0"

    # ── Dicionário MikroTik ────────────────────────────────────────────────
    cp "${INSTALL_DIR}/freeradius/dictionary.mikrotik" /usr/share/freeradius/dictionary.mikrotik
    grep -q "dictionary.mikrotik" /usr/share/freeradius/dictionary \
        || echo '$INCLUDE dictionary.mikrotik' >> /usr/share/freeradius/dictionary
    success "Dicionário MikroTik instalado."

    # ── Módulo SQL ─────────────────────────────────────────────────────────
    cp "${INSTALL_DIR}/freeradius/mods-available/sql" "${FR_DIR}/mods-available/sql"
    # Substitui credenciais no arquivo
    sed -i "s|password = \"secret\"|password = \"${DB_PASS}\"|g"  "${FR_DIR}/mods-available/sql"
    sed -i "s|radius_db = \"radius\"|radius_db = \"radius\"|g"     "${FR_DIR}/mods-available/sql"

    ln -sf "${FR_DIR}/mods-available/sql" "${FR_DIR}/mods-enabled/sql" 2>/dev/null || true
    success "Módulo SQL configurado e ativado."

    # ── Virtual Server ─────────────────────────────────────────────────────
    cp "${INSTALL_DIR}/freeradius/sites-available/hotspot" "${FR_DIR}/sites-available/hotspot"
    ln -sf "${FR_DIR}/sites-available/hotspot" "${FR_DIR}/sites-enabled/hotspot" 2>/dev/null || true

    # Desativa o site 'default' para evitar conflito (opcional)
    # rm -f "${FR_DIR}/sites-enabled/default"
    success "Virtual server 'hotspot' ativado."

    # ── clients.conf — Adiciona o MikroTik ────────────────────────────────
    CLIENTS_CONF="${FR_DIR}/clients.conf"
    if ! grep -q "client mikrotik" "$CLIENTS_CONF"; then
        cat >> "$CLIENTS_CONF" <<EOF

# MikroTik Hotspot — adicionado pelo instalador Hotspot Manager
client mikrotik_hotspot {
    ipaddr    = ${MIKROTIK_IP}
    secret    = ${RADIUS_SECRET}
    shortname = mikrotik
    nastype   = other
    require_message_authenticator = no
}

# Permite testes locais com radtest
client localhost_test {
    ipaddr    = 127.0.0.1
    secret    = ${RADIUS_SECRET}
    shortname = localhost
}
EOF
        success "MikroTik adicionado ao clients.conf."
    fi

    # ── Permissões ─────────────────────────────────────────────────────────
    chown -R freerad:freerad "${FR_DIR}"

    # ── Habilita e testa ────────────────────────────────────────────────────
    systemctl enable freeradius

    # Teste de configuração antes de iniciar
    if freeradius -C 2>&1 | grep -q "ERROR"; then
        warn "FreeRADIUS detectou erros de configuração. Execute: freeradius -X para debug."
    else
        systemctl restart freeradius
        success "FreeRADIUS iniciado com sucesso."
    fi

    # Salva o RADIUS secret
    cat > /root/.hotspot_radius_credentials <<EOF
# Hotspot Manager — Credenciais RADIUS
# Geradas em: $(date)
RADIUS_SECRET=${RADIUS_SECRET}
MIKROTIK_IP=${MIKROTIK_IP}

# Adicionar no MikroTik:
# /radius add service=hotspot address=SEU_IP_SERVIDOR secret=${RADIUS_SECRET}
EOF
    chmod 600 /root/.hotspot_radius_credentials
    info "RADIUS secret salvo em /root/.hotspot_radius_credentials"
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 6 — APLICAÇÃO LARAVEL
# ══════════════════════════════════════════════════════════════════════════════
install_app() {
    step "6/9 — Instalando a aplicação Laravel"

    # Cria diretório e copia arquivos
    mkdir -p "$INSTALL_DIR"

    # Se o script está sendo executado dentro do repositório clonado
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
        info "Copiando arquivos para ${INSTALL_DIR}..."
        rsync -a --exclude='.git' --exclude='node_modules' --exclude='vendor' \
            "${SCRIPT_DIR}/" "${INSTALL_DIR}/"
    fi

    cd "$INSTALL_DIR"

    # ── .env ────────────────────────────────────────────────────────────────
    cp .env.example .env
    cat > .env <<EOF
APP_NAME="Hotspot Manager"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://${APP_HOST}
APP_TIMEZONE=America/Sao_Paulo

LOG_CHANNEL=daily
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=warning

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=radius
DB_USERNAME=radius
DB_PASSWORD=${DB_PASS}

RADIUS_SECRET=${RADIUS_SECRET}
RADIUS_HOST=127.0.0.1
RADIUS_PORT=1812

MIKROTIK_HOST=${MIKROTIK_IP}
MIKROTIK_USER=admin
MIKROTIK_PASS=
MIKROTIK_PORT=8728
MIKROTIK_ENABLED=false

PORTAL_DEFAULT_PLAN=basic_5mb
PORTAL_REQUIRE_PHONE=false

SESSION_DRIVER=file
SESSION_LIFETIME=120
CACHE_STORE=file
QUEUE_CONNECTION=sync

MAIL_MAILER=log
MAIL_FROM_ADDRESS="hotspot@${APP_HOST}"
MAIL_FROM_NAME="Hotspot Manager"
EOF

    # ── Composer ────────────────────────────────────────────────────────────
    info "Instalando dependências PHP (Composer)..."
    composer install --no-dev --optimize-autoloader --no-interaction --quiet
    success "Dependências instaladas."

    # ── Chave da aplicação ──────────────────────────────────────────────────
    php artisan key:generate --ansi --force
    success "APP_KEY gerada."

    # ── Migrations e Seeders ────────────────────────────────────────────────
    info "Executando migrations (criando tabelas RADIUS)..."
    php artisan migrate --force --ansi
    success "Tabelas criadas no banco 'radius'."

    info "Executando seeders (planos padrão + admin)..."
    php artisan db:seed --force --ansi
    success "Dados iniciais inseridos."

    # Atualiza senha do admin se foi customizada
    if [[ "$ADMIN_PASS" != "Admin@123" ]]; then
        php artisan tinker --execute="
            \App\Models\AdminUser::where('email', 'admin@hotspot.local')
                ->update(['password' => bcrypt('${ADMIN_PASS}')]);
            echo 'Senha do admin atualizada.';
        " 2>/dev/null || warn "Não foi possível atualizar senha via tinker."
    fi

    # ── Otimizações de produção ─────────────────────────────────────────────
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    success "Cache de configuração/rotas/views gerado."

    # ── Permissões ─────────────────────────────────────────────────────────
    chown -R www-data:www-data "$INSTALL_DIR"
    find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
    find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
    chmod -R 775 "${INSTALL_DIR}/storage" "${INSTALL_DIR}/bootstrap/cache"
    success "Permissões configuradas."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 7 — WEB SERVER (NGINX ou APACHE)
# ══════════════════════════════════════════════════════════════════════════════
install_webserver() {
    step "7/9 — Configurando ${WEB_SERVER}"

    if [[ "$WEB_SERVER" == "nginx" ]]; then
        install_nginx
    else
        install_apache
    fi
}

install_nginx() {
    apt-get install -y -qq nginx

    cat > /etc/nginx/sites-available/hotspot-manager <<EOF
# Hotspot Manager — configuração Nginx
# Gerado pelo instalador em $(date)

server {
    listen 80;
    listen [::]:80;

    server_name ${APP_HOST};
    root ${INSTALL_DIR}/public;
    index index.php;

    # Segurança
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    server_tokens off;

    # Logs
    access_log /var/log/nginx/hotspot-manager.access.log;
    error_log  /var/log/nginx/hotspot-manager.error.log;

    # Laravel — todas as rotas para index.php
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP-FPM
    location ~ \.php$ {
        fastcgi_pass   unix:/run/php/php8.2-fpm.sock;
        fastcgi_param  SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    # Bloqueia acesso a arquivos ocultos
    location ~ /\. {
        deny all;
    }

    # Cache de assets estáticos
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|woff|woff2|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Limite de tamanho de upload
    client_max_body_size 25M;
}
EOF

    # Ativa o site
    ln -sf /etc/nginx/sites-available/hotspot-manager \
           /etc/nginx/sites-enabled/hotspot-manager
    rm -f /etc/nginx/sites-enabled/default

    nginx -t && systemctl enable --now nginx && systemctl reload nginx
    success "Nginx configurado e iniciado."
}

install_apache() {
    apt-get install -y -qq apache2 libapache2-mod-php8.2

    a2enmod rewrite php8.2 headers

    cat > /etc/apache2/sites-available/hotspot-manager.conf <<EOF
# Hotspot Manager — configuração Apache2
# Gerado pelo instalador em $(date)

<VirtualHost *:80>
    ServerName  ${APP_HOST}
    DocumentRoot ${INSTALL_DIR}/public

    <Directory ${INSTALL_DIR}/public>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>

    # Segurança
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    ServerTokens Prod
    ServerSignature Off

    ErrorLog  \${APACHE_LOG_DIR}/hotspot-manager.error.log
    CustomLog \${APACHE_LOG_DIR}/hotspot-manager.access.log combined
</VirtualHost>
EOF

    a2ensite hotspot-manager.conf
    a2dissite 000-default.conf 2>/dev/null || true
    apache2ctl configtest && systemctl enable --now apache2 && systemctl reload apache2
    success "Apache2 configurado e iniciado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 8 — FIREWALL (UFW)
# ══════════════════════════════════════════════════════════════════════════════
configure_firewall() {
    step "8/9 — Configurando Firewall (UFW)"

    ufw --force reset

    # Regras padrão
    ufw default deny incoming
    ufw default allow outgoing

    # SSH (não perder acesso!)
    ufw allow 22/tcp comment "SSH"

    # Web
    ufw allow 80/tcp  comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"

    # RADIUS — apenas do MikroTik
    ufw allow from "${MIKROTIK_IP}" to any port 1812 proto udp comment "RADIUS Auth (MikroTik)"
    ufw allow from "${MIKROTIK_IP}" to any port 1813 proto udp comment "RADIUS Acct (MikroTik)"

    # RADIUS localhost (para radtest)
    ufw allow from 127.0.0.1 to any port 1812 proto udp comment "RADIUS Auth local"
    ufw allow from 127.0.0.1 to any port 1813 proto udp comment "RADIUS Acct local"

    ufw --force enable
    success "Firewall configurado."
    ufw status numbered
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 9 — CRON (expiração de usuários)
# ══════════════════════════════════════════════════════════════════════════════
configure_cron() {
    step "9/9 — Configurando Cron (tarefas agendadas)"

    CRON_FILE="/etc/cron.d/hotspot-manager"
    cat > "$CRON_FILE" <<EOF
# Hotspot Manager — tarefas agendadas
# Gerado em: $(date)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Scheduler do Laravel (executa a cada minuto)
* * * * * www-data cd ${INSTALL_DIR} && php artisan schedule:run >> /dev/null 2>&1

# Expira usuários com vencimento passado (diariamente às 01:00)
0 1 * * * www-data cd ${INSTALL_DIR} && php artisan hotspot:expire-users >> /dev/null 2>&1

# Limpeza de sessões antigas do FreeRADIUS (semanal)
0 3 * * 0 root mariadb -u radius -p'${DB_PASS}' radius -e \
  "DELETE FROM radacct WHERE acctstoptime < DATE_SUB(NOW(), INTERVAL 90 DAY);" \
  >> /dev/null 2>&1
EOF

    chmod 644 "$CRON_FILE"
    service cron restart 2>/dev/null || systemctl restart cron 2>/dev/null || true
    success "Cron configurado."
}

# ══════════════════════════════════════════════════════════════════════════════
# LOGROTATE
# ══════════════════════════════════════════════════════════════════════════════
configure_logrotate() {
    cat > /etc/logrotate.d/hotspot-manager <<EOF
${INSTALL_DIR}/storage/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        /usr/bin/find ${INSTALL_DIR}/storage/logs -name "*.log" \
            -mtime +30 -delete 2>/dev/null || true
    endscript
}
EOF
    success "Logrotate configurado."
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO FINAL
# ══════════════════════════════════════════════════════════════════════════════
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          INSTALAÇÃO CONCLUÍDA COM SUCESSO!                   ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Painel Admin:    ${BOLD}http://${APP_HOST}/admin${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Captive Portal:  ${BOLD}http://${APP_HOST}/portal${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  E-mail admin:    ${BOLD}${ADMIN_EMAIL}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Senha admin:     ${BOLD}${ADMIN_PASS}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  RADIUS Secret:   ${BOLD}${RADIUS_SECRET}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Próximos passos no MikroTik:                               ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo ""
    echo "  /radius add \\"
    echo "      service=hotspot \\"
    echo "      address=$(hostname -I | awk '{print $1}') \\"
    echo "      secret=${RADIUS_SECRET} \\"
    echo "      authentication-port=1812 \\"
    echo "      accounting-port=1813"
    echo ""
    echo "  /ip hotspot profile set [find] \\"
    echo "      use-radius=yes \\"
    echo "      radius-accounting=yes"
    echo ""
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Credenciais salvas em:                                      ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo "  /root/.hotspot_db_credentials     (banco de dados)"
    echo "  /root/.hotspot_radius_credentials (RADIUS secret)"
    echo ""
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Testar autenticação RADIUS:                                 ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo "  radtest admin_user senha_usuario 127.0.0.1 0 ${RADIUS_SECRET}"
    echo ""
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Logs úteis:                                                 ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo "  journalctl -u freeradius -f          # RADIUS em tempo real"
    echo "  journalctl -u ${WEB_SERVER} -f             # Web server"
    echo "  tail -f ${INSTALL_DIR}/storage/logs/laravel.log"
    echo ""
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    warn "ATENÇÃO: Altere a senha padrão do admin imediatamente após o primeiro login!"
}

# ══════════════════════════════════════════════════════════════════════════════
# TRATAMENTO DE ERROS
# ══════════════════════════════════════════════════════════════════════════════
cleanup_on_error() {
    error "A instalação falhou na etapa anterior. Verifique os logs acima."
}
trap cleanup_on_error ERR

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    banner
    check_root
    check_os
    check_internet
    collect_config

    # Salva log completo da instalação
    LOG_FILE="/var/log/hotspot-manager-install.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "Log completo em: $LOG_FILE"

    update_system
    install_php
    install_composer
    install_mariadb
    install_app          # Deve vir antes do FreeRADIUS para copiar os arquivos de config
    install_freeradius
    install_webserver
    configure_firewall
    configure_cron
    configure_logrotate

    print_summary
}

main "$@"

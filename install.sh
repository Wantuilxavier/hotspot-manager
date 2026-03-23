#!/usr/bin/env bash
# ==============================================================================
#  Hotspot Manager — Script de Instalação Completa
#  Alvo  : Debian 13 (Trixie) / Debian 12 (Bookworm)
#  Uso   : bash install.sh          (execute como root)
#  Repo  : https://github.com/Wantuilxavier/hotspot-manager
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
ask()     { echo -e -n "${YELLOW}[?]${NC} $* "; }

banner() {
cat << 'EOF'

  ██╗  ██╗ ██████╗ ████████╗███████╗██████╗  ██████╗ ████████╗
  ██║  ██║██╔═══██╗╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝
  ███████║██║   ██║   ██║   ███████╗██████╔╝██║   ██║   ██║
  ██╔══██║██║   ██║   ██║   ╚════██║██╔═══╝ ██║   ██║   ██║
  ██║  ██║╚██████╔╝   ██║   ███████║██║     ╚██████╔╝   ██║
  ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝╚═╝      ╚═════╝    ╚═╝
            MikroTik Hotspot Manager — Instalador v1.1
              Debian 13 (Trixie) / Debian 12 (Bookworm)
              Execução como root  |  github.com/Wantuilxavier

EOF
}

# ══════════════════════════════════════════════════════════════════════════════
# VERIFICAÇÕES INICIAIS
# ══════════════════════════════════════════════════════════════════════════════
check_root() {
    [[ $EUID -eq 0 ]] || error "Este script deve ser executado como root. Use: bash $0"
}

check_os() {
    [[ -f /etc/debian_version ]] \
        || error "Sistema não suportado. Requer Debian 12 (Bookworm) ou 13 (Trixie)."

    DEBIAN_VERSION=$(cut -d. -f1 /etc/debian_version)
    OS_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
    info "Debian ${DEBIAN_VERSION} (${OS_CODENAME}) detectado."

    [[ "$DEBIAN_VERSION" -ge 12 ]] \
        || error "Requer Debian 12 ou superior. Versão atual: ${DEBIAN_VERSION}."
}

check_internet() {
    info "Verificando conexão com a internet..."
    curl -sf --max-time 8 https://deb.debian.org > /dev/null \
        || error "Sem acesso à internet. Verifique a conectividade."
    success "Internet disponível."
}

# ══════════════════════════════════════════════════════════════════════════════
# COLETA DE CONFIGURAÇÕES
# ══════════════════════════════════════════════════════════════════════════════
collect_config() {
    step "Configuração Interativa"

    # Diretório de instalação
    ask "Diretório de instalação [/var/www/hotspot-manager]:"
    read -r INSTALL_DIR
    INSTALL_DIR="${INSTALL_DIR:-/var/www/hotspot-manager}"

    # Domínio / IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    ask "Domínio ou IP público do servidor [${SERVER_IP}]:"
    read -r APP_HOST
    APP_HOST="${APP_HOST:-$SERVER_IP}"

    # Porta do web server
    ask "Porta HTTP [80]:"
    read -r APP_PORT
    APP_PORT="${APP_PORT:-80}"

    # Banco de dados
    ask "Senha do usuário 'radius' no MariaDB [gera automático]:"
    read -rs DB_PASS; echo ""
    DB_PASS="${DB_PASS:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 22)}"

    # RADIUS secret
    ask "RADIUS Shared Secret [gera automático]:"
    read -r RADIUS_SECRET
    RADIUS_SECRET="${RADIUS_SECRET:-$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9!@#' | head -c 30)}"

    # IP do MikroTik
    ask "IP do roteador MikroTik [192.168.88.1]:"
    read -r MIKROTIK_IP
    MIKROTIK_IP="${MIKROTIK_IP:-192.168.88.1}"

    # Web server
    ask "Web server — (1) Nginx  (2) Apache2  [1]:"
    read -r WEB_CHOICE
    [[ "$WEB_CHOICE" == "2" ]] && WEB_SERVER="apache2" || WEB_SERVER="nginx"

    # Senha admin
    ask "Senha do administrador do painel [Admin@123]:"
    read -rs ADMIN_PASS; echo ""
    ADMIN_PASS="${ADMIN_PASS:-Admin@123}"

    # Fuso horário
    ask "Timezone [America/Sao_Paulo]:"
    read -r APP_TZ
    APP_TZ="${APP_TZ:-America/Sao_Paulo}"

    echo ""
    echo -e "${BOLD}┌────────────────────────────────────────────────────┐"
    echo -e "│              Resumo da Instalação                  │"
    echo -e "├────────────────────────────────────────────────────┤"
    echo -e "│ Diretório    : ${INSTALL_DIR}"
    echo -e "│ URL          : http://${APP_HOST}:${APP_PORT}"
    echo -e "│ Timezone     : ${APP_TZ}"
    echo -e "│ MariaDB user : radius / [oculto]"
    echo -e "│ RADIUS IP    : MikroTik @ ${MIKROTIK_IP}"
    echo -e "│ Web server   : ${WEB_SERVER}"
    echo -e "│ Admin login  : admin@hotspot.local / [definido]"
    echo -e "│ Execução     : root"
    echo -e "└────────────────────────────────────────────────────┘${NC}"
    echo ""
    ask "Confirmar e iniciar instalação? [s/N]:"
    read -r CONFIRM
    [[ "${CONFIRM,,}" == "s" ]] || { info "Instalação cancelada."; exit 0; }
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 1 — SISTEMA BASE
# ══════════════════════════════════════════════════════════════════════════════
update_system() {
    step "1/9 — Atualizando sistema"
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" \
                            -o Dpkg::Options::="--force-confold"
    apt-get install -y -qq \
        curl wget git unzip gnupg2 lsb-release ca-certificates \
        apt-transport-https \
        openssl ufw logrotate rsync acl

    success "Sistema atualizado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 2 — PHP 8.2
# ══════════════════════════════════════════════════════════════════════════════
install_php() {
    step "2/9 — Instalando PHP 8.2"

    # Sempre (re)adiciona o repositório Sury para garantir que php8.2-fpm etc. existam.
    # O pacote "php8.2" pode existir nos repos Debian, mas os pacotes individuais
    # (php8.2-fpm, php8.2-mysql, etc.) só estão disponíveis via Sury.
    info "Adicionando repositório Sury (deb.sury.org)..."

    # Remove entrada antiga para evitar conflito
    rm -f /etc/apt/sources.list.d/sury-php.list
    rm -f /usr/share/keyrings/sury-php.gpg

    # Importa a chave GPG
    curl -sSfL https://packages.sury.org/php/apt.gpg \
        | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg \
        || error "Falha ao baixar chave GPG do Sury. Verifique a conexão."

    # Adiciona o repositório usando o codename do OS
    local CODENAME
    CODENAME=$(lsb_release -cs)
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ ${CODENAME} main" \
        > /etc/apt/sources.list.d/sury-php.list

    info "Repositório Sury adicionado para '${CODENAME}'. Atualizando índice..."
    apt-get update -qq

    # Confirma que php8.2-fpm está disponível antes de instalar
    apt-cache show php8.2-fpm &>/dev/null \
        || error "php8.2-fpm não encontrado mesmo após adicionar o repositório Sury. Verifique: apt-cache policy php8.2-fpm"

    apt-get install -y -qq \
        php8.2 php8.2-fpm php8.2-cli php8.2-common \
        php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl \
        php8.2-zip php8.2-bcmath php8.2-intl php8.2-gd \
        php8.2-tokenizer php8.2-pdo php8.2-readline

    # PHP.ini — produção
    for ini_file in /etc/php/8.2/fpm/php.ini /etc/php/8.2/cli/php.ini; do
        [[ -f "$ini_file" ]] || continue
        sed -i 's/^upload_max_filesize.*/upload_max_filesize = 20M/'  "$ini_file"
        sed -i 's/^post_max_size.*/post_max_size = 25M/'              "$ini_file"
        sed -i 's/^memory_limit.*/memory_limit = 256M/'               "$ini_file"
        sed -i 's/^max_execution_time.*/max_execution_time = 60/'      "$ini_file"
        sed -i 's/^expose_php.*/expose_php = Off/'                     "$ini_file"
        sed -i "s|^;date.timezone.*|date.timezone = ${APP_TZ}|"       "$ini_file"
    done

    # Pool FPM rodando como root (já que a app é executada por root)
    PHP_POOL="/etc/php/8.2/fpm/pool.d/www.conf"
    sed -i 's/^user = .*/user = root/'   "$PHP_POOL"
    sed -i 's/^group = .*/group = root/' "$PHP_POOL"
    # Também ajusta os sockets de escuta para root
    sed -i 's/^listen\.owner.*/listen.owner = root/'  "$PHP_POOL" 2>/dev/null || true
    sed -i 's/^listen\.group.*/listen.group = root/'  "$PHP_POOL" 2>/dev/null || true

    systemctl enable --now php8.2-fpm
    success "PHP $(php -r 'echo PHP_VERSION;') instalado e configurado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 3 — COMPOSER
# ══════════════════════════════════════════════════════════════════════════════
install_composer() {
    step "3/9 — Instalando Composer"

    if command -v composer &>/dev/null; then
        success "Composer $(composer --version --no-ansi | awk '{print $3}') já instalado."
        return
    fi

    EXPECTED_SIG="$(curl -sSL https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
    ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"

    [[ "$EXPECTED_SIG" == "$ACTUAL_SIG" ]] \
        || error "Checksum do instalador Composer inválido. Abortando."

    php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer-setup.php
    success "Composer $(composer --version --no-ansi | awk '{print $3}') instalado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 4 — MARIADB
# ══════════════════════════════════════════════════════════════════════════════
install_mariadb() {
    step "4/9 — Instalando MariaDB 11.4"

    # Repositório oficial MariaDB (LTS)
    if ! mariadbd --version 2>/dev/null | grep -q "11\."; then
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup \
            | bash -s -- --mariadb-server-version="mariadb-11.4" \
                         --skip-maxscale --os-type=debian \
                         --os-version="$(lsb_release -cs)"
        apt-get update -qq
    fi

    apt-get install -y -qq mariadb-server mariadb-client
    systemctl enable mariadb
    systemctl start mariadb
    success "MariaDB instalado."

    # Aguarda o socket ficar disponível (até 30s)
    local SOCKET=""
    local WAITED=0
    info "Aguardando MariaDB ficar pronto..."
    while [[ $WAITED -lt 30 ]]; do
        for s in /run/mysqld/mysqld.sock /var/run/mysqld/mysqld.sock /tmp/mysql.sock; do
            if [[ -S "$s" ]]; then
                SOCKET="$s"
                break 2
            fi
        done
        sleep 1
        WAITED=$(( WAITED + 1 ))
    done

    [[ -n "$SOCKET" ]] && info "Socket encontrado em: ${SOCKET}" \
                       || error "Socket do MariaDB não encontrado. Verifique: journalctl -u mariadb -n 30"

    # No Debian, o MariaDB roda como o usuário de sistema 'mysql'.
    # Esse usuário tem acesso implícito ao servidor sem senha.
    # Usamos runuser para executar comandos como esse usuário — funciona
    # em qualquer versão do Debian/MariaDB independente de unix_socket ou senha.
    info "Criando banco 'radius' e usuário via runuser mysql..."
    runuser -u mysql -- mariadb --socket="${SOCKET}" <<SQL
CREATE DATABASE IF NOT EXISTS radius
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'radius'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
FLUSH PRIVILEGES;
SQL

    # Persiste credenciais com permissão restrita
    cat > /root/.hotspot_db.env <<EOF
# Hotspot Manager — Credenciais MariaDB
# Geradas em: $(date -Iseconds)
# Conectar manualmente: mariadb -u radius -p'${DB_PASS}' radius
DB_USER=radius
DB_NAME=radius
DB_PASS=${DB_PASS}
EOF
    chmod 600 /root/.hotspot_db.env
    success "Banco 'radius' criado. Credenciais em /root/.hotspot_db.env"
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 5 — APP LARAVEL
# ══════════════════════════════════════════════════════════════════════════════
install_app() {
    step "5/9 — Instalando a aplicação Laravel"

    # Clona ou atualiza o repositório
    # Usa SSH (git@github.com) — mesmo protocolo do push, sem autenticação interativa.
    # Pré-requisito: a chave SSH do servidor deve estar adicionada ao GitHub.
    local REPO_SSH="git@github.com:Wantuilxavier/hotspot-manager.git"
    local REPO_HTTPS="https://github.com/Wantuilxavier/hotspot-manager.git"

    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        info "Repositório já existe em ${INSTALL_DIR}. Atualizando..."
        git -C "$INSTALL_DIR" pull --ff-only
    else
        info "Clonando repositório via SSH..."

        # Garante que o fingerprint do GitHub está aceito (evita prompt interativo)
        mkdir -p /root/.ssh
        ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null

        if GIT_SSH_COMMAND="ssh -o BatchMode=yes" git clone --depth=1 "$REPO_SSH" "$INSTALL_DIR" 2>/dev/null; then
            success "Repositório clonado via SSH."
        else
            warn "Clone SSH falhou. Tentando HTTPS (funciona apenas se o repositório for público)..."
            GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$REPO_HTTPS" "$INSTALL_DIR" \
                || error "Falha ao clonar o repositório.

  Opção 1 — Torne o repositório público no GitHub:
    https://github.com/Wantuilxavier/hotspot-manager/settings

  Opção 2 — Adicione a chave SSH deste servidor ao GitHub:
    Chave pública: $(cat /root/.ssh/id_ed25519.pub 2>/dev/null || cat /root/.ssh/id_rsa.pub 2>/dev/null || echo '[nenhuma chave encontrada — gere com: ssh-keygen -t ed25519]')
    Adicionar em: https://github.com/settings/ssh/new"
        fi
    fi

    cd "$INSTALL_DIR"

    # ── .env ────────────────────────────────────────────────────────────────
    cat > .env <<EOF
APP_NAME="Hotspot Manager"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://${APP_HOST}:${APP_PORT}
APP_TIMEZONE=${APP_TZ}

LOG_CHANNEL=daily
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

    # ── Dependências ────────────────────────────────────────────────────────
    # --no-scripts evita que package:discover rode antes do APP_KEY existir,
    # causando falha no bootstrap do Laravel durante o composer install.
    info "Instalando dependências PHP via Composer..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install \
        --no-dev --optimize-autoloader --no-interaction --quiet --no-scripts
    success "Dependências instaladas."

    # ── Chave (deve vir antes de qualquer artisan command) ───────────────────
    php artisan key:generate --force --ansi
    success "APP_KEY gerada."

    # ── Package discover (agora que o APP_KEY existe) ────────────────────────
    php artisan package:discover --ansi
    success "Package discovery concluído."

    # ── Banco ───────────────────────────────────────────────────────────────
    info "Executando migrations (criando schema RADIUS)..."
    php artisan migrate --force --ansi
    success "Migrations concluídas."

    info "Populando dados iniciais (planos e admin)..."
    php artisan db:seed --force --ansi
    success "Seed concluído."

    # Atualiza senha do admin se foi personalizada
    if [[ "$ADMIN_PASS" != "Admin@123" ]]; then
        php artisan tinker --execute="\
            \App\Models\AdminUser::where('email','admin@hotspot.local')
                ->update(['password'=>bcrypt('${ADMIN_PASS}')]);
        " 2>/dev/null && success "Senha do admin atualizada." \
                       || warn "Atualize a senha do admin manualmente no painel."
    fi

    # ── Cache de produção ────────────────────────────────────────────────────
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
    success "Cache de produção gerado."

    # ── Permissões (root como owner) ────────────────────────────────────────
    chown -R root:root "$INSTALL_DIR"
    find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
    find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
    chmod -R 775 "${INSTALL_DIR}/storage" "${INSTALL_DIR}/bootstrap/cache"
    # install.sh executável
    chmod +x "${INSTALL_DIR}/install.sh"
    success "Permissões configuradas (owner: root)."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 6 — FREERADIUS 3
# ══════════════════════════════════════════════════════════════════════════════
install_freeradius() {
    step "6/9 — Instalando FreeRADIUS 3"

    apt-get install -y -qq \
        freeradius freeradius-mysql freeradius-utils freeradius-common

    FR_DIR="/etc/freeradius/3.0"
    FR_VERSION=$(freeradius -v 2>&1 | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || echo "3.x")
    success "FreeRADIUS ${FR_VERSION} instalado."

    # ── Dicionário MikroTik ────────────────────────────────────────────────
    cp "${INSTALL_DIR}/freeradius/dictionary.mikrotik" /usr/share/freeradius/dictionary.mikrotik
    grep -q "dictionary.mikrotik" /usr/share/freeradius/dictionary \
        || echo '$INCLUDE dictionary.mikrotik' >> /usr/share/freeradius/dictionary
    success "Dicionário MikroTik instalado."

    # ── Módulo SQL ─────────────────────────────────────────────────────────
    cp "${INSTALL_DIR}/freeradius/mods-available/sql" "${FR_DIR}/mods-available/sql"
    sed -i "s|password = \"secret\"|password = \"${DB_PASS}\"|g" \
        "${FR_DIR}/mods-available/sql"

    ln -sf "${FR_DIR}/mods-available/sql" "${FR_DIR}/mods-enabled/sql" 2>/dev/null || true
    success "Módulo SQL configurado."

    # ── Módulos necessários ────────────────────────────────────────────────
    # Habilita módulos usados pelo virtual server hotspot
    for mod in preprocess pap chap acct_unique attr_filter; do
        if [[ -f "${FR_DIR}/mods-available/${mod}" ]]; then
            ln -sf "${FR_DIR}/mods-available/${mod}" \
                   "${FR_DIR}/mods-enabled/${mod}" 2>/dev/null || true
        fi
    done
    success "Módulos FreeRADIUS habilitados."

    # ── Virtual server hotspot ─────────────────────────────────────────────
    cp "${INSTALL_DIR}/freeradius/sites-available/hotspot" \
       "${FR_DIR}/sites-available/hotspot"
    ln -sf "${FR_DIR}/sites-available/hotspot" "${FR_DIR}/sites-enabled/hotspot" 2>/dev/null || true
    success "Virtual server 'hotspot' ativado."

    # ── clients.conf ───────────────────────────────────────────────────────
    if ! grep -q "client mikrotik_hotspot" "${FR_DIR}/clients.conf"; then
        cat >> "${FR_DIR}/clients.conf" <<EOF

# ── Adicionado pelo instalador Hotspot Manager em $(date -Iseconds) ──

client mikrotik_hotspot {
    ipaddr    = ${MIKROTIK_IP}
    secret    = ${RADIUS_SECRET}
    shortname = mikrotik
    nastype   = other
    require_message_authenticator = no
}

client localhost_radtest {
    ipaddr    = 127.0.0.1
    secret    = ${RADIUS_SECRET}
    shortname = localhost
}
EOF
        success "MikroTik (${MIKROTIK_IP}) adicionado ao clients.conf."
    fi

    # ── Permissões ─────────────────────────────────────────────────────────
    chown -R freerad:freerad "${FR_DIR}"

    # ── Valida configuração antes de iniciar ────────────────────────────────
    local FR_CHECK
    FR_CHECK=$(freeradius -XC 2>&1) || true

    if echo "$FR_CHECK" | grep -qi "error"; then
        warn "FreeRADIUS detectou erros de configuração:"
        echo "$FR_CHECK" | grep -i "error" | head -10
        warn "Para debug completo rode: freeradius -X"
        warn "O script continua — corrija o FreeRADIUS manualmente após a instalação."
    else
        systemctl enable freeradius
        systemctl restart freeradius \
            && success "FreeRADIUS iniciado com sucesso." \
            || {
                warn "FreeRADIUS falhou ao iniciar. Saída do journalctl:"
                journalctl -u freeradius -n 20 --no-pager || true
                warn "Corrija e rode: systemctl restart freeradius"
            }
    fi

    # Salva secret
    cat > /root/.hotspot_radius.env <<EOF
# Hotspot Manager — RADIUS
# Geradas em: $(date -Iseconds)
RADIUS_SECRET=${RADIUS_SECRET}
MIKROTIK_IP=${MIKROTIK_IP}

# Cole no RouterOS:
# /radius add service=hotspot address=$(hostname -I | awk '{print $1}') secret=${RADIUS_SECRET}
EOF
    chmod 600 /root/.hotspot_radius.env
    success "RADIUS secret salvo em /root/.hotspot_radius.env"
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 7 — WEB SERVER
# ══════════════════════════════════════════════════════════════════════════════
install_webserver() {
    step "7/9 — Configurando ${WEB_SERVER}"
    [[ "$WEB_SERVER" == "nginx" ]] && setup_nginx || setup_apache
}

setup_nginx() {
    apt-get install -y -qq nginx

    # Nginx worker rodando como root
    sed -i 's/^user .*/user root;/' /etc/nginx/nginx.conf

    cat > /etc/nginx/sites-available/hotspot-manager <<EOF
# Hotspot Manager — Nginx
# Gerado em: $(date -Iseconds)

server {
    listen ${APP_PORT};
    listen [::]:${APP_PORT};
    server_name ${APP_HOST};

    root ${INSTALL_DIR}/public;
    index index.php index.html;

    # Segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    server_tokens off;

    # Logs
    access_log /var/log/nginx/hotspot-manager.access.log;
    error_log  /var/log/nginx/hotspot-manager.error.log warn;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass   unix:/run/php/php8.2-fpm.sock;
        fastcgi_param  SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_read_timeout 60;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|woff|woff2|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    client_max_body_size 25M;
}
EOF

    ln -sf /etc/nginx/sites-available/hotspot-manager \
           /etc/nginx/sites-enabled/hotspot-manager
    rm -f /etc/nginx/sites-enabled/default

    nginx -t 2>/dev/null \
        && systemctl enable --now nginx \
        && systemctl reload nginx
    success "Nginx configurado na porta ${APP_PORT}."
}

setup_apache() {
    apt-get install -y -qq apache2 libapache2-mod-php8.2
    a2enmod rewrite php8.2 headers deflate

    # Apache rodando como root
    sed -i 's/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=root/'  /etc/apache2/envvars
    sed -i 's/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=root/' /etc/apache2/envvars

    cat > /etc/apache2/sites-available/hotspot-manager.conf <<EOF
# Hotspot Manager — Apache2
# Gerado em: $(date -Iseconds)

<VirtualHost *:${APP_PORT}>
    ServerName  ${APP_HOST}
    DocumentRoot ${INSTALL_DIR}/public

    <Directory ${INSTALL_DIR}/public>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>

    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    ServerTokens Prod
    ServerSignature Off

    ErrorLog  \${APACHE_LOG_DIR}/hotspot-manager.error.log
    CustomLog \${APACHE_LOG_DIR}/hotspot-manager.access.log combined
</VirtualHost>
EOF

    # Ajusta porta se não for 80
    if [[ "$APP_PORT" != "80" ]]; then
        grep -q "Listen ${APP_PORT}" /etc/apache2/ports.conf \
            || echo "Listen ${APP_PORT}" >> /etc/apache2/ports.conf
    fi

    a2ensite hotspot-manager.conf
    a2dissite 000-default.conf 2>/dev/null || true
    apache2ctl configtest \
        && systemctl enable --now apache2 \
        && systemctl reload apache2
    success "Apache2 configurado na porta ${APP_PORT}."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 8 — FIREWALL (UFW)
# ══════════════════════════════════════════════════════════════════════════════
configure_firewall() {
    step "8/9 — Configurando Firewall (UFW)"

    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # SSH — crítico: não perder acesso
    ufw allow 22/tcp comment "SSH"

    # HTTP / HTTPS
    [[ "$APP_PORT" != "80" ]] && ufw allow 80/tcp  comment "HTTP"
    ufw allow "${APP_PORT}/tcp" comment "Hotspot Manager"
    ufw allow 443/tcp comment "HTTPS"

    # RADIUS — apenas do MikroTik
    ufw allow from "${MIKROTIK_IP}" to any port 1812 proto udp \
        comment "RADIUS Auth — MikroTik"
    ufw allow from "${MIKROTIK_IP}" to any port 1813 proto udp \
        comment "RADIUS Acct — MikroTik"

    # RADIUS localhost (radtest)
    ufw allow from 127.0.0.1 to any port 1812 proto udp comment "RADIUS local auth"
    ufw allow from 127.0.0.1 to any port 1813 proto udp comment "RADIUS local acct"

    ufw --force enable
    success "Firewall ativo."
    ufw status numbered
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 9 — CRON + LOGROTATE
# ══════════════════════════════════════════════════════════════════════════════
configure_cron() {
    step "9/9 — Configurando Cron e Logrotate"

    # Crontab do root
    CRON_TMP=$(mktemp)
    crontab -l 2>/dev/null > "$CRON_TMP" || true

    # Remove entradas antigas do hotspot-manager
    grep -v "hotspot-manager\|artisan" "$CRON_TMP" > "${CRON_TMP}.clean" || true
    mv "${CRON_TMP}.clean" "$CRON_TMP"

    cat >> "$CRON_TMP" <<EOF

# ── Hotspot Manager ────────────────────────────────────
# Laravel Scheduler (a cada minuto)
* * * * * cd ${INSTALL_DIR} && php artisan schedule:run >> /dev/null 2>&1

# Expira usuários vencidos (01:00 diariamente)
0 1 * * * cd ${INSTALL_DIR} && php artisan hotspot:expire-users >> /dev/null 2>&1

# Limpa sessões RADIUS antigas (> 90 dias) — domingo 03:00
0 3 * * 0 mariadb -u radius -p'${DB_PASS}' radius -e \
  "DELETE FROM radacct WHERE acctstoptime < DATE_SUB(NOW(), INTERVAL 90 DAY);" >> /dev/null 2>&1
EOF

    crontab "$CRON_TMP"
    rm -f "$CRON_TMP"
    success "Cron configurado no crontab de root."

    # Logrotate
    cat > /etc/logrotate.d/hotspot-manager <<EOF
${INSTALL_DIR}/storage/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
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
    local SERVER_IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        INSTALAÇÃO CONCLUÍDA COM SUCESSO!                     ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Painel Admin :  ${BOLD}http://${APP_HOST}:${APP_PORT}/admin${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Captive Portal: ${BOLD}http://${APP_HOST}:${APP_PORT}/portal${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Login admin  :  ${BOLD}admin@hotspot.local${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Senha admin  :  ${BOLD}${ADMIN_PASS}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Arquivos de credenciais (somente root):"
    echo -e "${GREEN}${BOLD}║${NC}    /root/.hotspot_db.env       (MariaDB)"
    echo -e "${GREEN}${BOLD}║${NC}    /root/.hotspot_radius.env   (RADIUS secret)"
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║${NC}  Cole no MikroTik (Terminal / Winbox):${GREEN}${BOLD}"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo ""
    printf "  /radius add \\\\\n"
    printf "      service=hotspot \\\\\n"
    printf "      address=%s \\\\\n" "$SERVER_IP"
    printf "      secret=%s \\\\\n" "$RADIUS_SECRET"
    printf "      authentication-port=1812 \\\\\n"
    printf "      accounting-port=1813\n"
    echo ""
    printf "  /ip hotspot profile set [find] \\\\\n"
    printf "      use-radius=yes radius-accounting=yes\n"
    echo ""
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Testar RADIUS:                                              ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo "  radtest usuario senha 127.0.0.1 0 ${RADIUS_SECRET}"
    echo ""
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Diagnóstico:                                                ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo "  journalctl -u freeradius -f"
    echo "  journalctl -u ${WEB_SERVER} -f"
    echo "  tail -f ${INSTALL_DIR}/storage/logs/laravel.log"
    echo "  freeradius -X                  # debug interativo"
    echo ""
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Log completo desta instalação:                              ║"
    echo -e "╠══════════════════════════════════════════════════════════════╣${NC}"
    echo "  /var/log/hotspot-manager-install.log"
    echo ""
    echo -e "${YELLOW}${BOLD}  ATENÇÃO: Altere a senha do admin no primeiro acesso!${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# TRAP DE ERROS
# ══════════════════════════════════════════════════════════════════════════════
on_error() {
    local line=$1
    echo -e "\n${RED}${BOLD}[ERRO FATAL]${NC} Falha na linha ${line}."
    echo "Verifique o log completo em: /var/log/hotspot-manager-install.log"
}
trap 'on_error $LINENO' ERR

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
main() {
    banner
    check_root
    check_os
    check_internet
    collect_config

    LOG_FILE="/var/log/hotspot-manager-install.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "Log sendo gravado em: ${LOG_FILE}"
    echo "Início: $(date -Iseconds)"

    update_system
    install_php
    install_composer
    install_mariadb
    install_app          # ← deve vir antes do FreeRADIUS (copia configs)
    install_freeradius
    install_webserver
    configure_firewall
    configure_cron

    echo "Fim: $(date -Iseconds)"
    print_summary
}

main "$@"

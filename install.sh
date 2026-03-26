#!/usr/bin/env bash
# ==============================================================================
#  Hotspot Manager — Instalador / Atualizador  v2.0
#  Alvo  : Debian 13 (Trixie) / Debian 12 (Bookworm)
#  Uso   : bash install.sh   (execute como root)
#  Modos : fresh | update  (detectado automaticamente)
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

banner() {
cat << 'EOF'

  ██╗  ██╗ ██████╗ ████████╗███████╗██████╗  ██████╗ ████████╗
  ██║  ██║██╔═══██╗╚══██╔══╝██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝
  ███████║██║   ██║   ██║   ███████╗██████╔╝██║   ██║   ██║
  ██╔══██║██║   ██║   ██║   ╚════██║██╔═══╝ ██║   ██║   ██║
  ██║  ██║╚██████╔╝   ██║   ███████║██║     ╚██████╔╝   ██║
  ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝╚═╝      ╚═════╝    ╚═╝
        MikroTik Hotspot Manager — Instalador v2.0
          Debian 13 (Trixie) / Debian 12 (Bookworm)
          Execução como root  |  github.com/Wantuilxavier

EOF
}

# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ══════════════════════════════════════════════════════════════════════════════
INSTALL_DIR="/var/www/hotspot-manager"
WEB_SERVER="nginx"
APP_PORT="80"
APP_TZ="America/Sao_Paulo"
MIKROTIK_IP="192.168.88.1"
REPO_SSH="git@github.com:Wantuilxavier/hotspot-manager.git"
REPO_HTTPS="https://github.com/Wantuilxavier/hotspot-manager.git"

# Arquivos de estado (persistem entre execuções)
STATE_DB="/root/.hotspot_db.env"
STATE_RADIUS="/root/.hotspot_radius.env"
STATE_ADMIN="/root/.hotspot_admin.env"
CRED_FILE="/root/hotspot-manager-credentials.txt"

# Modo de execução (definido em detect_mode)
MODE="fresh"   # fresh | update

# ══════════════════════════════════════════════════════════════════════════════
# VERIFICAÇÕES INICIAIS
# ══════════════════════════════════════════════════════════════════════════════
check_root() {
    [[ $EUID -eq 0 ]] || error "Execute como root: bash $0"
}

check_os() {
    [[ -f /etc/debian_version ]] \
        || error "Sistema não suportado. Requer Debian 12 ou 13."
    DEBIAN_VERSION=$(cut -d. -f1 /etc/debian_version)
    OS_CODENAME=$(lsb_release -cs 2>/dev/null || echo "unknown")
    [[ "$DEBIAN_VERSION" -ge 12 ]] \
        || error "Requer Debian 12+. Atual: ${DEBIAN_VERSION}."
    info "Debian ${DEBIAN_VERSION} (${OS_CODENAME}) detectado."
}

check_internet() {
    info "Verificando conectividade..."
    curl -sf --max-time 8 https://deb.debian.org > /dev/null \
        || error "Sem acesso à internet."
    success "Internet disponível."
}

# ══════════════════════════════════════════════════════════════════════════════
# DETECÇÃO DE MODO + CREDENCIAIS
# ══════════════════════════════════════════════════════════════════════════════
detect_mode() {
    if [[ -d "${INSTALL_DIR}/.git" ]] && [[ -f "$STATE_DB" ]]; then
        MODE="update"
    else
        MODE="fresh"
    fi
}

load_or_generate_credentials() {
    # Lê credenciais persistidas. Se não existirem (fresh install), gera novas.
    # NUNCA gera novas senhas em modo update — isso causaria dessincronização
    # entre o banco de dados já existente e o novo .env.
    DB_PASS=""
    RADIUS_SECRET=""
    ADMIN_PASS=""

    [[ -f "$STATE_DB" ]]     && DB_PASS="$(grep ^DB_PASS= "$STATE_DB" | cut -d= -f2)"
    [[ -f "$STATE_RADIUS" ]] && RADIUS_SECRET="$(grep ^RADIUS_SECRET= "$STATE_RADIUS" | cut -d= -f2)"
    [[ -f "$STATE_ADMIN" ]]  && ADMIN_PASS="$(grep ^ADMIN_PASS= "$STATE_ADMIN" | cut -d= -f2)"

    [[ -n "$DB_PASS" ]]       || DB_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 22)"
    [[ -n "$RADIUS_SECRET" ]] || RADIUS_SECRET="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)"
    [[ -n "$ADMIN_PASS" ]]    || ADMIN_PASS="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 20)"

    SERVER_IP=$(hostname -I | awk '{print $1}')
    APP_HOST="${SERVER_IP}"
}

collect_config() {
    detect_mode
    load_or_generate_credentials

    local mode_label
    [[ "$MODE" == "update" ]] && mode_label="ATUALIZAÇÃO" || mode_label="INSTALAÇÃO NOVA"

    echo ""
    echo -e "${BOLD}┌──────────────────────────────────────────────────────┐"
    printf  "│  Modo     : %-40s│\n" "$mode_label"
    printf  "│  Servidor : %-40s│\n" "${APP_HOST}:${APP_PORT}"
    printf  "│  Dir      : %-40s│\n" "${INSTALL_DIR}"
    printf  "│  MariaDB  : %-40s│\n" "radius / [credenciais em /root]"
    printf  "│  Web      : %-40s│\n" "${WEB_SERVER}"
    echo -e "└──────────────────────────────────────────────────────┘${NC}"
    echo ""
    info "Iniciando em 5 segundos... (Ctrl+C para cancelar)"
    sleep 5
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 1 — SISTEMA BASE
# ══════════════════════════════════════════════════════════════════════════════
update_system() {
    step "1/9 — Atualizando sistema"
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"
    apt-get install -y -qq \
        curl wget git unzip gnupg2 lsb-release ca-certificates \
        apt-transport-https openssl ufw logrotate rsync acl

    success "Sistema atualizado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 2 — PHP 8.2
# ══════════════════════════════════════════════════════════════════════════════
install_php() {
    step "2/9 — PHP 8.2"

    # Sempre (re)adiciona o repositório Sury — garante que php8.2-fpm exista
    info "Configurando repositório Sury..."
    rm -f /etc/apt/sources.list.d/sury-php.list \
          /usr/share/keyrings/sury-php.gpg

    curl -sSfL https://packages.sury.org/php/apt.gpg \
        | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg \
        || error "Falha ao baixar chave GPG do Sury."

    local CODENAME
    CODENAME=$(lsb_release -cs)
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ ${CODENAME} main" \
        > /etc/apt/sources.list.d/sury-php.list

    apt-get update -qq
    apt-cache show php8.2-fpm &>/dev/null \
        || error "php8.2-fpm não encontrado. Verifique: apt-cache policy php8.2-fpm"

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

    # Pool FPM — PHP proíbe workers como root (proteção hard-coded)
    local PHP_POOL="/etc/php/8.2/fpm/pool.d/www.conf"

    if [[ ! -f "$PHP_POOL" ]]; then
        # "Not replacing deleted config file" — dpkg marcou os conffiles como
        # apagados pelo usuário; --reinstall respeita isso e não recria.
        # Solução: purgar TODOS os pacotes php8.2* (limpa estado dpkg de todos)
        # e reinstalar o conjunto completo — evita que php8.2-common (phar, etc.)
        # fique como órfão após purgar apenas php8.2-fpm.
        warn "Config PHP-FPM ausente (dpkg conffile state) — purgando php8.2* para reinstalação limpa..."
        apt-get purge -y -qq "php8.2*" 2>/dev/null || true
        apt-get autoremove -y -qq 2>/dev/null || true
        apt-get install -y -qq \
            php8.2 php8.2-fpm php8.2-cli php8.2-common \
            php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl \
            php8.2-zip php8.2-bcmath php8.2-intl php8.2-gd \
            php8.2-tokenizer php8.2-pdo php8.2-readline
    fi

    [[ -f "$PHP_POOL" ]] \
        || error "Pool config não encontrado: ${PHP_POOL}. Verifique: dpkg -l php8.2-fpm"

    sed -i 's/^user = .*/user = www-data/'               "$PHP_POOL"
    sed -i 's/^group = .*/group = www-data/'             "$PHP_POOL"
    sed -i 's/^listen\.owner.*/listen.owner = www-data/' "$PHP_POOL" 2>/dev/null || true
    sed -i 's/^listen\.group.*/listen.group = www-data/' "$PHP_POOL" 2>/dev/null || true

    # Garante o diretório do socket (pode não existir no Debian 13 fresh)
    mkdir -p /run/php
    for tmpfile in /usr/lib/tmpfiles.d/php8.2-fpm.conf /etc/tmpfiles.d/php8.2-fpm.conf; do
        [[ -f "$tmpfile" ]] && systemd-tmpfiles --create "$tmpfile" 2>/dev/null || true
    done

    info "Validando configuração PHP-FPM..."
    php-fpm8.2 --test 2>&1 || error "Configuração PHP-FPM inválida (ver acima)."

    systemctl enable php8.2-fpm
    _service_restart php8.2-fpm
    success "PHP $(php -r 'echo PHP_VERSION;') instalado e configurado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 3 — COMPOSER
# ══════════════════════════════════════════════════════════════════════════════
install_composer() {
    step "3/9 — Composer"

    if command -v composer &>/dev/null; then
        # Atualiza composer se já instalado
        composer self-update --stable --no-interaction 2>/dev/null || true
        success "Composer $(composer --version --no-ansi | awk '{print $3}') pronto."
        return
    fi

    local EXPECTED_SIG ACTUAL_SIG
    EXPECTED_SIG="$(curl -sSL https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
    ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
    [[ "$EXPECTED_SIG" == "$ACTUAL_SIG" ]] || error "Checksum Composer inválido."

    php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer-setup.php
    success "Composer $(composer --version --no-ansi | awk '{print $3}') instalado."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 4 — MARIADB
# ══════════════════════════════════════════════════════════════════════════════
install_mariadb() {
    step "4/9 — MariaDB 11.4"

    if ! mariadbd --version 2>/dev/null | grep -q "11\."; then
        info "Adicionando repositório MariaDB 11.4..."
        curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup \
            | bash -s -- --mariadb-server-version="mariadb-11.4" \
                         --skip-maxscale --os-type=debian \
                         --os-version="$(lsb_release -cs)"
        apt-get update -qq
    fi

    apt-get install -y -qq mariadb-server mariadb-client
    systemctl enable mariadb
    _service_restart mariadb

    # Aguarda o socket (até 30 s)
    local SOCKET="" WAITED=0
    info "Aguardando MariaDB..."
    while [[ $WAITED -lt 30 ]]; do
        for s in /run/mysqld/mysqld.sock /var/run/mysqld/mysqld.sock /tmp/mysql.sock; do
            [[ -S "$s" ]] && { SOCKET="$s"; break 2; }
        done
        sleep 1; WAITED=$(( WAITED + 1 ))
    done
    [[ -n "$SOCKET" ]] || error "Socket MariaDB não encontrado. Ver: journalctl -u mariadb -n 30"
    info "Socket: ${SOCKET}"

    # Cria banco + usuário (CREATE OR REPLACE — sempre sincroniza a senha)
    # Dois grants: @'localhost' (socket) e @'127.0.0.1' (TCP).
    # FreeRADIUS conecta via TCP (server = "127.0.0.1") — precisa do grant TCP.
    runuser -u mysql -- mariadb --socket="${SOCKET}" <<SQL
CREATE DATABASE IF NOT EXISTS radius
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE OR REPLACE USER 'radius'@'localhost'  IDENTIFIED BY '${DB_PASS}';
CREATE OR REPLACE USER 'radius'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'localhost';
GRANT ALL PRIVILEGES ON radius.* TO 'radius'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

    # Confirma autenticação via TCP (--protocol=tcp força TCP mesmo em localhost)
    # Este é o mesmo caminho que FreeRADIUS usa: server = "127.0.0.1"
    mariadb -u radius -p"${DB_PASS}" -h 127.0.0.1 --protocol=tcp radius \
        -e "SELECT 1;" &>/dev/null \
        || error "Autenticação TCP falhou para 'radius'@'127.0.0.1'. Senha: ${DB_PASS}"
    success "Usuário 'radius' autenticado via TCP com sucesso."

    # Persiste credenciais
    printf '# Hotspot Manager — MariaDB\nDB_USER=radius\nDB_NAME=radius\nDB_PASS=%s\n' \
        "${DB_PASS}" > "$STATE_DB"
    chmod 600 "$STATE_DB"

    # Atualiza .my.cnf (usado pelo cron)
    cat > /root/.my.cnf <<MYCNF
[client]
user=radius
password=${DB_PASS}
host=127.0.0.1
MYCNF
    chmod 600 /root/.my.cnf

    success "Banco 'radius' pronto."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 5 — APP LARAVEL
# ══════════════════════════════════════════════════════════════════════════════
install_app() {
    step "5/9 — Aplicação Laravel (modo: ${MODE})"

    # ── Git ──────────────────────────────────────────────────────────────────
    if [[ "$MODE" == "fresh" ]]; then
        _git_clone
    else
        _git_update
    fi

    cd "$INSTALL_DIR"

    # ── Diretórios obrigatórios do Laravel ───────────────────────────────────
    # Podem não existir no repo (.gitignore) — causam 500 se ausentes
    mkdir -p storage/framework/{sessions,cache/data,views} \
             storage/{app/public,logs} \
             bootstrap/cache

    # ── .env ─────────────────────────────────────────────────────────────────
    if [[ "$MODE" == "fresh" ]]; then
        _env_create
    else
        _env_sync   # Atualiza apenas as chaves gerenciadas pelo instalador
    fi

    # ── Dependências ─────────────────────────────────────────────────────────
    info "Instalando/atualizando dependências Composer..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install \
        --no-dev --optimize-autoloader --no-interaction --quiet --no-scripts
    success "Dependências prontas."

    # ── APP_KEY ──────────────────────────────────────────────────────────────
    grep -q "^APP_KEY=" .env || echo "APP_KEY=" >> .env

    if ! grep -q "^APP_KEY=base64:" .env; then
        # Primeira vez ou key:generate falhou — gera manualmente
        local GEN_KEY="base64:$(openssl rand -base64 32)"
        sed -i "s|^APP_KEY=.*|APP_KEY=${GEN_KEY}|" .env
    fi

    php artisan key:generate --force --ansi 2>&1 || true

    grep -q "^APP_KEY=base64:" .env \
        || error "Falha ao definir APP_KEY. Verifique permissões do .env."
    success "APP_KEY configurada."

    # ── Package discover ──────────────────────────────────────────────────────
    php artisan package:discover --ansi
    success "Package discovery concluído."

    # ── Limpa cache antigo (credenciais antigas no config cache causam 403) ──
    php artisan optimize:clear --ansi 2>/dev/null \
        || rm -f bootstrap/cache/config.php \
                 bootstrap/cache/routes*.php \
                 bootstrap/cache/packages.php \
                 bootstrap/cache/services.php

    # ── Migrations ───────────────────────────────────────────────────────────
    # Sempre seguro: migrate é idempotente (aplica apenas migrations pendentes)
    info "Executando migrations..."
    php artisan migrate --force --ansi
    success "Migrations concluídas."

    # ── Seed — apenas na instalação inicial ──────────────────────────────────
    if [[ "$MODE" == "fresh" ]]; then
        info "Populando dados iniciais..."
        php artisan db:seed --force --ansi
        success "Seed concluído."
    else
        info "Modo update — seed ignorado (dados existentes preservados)."
    fi

    # ── Senha do admin ────────────────────────────────────────────────────────
    php artisan tinker --execute="\
        \App\Models\AdminUser::where('email','admin@hotspot.local')
            ->update(['password'=>bcrypt('${ADMIN_PASS}')]);
    " 2>/dev/null \
        && success "Senha do admin atualizada." \
        || warn "Atualize a senha admin manualmente no painel."

    printf 'ADMIN_PASS=%s\n' "${ADMIN_PASS}" > "$STATE_ADMIN"
    chmod 600 "$STATE_ADMIN"

    # ── Permissões ────────────────────────────────────────────────────────────
    # Aplicadas ANTES do config:cache — os arquivos de cache nascem com
    # owner www-data (o mesmo usuário que o PHP-FPM usa em runtime)
    chown -R root:www-data "$INSTALL_DIR"
    find "$INSTALL_DIR" -type f -exec chmod 640 {} \;
    find "$INSTALL_DIR" -type d -exec chmod 750 {} \;
    chown -R www-data:www-data "${INSTALL_DIR}/storage" \
                               "${INSTALL_DIR}/bootstrap/cache"
    chmod -R 775 "${INSTALL_DIR}/storage" "${INSTALL_DIR}/bootstrap/cache"
    chmod -R 755 "${INSTALL_DIR}/public"
    chmod 700    "${INSTALL_DIR}/install.sh"
    success "Permissões configuradas."

    # ── Cache de produção (como www-data para garantir ownership correto) ─────
    # runuser em vez de sudo — sudo pode não estar instalado no Debian minimal
    runuser -u www-data -- php artisan config:cache
    runuser -u www-data -- php artisan route:cache
    runuser -u www-data -- php artisan view:cache
    success "Cache de produção gerado."
}

# ── Helpers de git ────────────────────────────────────────────────────────────
_git_clone() {
    info "Clonando repositório..."
    mkdir -p /root/.ssh
    ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null || true

    if GIT_SSH_COMMAND="ssh -o BatchMode=yes" \
       git clone --depth=1 "$REPO_SSH" "$INSTALL_DIR" 2>/dev/null; then
        success "Clonado via SSH."
    else
        warn "SSH falhou. Tentando HTTPS..."
        GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$REPO_HTTPS" "$INSTALL_DIR" \
            || error "Falha ao clonar. Verifique acesso ao repositório:
  SSH : adicione a chave do servidor em https://github.com/settings/ssh/new
        Chave: $(cat /root/.ssh/id_ed25519.pub 2>/dev/null \
                 || cat /root/.ssh/id_rsa.pub 2>/dev/null \
                 || echo '[gere com: ssh-keygen -t ed25519]')
  HTTPS: torne o repositório público em https://github.com/Wantuilxavier/hotspot-manager/settings"
    fi
}

_git_update() {
    info "Atualizando repositório para a versão mais recente..."
    # fetch + reset garante que o servidor fique idêntico ao repositório remoto,
    # independente de divergências locais (install.sh modificado, etc.)
    git -C "$INSTALL_DIR" fetch origin --prune 2>/dev/null \
        || { warn "fetch SSH falhou. Tentando HTTPS...";
             git -C "$INSTALL_DIR" remote set-url origin "$REPO_HTTPS" 2>/dev/null || true
             git -C "$INSTALL_DIR" fetch origin --prune; }

    local REMOTE_BRANCH
    REMOTE_BRANCH=$(git -C "$INSTALL_DIR" remote show origin 2>/dev/null \
                    | grep "HEAD branch" | awk '{print $NF}')
    REMOTE_BRANCH="${REMOTE_BRANCH:-main}"

    git -C "$INSTALL_DIR" reset --hard "origin/${REMOTE_BRANCH}"
    # Remove arquivos não rastreados exceto .env (contém credenciais)
    git -C "$INSTALL_DIR" clean -fd --exclude=".env" 2>/dev/null || true

    local NEW_HASH
    NEW_HASH=$(git -C "$INSTALL_DIR" rev-parse --short HEAD)
    success "Repositório atualizado → ${NEW_HASH} (${REMOTE_BRANCH})."
}

# ── Helpers de .env ───────────────────────────────────────────────────────────
_env_create() {
    info "Criando .env..."
    cat > "${INSTALL_DIR}/.env" <<ENVEOF
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
ENVEOF
    success ".env criado."
}

_env_sync() {
    # Em modo update, não recria o .env do zero — o usuário pode ter
    # personalizado valores (ex: MIKROTIK_PASS, MAIL_*, etc.).
    # Sincroniza apenas as chaves gerenciadas pelo instalador.
    info "Sincronizando valores do .env..."

    local ENV_FILE="${INSTALL_DIR}/.env"

    # Cria o .env se não existir (ex: primeiro update após instalação manual)
    if [[ ! -f "$ENV_FILE" ]]; then
        warn ".env não encontrado — criando a partir do template."
        _env_create
        return
    fi

    _env_set "DB_PASSWORD"    "${DB_PASS}"
    _env_set "RADIUS_SECRET"  "${RADIUS_SECRET}"
    _env_set "APP_URL"        "http://${APP_HOST}:${APP_PORT}"
    _env_set "APP_TIMEZONE"   "${APP_TZ}"

    success ".env sincronizado."
}

# Atualiza ou insere uma chave no .env
_env_set() {
    local KEY="$1" VAL="$2"
    local ENV_FILE="${INSTALL_DIR}/.env"
    if grep -q "^${KEY}=" "$ENV_FILE"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "$ENV_FILE"
    else
        echo "${KEY}=${VAL}" >> "$ENV_FILE"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 6 — FREERADIUS 3
# ══════════════════════════════════════════════════════════════════════════════
install_freeradius() {
    step "6/9 — FreeRADIUS 3"

    # Bloqueia start automático durante apt-get install.
    # O FreeRADIUS roda ExecStartPre=-Cx (config check) antes de iniciar;
    # como ainda não configuramos nada, esse check falha e o pacote fica
    # em estado parcial com a estrutura de /etc/freeradius/3.0 incompleta.
    echo '#!/bin/sh
exit 101' > /usr/sbin/policy-rc.d
    chmod +x /usr/sbin/policy-rc.d

    apt-get install -y -qq \
        freeradius freeradius-mysql freeradius-utils freeradius-common

    rm -f /usr/sbin/policy-rc.d

    local FR_DIR="/etc/freeradius/3.0"
    local FR_VERSION
    FR_VERSION=$(freeradius -v 2>&1 | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || echo "3.x")
    success "FreeRADIUS ${FR_VERSION}."

    # Garante que a estrutura de configuração foi criada pelo pacote.
    # radiusd.conf  → pacote freeradius
    # mods-available/ → pacote freeradius-config
    # Se qualquer um estiver ausente: dpkg marcou conffiles como "user-deleted"
    # (causado por rm -rf /etc/freeradius sem purge prévio).
    # Solução: purgar freeradius* inteiro (limpa estado dpkg de todos) e reinstalar.
    if [[ ! -d "${FR_DIR}/mods-available" ]] || [[ ! -f "${FR_DIR}/radiusd.conf" ]]; then
        warn "Estrutura FreeRADIUS incompleta (dpkg conffile state) — purgando para reinstalação limpa..."
        echo '#!/bin/sh
exit 101' > /usr/sbin/policy-rc.d
        chmod +x /usr/sbin/policy-rc.d
        apt-get purge -y -qq "freeradius*" 2>/dev/null || true
        apt-get autoremove -y -qq 2>/dev/null || true
        apt-get install -y -qq \
            freeradius freeradius-mysql freeradius-utils freeradius-common
        rm -f /usr/sbin/policy-rc.d
        [[ -d "${FR_DIR}/mods-available" ]] && [[ -f "${FR_DIR}/radiusd.conf" ]] \
            || error "Falha ao restaurar estrutura FreeRADIUS. \
Verifique: dpkg -l freeradius freeradius-config"
    fi

    # ── Dicionário MikroTik ────────────────────────────────────────────────
    [[ -f "${INSTALL_DIR}/freeradius/dictionary.mikrotik" ]] \
        || error "Arquivo ausente: ${INSTALL_DIR}/freeradius/dictionary.mikrotik"
    cp "${INSTALL_DIR}/freeradius/dictionary.mikrotik" \
       /usr/share/freeradius/dictionary.mikrotik
    grep -q "dictionary.mikrotik" /usr/share/freeradius/dictionary \
        || echo '$INCLUDE dictionary.mikrotik' >> /usr/share/freeradius/dictionary
    success "Dicionário MikroTik instalado."

    # ── Módulo SQL ─────────────────────────────────────────────────────────
    [[ -f "${INSTALL_DIR}/freeradius/mods-available/sql" ]] \
        || error "Arquivo ausente: ${INSTALL_DIR}/freeradius/mods-available/sql"
    cp "${INSTALL_DIR}/freeradius/mods-available/sql" \
       "${FR_DIR}/mods-available/sql"

    # Substitui qualquer valor de password = "..." pela senha atual.
    # O padrão cobre tanto a instalação inicial ("secret") quanto
    # re-execuções (senha anterior já gravada no arquivo).
    sed -i "s|password = \"[^\"]*\"|password = \"${DB_PASS}\"|g" \
        "${FR_DIR}/mods-available/sql"

    ln -sf "${FR_DIR}/mods-available/sql" "${FR_DIR}/mods-enabled/sql" 2>/dev/null || true
    success "Módulo SQL configurado."

    # ── Módulos necessários ────────────────────────────────────────────────
    for mod in preprocess pap chap acct_unique attr_filter; do
        [[ -f "${FR_DIR}/mods-available/${mod}" ]] && \
            ln -sf "${FR_DIR}/mods-available/${mod}" \
                   "${FR_DIR}/mods-enabled/${mod}" 2>/dev/null || true
    done
    success "Módulos habilitados."

    # ── Virtual server hotspot ─────────────────────────────────────────────
    [[ -f "${INSTALL_DIR}/freeradius/sites-available/hotspot" ]] \
        || error "Arquivo ausente: ${INSTALL_DIR}/freeradius/sites-available/hotspot"
    cp "${INSTALL_DIR}/freeradius/sites-available/hotspot" \
       "${FR_DIR}/sites-available/hotspot"
    ln -sf "${FR_DIR}/sites-available/hotspot" \
           "${FR_DIR}/sites-enabled/hotspot" 2>/dev/null || true
    success "Virtual server 'hotspot' ativado."

    # Desabilita o site 'default' do pacote — ele também declara listen { port = 0 }
    # para auth (1812) e acct (1813). Com 'hotspot' fazendo o mesmo, o segundo bind
    # falha com "Address already in use". O 'hotspot' é o único server necessário.
    rm -f "${FR_DIR}/sites-enabled/default" 2>/dev/null || true
    info "Site 'default' desabilitado (evita conflito de porta com 'hotspot')."

    # ── clients.conf ──────────────────────────────────────────────────────
    # Remove o bloco localhost_radtest se foi adicionado por versões anteriores
    # do instalador — causava "Failed to add duplicate client localhost" porque
    # o FreeRADIUS já tem um "client localhost" padrão para 127.0.0.1.
    if grep -q "client localhost_radtest" "${FR_DIR}/clients.conf"; then
        # Remove o bloco completo (da linha "client localhost_radtest" até "}")
        sed -i '/^client localhost_radtest/,/^}/d' "${FR_DIR}/clients.conf"
        info "Bloco localhost_radtest duplicado removido do clients.conf."
    fi

    # O FreeRADIUS já inclui um "client localhost" padrão para 127.0.0.1.
    # NÃO adicionamos outro cliente com o mesmo IP — causaria erro fatal:
    # "Failed to add duplicate client localhost".
    # Atualizamos o secret dos clientes padrão e adicionamos apenas o MikroTik.

    # Atualiza secrets dos clientes padrão (localhost e localhost_ipv6)
    sed -i "/^client localhost[^_]/,/^}/ s|secret\s*=.*|secret    = ${RADIUS_SECRET}|" \
        "${FR_DIR}/clients.conf" 2>/dev/null || true
    sed -i "/^client localhost_ipv6/,/^}/ s|secret\s*=.*|secret    = ${RADIUS_SECRET}|" \
        "${FR_DIR}/clients.conf" 2>/dev/null || true

    # Adiciona cliente MikroTik se ainda não existir; sincroniza secret se existir
    if ! grep -q "client mikrotik_hotspot" "${FR_DIR}/clients.conf"; then
        cat >> "${FR_DIR}/clients.conf" <<EOF

# ── Hotspot Manager — adicionado em $(date -Iseconds) ──
client mikrotik_hotspot {
    ipaddr    = ${MIKROTIK_IP}
    secret    = ${RADIUS_SECRET}
    shortname = mikrotik
    nastype   = other
    require_message_authenticator = no
}
EOF
        success "MikroTik (${MIKROTIK_IP}) adicionado ao clients.conf."
    else
        sed -i "/client mikrotik_hotspot/,/^}/ s|secret\s*=.*|secret    = ${RADIUS_SECRET}|" \
            "${FR_DIR}/clients.conf" 2>/dev/null || true
        info "clients.conf: secret MikroTik sincronizado."
    fi

    # ── Permissões ─────────────────────────────────────────────────────────
    chown -R freerad:freerad "${FR_DIR}"

    # ── Valida configuração ────────────────────────────────────────────────
    # Usa código de saída, não grep — palavras como "send_error" dariam falso positivo
    local FR_CHECK FR_OK=0
    FR_CHECK=$(freeradius -XC 2>&1) || FR_OK=$?

    if [[ $FR_OK -ne 0 ]]; then
        warn "FreeRADIUS: configuração inválida (código ${FR_OK}):"
        echo "$FR_CHECK" | tail -20
        warn "Corrija e rode: systemctl restart freeradius"
        return 0   # não aborta — admin pode corrigir manualmente
    fi

    # ── Verifica conectividade MariaDB antes de iniciar ───────────────────
    # freeradius -XC não testa a conexão real — o daemon falha ao iniciar o pool.
    # Confirma aqui com os mesmos parâmetros do módulo SQL (TCP 127.0.0.1:3306).
    info "Verificando acesso MariaDB para FreeRADIUS (TCP 127.0.0.1:3306)..."
    mariadb -u radius -p"${DB_PASS}" -h 127.0.0.1 --protocol=tcp radius \
        -e "SELECT 1 FROM information_schema.tables \
            WHERE table_schema='radius' AND table_name='radcheck' LIMIT 1;" \
        &>/dev/null \
        || error "FreeRADIUS não consegue conectar ao MariaDB via TCP. \
Verifique: GRANT para 'radius'@'127.0.0.1' e se tabela radcheck existe."
    success "MariaDB acessível via TCP — FreeRADIUS pode conectar."

    # ── Override do ExecStartPre defeituoso ────────────────────────────────
    # No Debian 13, freeradius.service tem:
    #   ExecStartPre=/usr/sbin/freeradius $FREERADIUS_OPTIONS -Cx -lstdout
    # O flag -Cx retorna exit code 1 mesmo quando a configuração está correta,
    # impedindo o ExecStart de rodar. Nossa validação com -XC acima já garante
    # que a config é válida — o ExecStartPre é redundante e defeituoso aqui.
    mkdir -p /etc/systemd/system/freeradius.service.d/
    cat > /etc/systemd/system/freeradius.service.d/override.conf << 'OVERRIDE'
[Service]
ExecStartPre=
OVERRIDE
    systemctl daemon-reload
    info "Override ExecStartPre aplicado (freeradius.service.d/override.conf)."

    # ── Limpa estado antes de iniciar ─────────────────────────────────────
    # Processos freeradius de sessões anteriores (loop de restart) podem estar
    # segurando as portas 1812/1813 UDP, impedindo o novo start.
    systemctl stop freeradius 2>/dev/null || true
    pkill -x freeradius      2>/dev/null || true
    sleep 1
    # Confirma que as portas estão livres
    if ss -ulnp 2>/dev/null | grep -qE ':1812|:1813'; then
        warn "Porta RADIUS ainda em uso após stop. Forçando kill..."
        pkill -9 -x freeradius 2>/dev/null || true
        sleep 2
    fi
    # Reseta estado de falha do systemd (evita que o restart counter bloqueie o start)
    systemctl reset-failed freeradius 2>/dev/null || true

    systemctl enable freeradius
    _service_restart freeradius
    success "FreeRADIUS iniciado."

    # Persiste secret
    printf '# Hotspot Manager — RADIUS\nRADIUS_SECRET=%s\nMIKROTIK_IP=%s\n' \
        "${RADIUS_SECRET}" "${MIKROTIK_IP}" > "$STATE_RADIUS"
    chmod 600 "$STATE_RADIUS"
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 7 — WEB SERVER
# ══════════════════════════════════════════════════════════════════════════════
install_webserver() {
    step "7/9 — ${WEB_SERVER}"
    [[ "$WEB_SERVER" == "nginx" ]] && _setup_nginx || _setup_apache
}

_setup_nginx() {
    apt-get install -y -qq nginx

    cat > /etc/nginx/sites-available/hotspot-manager <<EOF
# Hotspot Manager — Nginx  (gerado em $(date -Iseconds))
server {
    listen ${APP_PORT};
    listen [::]:${APP_PORT};
    server_name ${APP_HOST};

    root ${INSTALL_DIR}/public;
    index index.php index.html;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    server_tokens off;

    access_log /var/log/nginx/hotspot-manager.access.log;
    error_log  /var/log/nginx/hotspot-manager.error.log warn;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass   unix:/run/php/php8.2-fpm.sock;
        fastcgi_param  SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_read_timeout 60;
    }

    location ~ /\.(?!well-known).* { deny all; }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|woff|woff2|svg)\$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    client_max_body_size 25M;
}
EOF

    ln -sf /etc/nginx/sites-available/hotspot-manager \
           /etc/nginx/sites-enabled/hotspot-manager
    rm -f /etc/nginx/sites-enabled/default

    nginx -t 2>&1 || error "Configuração Nginx inválida (ver acima)."
    systemctl enable nginx
    _service_restart nginx
    success "Nginx na porta ${APP_PORT}."
}

_setup_apache() {
    apt-get install -y -qq apache2 libapache2-mod-php8.2
    a2enmod rewrite php8.2 headers deflate

    cat > /etc/apache2/sites-available/hotspot-manager.conf <<EOF
# Hotspot Manager — Apache2  (gerado em $(date -Iseconds))
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

    [[ "$APP_PORT" != "80" ]] && \
        { grep -q "Listen ${APP_PORT}" /etc/apache2/ports.conf \
            || echo "Listen ${APP_PORT}" >> /etc/apache2/ports.conf; }

    a2ensite hotspot-manager.conf
    a2dissite 000-default.conf 2>/dev/null || true
    apache2ctl configtest 2>&1 || error "Configuração Apache2 inválida (ver acima)."
    systemctl enable apache2
    _service_restart apache2
    success "Apache2 na porta ${APP_PORT}."
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 8 — FIREWALL
# ══════════════════════════════════════════════════════════════════════════════
configure_firewall() {
    step "8/9 — Firewall (UFW)"

    # Não faz reset das regras — preserva configurações existentes (ex: SSH já liberado)
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    # SSH — garante que não bloqueie o acesso remoto
    ufw allow 22/tcp           comment "SSH" 2>/dev/null || true
    [[ "$APP_PORT" != "80" ]] && { ufw allow 80/tcp comment "HTTP" 2>/dev/null || true; }
    ufw allow "${APP_PORT}/tcp" comment "Hotspot Manager" 2>/dev/null || true
    ufw allow 443/tcp          comment "HTTPS" 2>/dev/null || true
    ufw allow from "${MIKROTIK_IP}" to any port 1812 proto udp comment "RADIUS Auth" 2>/dev/null || true
    ufw allow from "${MIKROTIK_IP}" to any port 1813 proto udp comment "RADIUS Acct" 2>/dev/null || true
    ufw allow from 127.0.0.1   to any port 1812 proto udp comment "RADIUS local" 2>/dev/null || true
    ufw allow from 127.0.0.1   to any port 1813 proto udp comment "RADIUS local" 2>/dev/null || true
    success "Firewall ativo."
    ufw status numbered
}

# ══════════════════════════════════════════════════════════════════════════════
# PASSO 9 — CRON + LOGROTATE
# ══════════════════════════════════════════════════════════════════════════════
configure_cron() {
    step "9/9 — Cron e Logrotate"

    local CRON_TMP
    CRON_TMP=$(mktemp)
    crontab -l 2>/dev/null > "$CRON_TMP" || true

    # Remove entradas antigas e regrava (idempotente)
    grep -v "hotspot-manager\|artisan\|radacct" "$CRON_TMP" \
        > "${CRON_TMP}.clean" || true
    mv "${CRON_TMP}.clean" "$CRON_TMP"

    cat >> "$CRON_TMP" <<EOF

# ── Hotspot Manager ────────────────────────────────────────────
# Laravel Scheduler
* * * * * cd ${INSTALL_DIR} && php artisan schedule:run >> /dev/null 2>&1
# Expira usuários vencidos (01:00)
0 1 * * * cd ${INSTALL_DIR} && php artisan hotspot:expire-users >> /dev/null 2>&1
# Purga sessões RADIUS > 90 dias (domingo 03:00)
0 3 * * 0 mariadb radius -e "DELETE FROM radacct WHERE acctstoptime < DATE_SUB(NOW(), INTERVAL 90 DAY);" >> /dev/null 2>&1
EOF

    crontab "$CRON_TMP"
    rm -f "$CRON_TMP"
    success "Cron configurado."

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
        find ${INSTALL_DIR}/storage/logs -name "*.log" -mtime +30 -delete 2>/dev/null || true
    endscript
}
EOF
    success "Logrotate configurado."
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO FINAL + ARQUIVO DE CREDENCIAIS
# ══════════════════════════════════════════════════════════════════════════════
print_summary() {
    local SERVER_IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    local NOW
    NOW=$(date "+%d/%m/%Y %H:%M:%S")

    cat > "$CRED_FILE" <<EOF
================================================================================
  HOTSPOT MANAGER — CREDENCIAIS
  Modo    : ${MODE^^}
  Gerado  : ${NOW}
================================================================================

ACESSO AO PAINEL
  URL Admin     : http://${APP_HOST}:${APP_PORT}/admin
  URL Portal    : http://${APP_HOST}:${APP_PORT}/portal
  Login         : admin@hotspot.local
  Senha         : ${ADMIN_PASS}

BANCO DE DADOS (MariaDB)
  Host    : 127.0.0.1:3306
  Banco   : radius
  Usuário : radius
  Senha   : ${DB_PASS}
  Acesso  : mariadb -u radius -p'${DB_PASS}' -h 127.0.0.1 radius

FREERADIUS
  RADIUS Secret : ${RADIUS_SECRET}
  Auth          : 1812/udp
  Acct          : 1813/udp
  MikroTik IP   : ${MIKROTIK_IP}

SERVIDOR
  IP            : ${SERVER_IP}
  Diretório     : ${INSTALL_DIR}
  Web server    : ${WEB_SERVER}

MIKROTIK — cole no terminal do RouterOS:
  /radius add \\
      service=hotspot \\
      address=${SERVER_IP} \\
      secret=${RADIUS_SECRET} \\
      authentication-port=1812 \\
      accounting-port=1813
  /ip hotspot profile set [find] use-radius=yes radius-accounting=yes

TESTE RADIUS:
  radtest usuario senha 127.0.0.1 0 ${RADIUS_SECRET}

DIAGNÓSTICO:
  journalctl -u freeradius -f
  journalctl -u ${WEB_SERVER} -f
  tail -f ${INSTALL_DIR}/storage/logs/laravel.log
  freeradius -X

LOG DE INSTALAÇÃO:
  /var/log/hotspot-manager-install.log

================================================================================
  REMOVA ESTE ARQUIVO APÓS GUARDAR AS SENHAS: rm -f ${CRED_FILE}
================================================================================
EOF
    chmod 600 "$CRED_FILE"

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    printf "║  %-66s  ║\n" "$([ "$MODE" == "update" ] && echo "ATUALIZAÇÃO CONCLUÍDA!" || echo "INSTALAÇÃO CONCLUÍDA!")"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo -e "║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Admin  :  ${BOLD}http://${APP_HOST}:${APP_PORT}/admin${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Portal :  ${BOLD}http://${APP_HOST}:${APP_PORT}/portal${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Login  :  ${BOLD}admin@hotspot.local${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Senha  :  ${BOLD}${ADMIN_PASS}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  DB     :  ${BOLD}${DB_PASS}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  RADIUS :  ${BOLD}${RADIUS_SECRET}${NC}"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════════════════════╣"
    echo -e "║${NC}  MikroTik (cole no RouterOS):${GREEN}${BOLD}"
    echo -e "╠════════════════════════════════════════════════════════════════════╣${NC}"
    printf "  /radius add \\\\\n"
    printf "      service=hotspot \\\\\n"
    printf "      address=%s \\\\\n" "$SERVER_IP"
    printf "      secret=%s \\\\\n" "$RADIUS_SECRET"
    printf "      authentication-port=1812 \\\\\n"
    printf "      accounting-port=1813\n\n"
    printf "  /ip hotspot profile set [find] use-radius=yes radius-accounting=yes\n\n"
    echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════════════════════╣${NC}"
    echo "  Credenciais completas: ${CRED_FILE}"
    echo "  Log de instalação   : /var/log/hotspot-manager-install.log"
    echo -e "${YELLOW}${BOLD}  Guarde as credenciais acima antes de fechar o terminal!${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# HELPER — restart seguro (funciona para serviço parado ou rodando)
# ══════════════════════════════════════════════════════════════════════════════
_service_restart() {
    local SVC="$1"
    if systemctl is-active --quiet "$SVC"; then
        systemctl restart "$SVC" \
            || { journalctl -u "$SVC" -n 20 --no-pager || true
                 error "${SVC} falhou ao reiniciar."; }
    else
        if ! systemctl start "$SVC"; then
            journalctl -u "$SVC" -n 20 --no-pager || true
            error "${SVC} falhou ao iniciar."
        fi
    fi
    success "${SVC} rodando."
}

# ══════════════════════════════════════════════════════════════════════════════
# TRAP DE ERROS
# ══════════════════════════════════════════════════════════════════════════════
on_error() {
    echo -e "\n${RED}${BOLD}[ERRO FATAL]${NC} Falha na linha $1."
    echo "Log completo: /var/log/hotspot-manager-install.log"
    # Remove policy-rc.d caso o erro tenha ocorrido durante apt-get install
    rm -f /usr/sbin/policy-rc.d 2>/dev/null || true
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

    local LOG_FILE="/var/log/hotspot-manager-install.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo "════ Início: $(date -Iseconds) — modo: ${MODE} ════"

    update_system
    install_php
    install_composer
    install_mariadb
    install_app
    install_freeradius
    install_webserver
    configure_firewall
    configure_cron

    echo "════ Fim: $(date -Iseconds) ════"
    print_summary
}

main "$@"

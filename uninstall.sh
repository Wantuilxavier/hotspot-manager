#!/usr/bin/env bash
# ==============================================================================
#  Hotspot Manager — Desinstalador / Limpeza Total  v1.0
#  Alvo  : Debian 13 (Trixie) / Debian 12 (Bookworm)
#  Uso   : bash uninstall.sh   (execute como root)
#  AVISO : Remove TUDO — banco de dados, aplicação, configurações.
#          Não há desfazer. Faça backup antes se necessário.
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
step()    { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}"; }

# ── Constantes (devem coincidir com install.sh) ────────────────────────────────
INSTALL_DIR="/var/www/hotspot-manager"
STATE_DB="/root/.hotspot_db.env"
STATE_RADIUS="/root/.hotspot_radius.env"
STATE_ADMIN="/root/.hotspot_admin.env"
CRED_FILE="/root/hotspot-manager-credentials.txt"

# ══════════════════════════════════════════════════════════════════════════════
# CONFIRMAÇÃO
# ══════════════════════════════════════════════════════════════════════════════
confirm() {
    [[ $EUID -eq 0 ]] || { echo -e "${RED}Execute como root: bash $0${NC}"; exit 1; }

    echo ""
    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║          DESINSTALAÇÃO COMPLETA DO HOTSPOT MANAGER                  ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║  Será removido:                                                      ║"
    echo "║   • Aplicação Laravel  (/var/www/hotspot-manager)                   ║"
    echo "║   • Banco de dados MariaDB  (banco 'radius' + usuário 'radius')     ║"
    echo "║   • FreeRADIUS 3 (pacotes + configuração)                           ║"
    echo "║   • PHP 8.2 FPM + extensões                                         ║"
    echo "║   • Nginx (configuração do site)                                    ║"
    echo "║   • Regras UFW do Hotspot Manager                                   ║"
    echo "║   • Cron jobs e logrotate                                            ║"
    echo "║   • Arquivos de estado (/root/.hotspot_*.env)                       ║"
    echo "║                                                                      ║"
    echo "║  MariaDB, PHP, Nginx e UFW em si NÃO são desinstalados por padrão.  ║"
    echo "║  Use --purge-packages para remover também os pacotes do sistema.    ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    read -r -p "$(echo -e "${YELLOW}${BOLD}Digite CONFIRMAR para continuar (Ctrl+C para cancelar): ${NC}")" RESP
    [[ "$RESP" == "CONFIRMAR" ]] || { echo "Cancelado."; exit 0; }
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# 1 — SERVIÇOS
# ══════════════════════════════════════════════════════════════════════════════
stop_services() {
    step "1/7 — Parando serviços"

    for svc in freeradius nginx php8.2-fpm apache2; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc"   && info "${svc} parado."
        fi
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            systemctl disable "$svc" 2>/dev/null || true
        fi
        systemctl reset-failed "$svc" 2>/dev/null || true
    done

    # Garante que processos freeradius órfãos sejam encerrados
    pkill -x freeradius 2>/dev/null || true
    sleep 1

    success "Serviços parados."
}

# ══════════════════════════════════════════════════════════════════════════════
# 2 — BANCO DE DADOS
# ══════════════════════════════════════════════════════════════════════════════
remove_database() {
    step "2/7 — Removendo banco de dados MariaDB"

    if ! systemctl is-active --quiet mariadb 2>/dev/null; then
        warn "MariaDB não está rodando — pulando remoção do banco."
        return 0
    fi

    local SOCKET=""
    for s in /run/mysqld/mysqld.sock /var/run/mysqld/mysqld.sock /tmp/mysql.sock; do
        [[ -S "$s" ]] && { SOCKET="$s"; break; }
    done

    if [[ -z "$SOCKET" ]]; then
        warn "Socket MariaDB não encontrado — pulando remoção do banco."
        return 0
    fi

    runuser -u mysql -- mariadb --socket="${SOCKET}" 2>/dev/null <<SQL || warn "Erro ao remover banco/usuário (pode já não existir)."
DROP DATABASE  IF EXISTS radius;
DROP USER IF EXISTS 'radius'@'localhost';
DROP USER IF EXISTS 'radius'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

    success "Banco 'radius' e usuário 'radius' removidos."
}

# ══════════════════════════════════════════════════════════════════════════════
# 3 — FREERADIUS
# ══════════════════════════════════════════════════════════════════════════════
remove_freeradius() {
    step "3/7 — Removendo FreeRADIUS"

    if dpkg -l freeradius &>/dev/null; then
        # freeradius-config DEVE ser purgado aqui — se omitido, dpkg mantém o
        # estado dos conffiles. Ao fazer rm -rf /etc/freeradius a seguir, o dpkg
        # marca esses arquivos como "user-deleted", causando falha no próximo install.
        apt-get purge -y -qq "freeradius*" 2>/dev/null || true
        apt-get autoremove -y -qq 2>/dev/null || true
        success "Pacotes FreeRADIUS removidos."
    else
        info "FreeRADIUS não instalado via apt — nada a remover."
    fi

    # Remove resíduos de configuração
    rm -rf /etc/freeradius /var/log/freeradius /var/run/freeradius 2>/dev/null || true
    rm -f /usr/share/freeradius/dictionary.mikrotik 2>/dev/null || true

    # Remove linha do dicionário MikroTik se foi adicionada
    local DICT_MAIN="/usr/share/freeradius/dictionary"
    if [[ -f "$DICT_MAIN" ]]; then
        sed -i '/dictionary\.mikrotik/d' "$DICT_MAIN" 2>/dev/null || true
    fi

    success "FreeRADIUS limpo."
}

# ══════════════════════════════════════════════════════════════════════════════
# 4 — APLICAÇÃO LARAVEL
# ══════════════════════════════════════════════════════════════════════════════
remove_app() {
    step "4/7 — Removendo aplicação Laravel"

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        success "Diretório ${INSTALL_DIR} removido."
    else
        info "${INSTALL_DIR} não existe — nada a remover."
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 5 — WEB SERVER (apenas configuração do site)
# ══════════════════════════════════════════════════════════════════════════════
remove_webserver_config() {
    step "5/7 — Removendo configuração do web server"

    # Nginx
    if [[ -f /etc/nginx/sites-enabled/hotspot-manager ]]; then
        rm -f /etc/nginx/sites-enabled/hotspot-manager
    fi
    if [[ -f /etc/nginx/sites-available/hotspot-manager ]]; then
        rm -f /etc/nginx/sites-available/hotspot-manager
        success "Configuração Nginx removida."
    fi
    # Reativa o site padrão do Nginx se existir
    if [[ -f /etc/nginx/sites-available/default ]] \
       && [[ ! -L /etc/nginx/sites-enabled/default ]]; then
        ln -sf /etc/nginx/sites-available/default \
               /etc/nginx/sites-enabled/default 2>/dev/null || true
        info "Site padrão Nginx reativado."
    fi
    if systemctl is-active --quiet nginx 2>/dev/null; then
        nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    fi

    # Apache2
    if [[ -f /etc/apache2/sites-available/hotspot-manager.conf ]]; then
        a2dissite hotspot-manager.conf 2>/dev/null || true
        rm -f /etc/apache2/sites-available/hotspot-manager.conf
        success "Configuração Apache2 removida."
    fi

    # Logs do web server
    rm -f /var/log/nginx/hotspot-manager.*.log 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════════════════════
# 6 — CRON, LOGROTATE, REGRAS UFW
# ══════════════════════════════════════════════════════════════════════════════
remove_misc() {
    step "6/7 — Removendo cron, logrotate e regras UFW"

    # Cron — remove entradas do Hotspot Manager
    if crontab -l 2>/dev/null | grep -q "hotspot-manager\|artisan\|radacct"; then
        local CRON_TMP
        CRON_TMP=$(mktemp)
        crontab -l 2>/dev/null \
            | grep -v "hotspot-manager\|artisan\|radacct\|Hotspot Manager" \
            > "$CRON_TMP" || true
        crontab "$CRON_TMP"
        rm -f "$CRON_TMP"
        success "Entradas de cron removidas."
    else
        info "Nenhuma entrada de cron do Hotspot Manager encontrada."
    fi

    # Logrotate
    rm -f /etc/logrotate.d/hotspot-manager 2>/dev/null || true
    success "Logrotate removido."

    # UFW — remove regras com comentário "RADIUS" ou "Hotspot Manager"
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        # Deleta regras de trás para frente (índices mudam ao deletar de frente)
        local UFW_RULES
        UFW_RULES=$(ufw status numbered 2>/dev/null \
            | grep -E 'RADIUS|Hotspot' \
            | grep -oP '^\[\s*\K[0-9]+' \
            | sort -rn)
        if [[ -n "$UFW_RULES" ]]; then
            while IFS= read -r idx; do
                ufw --force delete "$idx" 2>/dev/null || true
            done <<< "$UFW_RULES"
            success "Regras UFW do Hotspot Manager removidas."
        else
            info "Nenhuma regra UFW específica do Hotspot Manager encontrada."
        fi
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# 7 — ARQUIVOS DE ESTADO E CREDENCIAIS
# ══════════════════════════════════════════════════════════════════════════════
remove_state_files() {
    step "7/7 — Removendo arquivos de estado"

    rm -f "$STATE_DB" "$STATE_RADIUS" "$STATE_ADMIN" 2>/dev/null || true
    rm -f /root/.my.cnf 2>/dev/null || true
    rm -f /var/log/hotspot-manager-install.log 2>/dev/null || true

    # Credenciais: avisa antes de remover
    if [[ -f "$CRED_FILE" ]]; then
        warn "Arquivo de credenciais encontrado: ${CRED_FILE}"
        warn "Removendo. Certifique-se de ter guardado as senhas."
        rm -f "$CRED_FILE"
    fi

    success "Arquivos de estado removidos."
}

# ══════════════════════════════════════════════════════════════════════════════
# OPCIONAL — remove também os pacotes do sistema
# ══════════════════════════════════════════════════════════════════════════════
purge_packages() {
    step "Extra — Removendo pacotes do sistema"
    warn "Isso remove PHP 8.2, MariaDB, Nginx, Composer e repositórios adicionais."

    # PHP 8.2
    apt-get purge -y -qq "php8.2*" 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/sury-php.list \
          /usr/share/keyrings/sury-php.gpg 2>/dev/null || true
    success "PHP 8.2 removido."

    # MariaDB — desinstala mas preserva o serviço para outros bancos
    apt-get purge -y -qq mariadb-server mariadb-client 2>/dev/null || true
    rm -rf /var/lib/mysql /etc/mysql /var/log/mysql 2>/dev/null || true
    success "MariaDB removido."

    # Nginx
    apt-get purge -y -qq nginx nginx-common 2>/dev/null || true
    rm -rf /etc/nginx /var/log/nginx 2>/dev/null || true
    success "Nginx removido."

    # Composer
    rm -f /usr/local/bin/composer 2>/dev/null || true
    success "Composer removido."

    # Repositório MariaDB
    rm -f /etc/apt/sources.list.d/mariadb.list \
          /usr/share/keyrings/mariadb-keyring.pgp 2>/dev/null || true

    apt-get autoremove -y -qq 2>/dev/null || true
    apt-get autoclean -qq     2>/dev/null || true
    success "Pacotes e dependências removidos."
}

# ══════════════════════════════════════════════════════════════════════════════
# RESUMO FINAL
# ══════════════════════════════════════════════════════════════════════════════
print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║           DESINSTALAÇÃO CONCLUÍDA                                    ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo -e "║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Removido:"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ Aplicação Laravel       (${INSTALL_DIR})"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ Banco de dados          (radius)"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ FreeRADIUS 3"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ Configuração web server"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ Cron + logrotate"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ Regras UFW"
    echo -e "${GREEN}${BOLD}║${NC}   ✓ Arquivos de estado"
    echo -e "${GREEN}${BOLD}║${NC}"

    if [[ "${PURGE:-0}" == "1" ]]; then
        echo -e "${GREEN}${BOLD}║${NC}   ✓ Pacotes do sistema (--purge-packages)"
        echo -e "${GREEN}${BOLD}║${NC}"
    else
        echo -e "${YELLOW}${BOLD}║${NC}  Mantido (pacotes do sistema):"
        echo -e "${YELLOW}${BOLD}║${NC}   • MariaDB, PHP 8.2, Nginx, Composer"
        echo -e "${YELLOW}${BOLD}║${NC}   → Para remover: bash $0 --purge-packages"
        echo -e "${GREEN}${BOLD}║${NC}"
    fi

    echo -e "${GREEN}${BOLD}║${NC}  Para reinstalar:"
    echo -e "${GREEN}${BOLD}║${NC}   bash install.sh"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
PURGE=0
[[ "${1:-}" == "--purge-packages" ]] && PURGE=1

confirm
stop_services
remove_database
remove_freeradius
remove_app
remove_webserver_config
remove_misc
remove_state_files

[[ "$PURGE" == "1" ]] && purge_packages

print_summary

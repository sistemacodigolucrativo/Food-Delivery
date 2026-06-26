#!/bin/bash

# ==============================================================================
# Pré-Instalador Automatizado - Food Delivery (StackFood)
# Compatível com Ubuntu 22.04 LTS e Ubuntu 24.04 LTS
# Versão: 2.1
# ==============================================================================

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERRO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}${BOLD}>>> $1${NC}"; }

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script precisa ser executado como root."
    echo "Execute: sudo bash pre-instalador.sh"
    exit 1
fi

# Verificar sistema operacional
OS_ID=$(. /etc/os-release && echo "$ID")
OS_VERSION=$(. /etc/os-release && echo "$VERSION_ID")
if [[ "$OS_ID" != "ubuntu" ]]; then
    log_error "Este script foi desenvolvido para Ubuntu. Sistema detectado: $OS_ID"
    exit 1
fi

# Variáveis de configuração
PHP_VERSION="8.2"
DB_NAME="stackfood_db"
DB_USER="stackfood_user"
DB_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
WEB_DIR="/var/www/html/food-delivery"
LOG_FILE="/var/log/food-delivery-install.log"
PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')

# Arquivo de log (sem exec tee para compatibilidade com SSH sem TTY)
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/food-delivery-install.log"

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║         PRÉ-INSTALADOR - FOOD DELIVERY (STACKFOOD)           ║"
echo "  ║                  Versão 2.1 | Ubuntu 22/24                   ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
log_info "Sistema detectado: Ubuntu $OS_VERSION"
log_info "IP Público: $PUBLIC_IP"
log_info "Log de instalação: $LOG_FILE"
echo ""

# Função para logar e exibir
run_cmd() {
    local desc="$1"
    shift
    log_info "$desc"
    "$@" >> "$LOG_FILE" 2>&1
    local status=$?
    if [ $status -ne 0 ]; then
        log_error "Falha em: $desc (código $status). Verifique $LOG_FILE"
        return $status
    fi
    return 0
}

# ==============================================================================
# ETAPA 1: Atualizar o sistema
# ==============================================================================
log_step "ETAPA 1/9 - Atualizando repositórios e pacotes do sistema"
export DEBIAN_FRONTEND=noninteractive
run_cmd "Atualizando listas de pacotes" apt-get update -y
run_cmd "Atualizando pacotes instalados" apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
log_success "Sistema atualizado."

# ==============================================================================
# ETAPA 2: Instalar utilitários básicos
# ==============================================================================
log_step "ETAPA 2/9 - Instalando utilitários essenciais"
run_cmd "Instalando utilitários" apt-get install -y \
    curl wget git unzip zip \
    software-properties-common \
    ca-certificates lsb-release \
    apt-transport-https \
    gnupg2 \
    openssl \
    cron \
    supervisor
log_success "Utilitários instalados."

# ==============================================================================
# ETAPA 3: Adicionar repositório PHP (Ondrej) e instalar PHP 8.2
# ==============================================================================
log_step "ETAPA 3/9 - Instalando PHP $PHP_VERSION e extensões"

# Verificar se o repositório já existe
if ! grep -r "ondrej/php" /etc/apt/sources.list.d/ &>/dev/null; then
    log_info "Adicionando repositório PPA Ondrej/PHP..."
    add-apt-repository ppa:ondrej/php -y >> "$LOG_FILE" 2>&1
    apt-get update -y >> "$LOG_FILE" 2>&1
fi

# Instalar PHP e extensões (sodium está incluída em php-common no Ubuntu 24.04)
log_info "Instalando PHP ${PHP_VERSION} e extensões..."
apt-get install -y \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-readline \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-soap \
    libapache2-mod-php${PHP_VERSION} >> "$LOG_FILE" 2>&1

# Instalar imagick se disponível
apt-get install -y php${PHP_VERSION}-imagick >> "$LOG_FILE" 2>&1 || log_warn "php${PHP_VERSION}-imagick não disponível, pulando."

# Definir PHP 8.2 como padrão
update-alternatives --set php /usr/bin/php${PHP_VERSION} >> "$LOG_FILE" 2>&1 || true

log_success "PHP $PHP_VERSION instalado: $(php${PHP_VERSION} -v 2>/dev/null | head -1)"

# ==============================================================================
# ETAPA 4: Instalar Apache
# ==============================================================================
log_step "ETAPA 4/9 - Configurando Apache"

# Apache já pode estar instalado
if ! dpkg -l apache2 &>/dev/null; then
    run_cmd "Instalando Apache" apt-get install -y apache2
fi

# Habilitar módulos necessários
log_info "Habilitando módulos do Apache..."
a2enmod rewrite >> "$LOG_FILE" 2>&1
a2enmod headers >> "$LOG_FILE" 2>&1
a2enmod ssl >> "$LOG_FILE" 2>&1
a2enmod php${PHP_VERSION} >> "$LOG_FILE" 2>&1 || true

systemctl enable apache2 >> "$LOG_FILE" 2>&1
systemctl start apache2 >> "$LOG_FILE" 2>&1 || systemctl restart apache2 >> "$LOG_FILE" 2>&1
log_success "Apache configurado e em execução."

# ==============================================================================
# ETAPA 5: Instalar e configurar MariaDB
# ==============================================================================
log_step "ETAPA 5/9 - Instalando e configurando MariaDB"

run_cmd "Instalando MariaDB" apt-get install -y mariadb-server mariadb-client
systemctl enable mariadb >> "$LOG_FILE" 2>&1
systemctl start mariadb >> "$LOG_FILE" 2>&1

# Configurar banco de dados (idempotente)
log_info "Criando banco de dados e usuário..."
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>>"$LOG_FILE"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>>"$LOG_FILE"
mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" 2>>"$LOG_FILE"
mysql -e "FLUSH PRIVILEGES;" 2>>"$LOG_FILE"

log_success "MariaDB configurado. Banco: $DB_NAME | Usuário: $DB_USER"

# ==============================================================================
# ETAPA 6: Instalar Composer
# ==============================================================================
log_step "ETAPA 6/9 - Instalando Composer"

if command -v composer &>/dev/null; then
    log_info "Composer já instalado. Versão: $(composer --version 2>/dev/null | head -1)"
    composer self-update >> "$LOG_FILE" 2>&1 || true
else
    log_info "Baixando e instalando Composer..."
    php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');" >> "$LOG_FILE" 2>&1
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer >> "$LOG_FILE" 2>&1
    rm -f /tmp/composer-setup.php
    chmod +x /usr/local/bin/composer
fi

log_success "Composer instalado: $(composer --version 2>/dev/null | head -1)"

# ==============================================================================
# ETAPA 7: Instalar Node.js 18 e NPM
# ==============================================================================
log_step "ETAPA 7/9 - Instalando Node.js 18 e NPM"

if command -v node &>/dev/null && node -v 2>/dev/null | grep -q "v18"; then
    log_info "Node.js 18 já instalado: $(node -v)"
else
    log_info "Instalando Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y nodejs >> "$LOG_FILE" 2>&1
fi

log_success "Node.js instalado: $(node -v 2>/dev/null) | NPM: $(npm -v 2>/dev/null)"

# ==============================================================================
# ETAPA 8: Configurar diretório e VirtualHost do Apache
# ==============================================================================
log_step "ETAPA 8/9 - Configurando diretório web e VirtualHost"

# Criar diretório do projeto
mkdir -p ${WEB_DIR}/public
chown -R www-data:www-data ${WEB_DIR}
chmod -R 755 ${WEB_DIR}

# Criar VirtualHost
cat > /etc/apache2/sites-available/food-delivery.conf <<VHOST
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${WEB_DIR}/public

    <Directory ${WEB_DIR}/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/food-delivery-error.log
    CustomLog \${APACHE_LOG_DIR}/food-delivery-access.log combined
</VirtualHost>
VHOST

# Desabilitar site padrão e habilitar o novo
a2dissite 000-default.conf >> "$LOG_FILE" 2>&1 || true
a2ensite food-delivery.conf >> "$LOG_FILE" 2>&1

log_success "VirtualHost configurado."

# ==============================================================================
# ETAPA 9: Ajustar configurações do PHP
# ==============================================================================
log_step "ETAPA 9/9 - Ajustando configurações do PHP"

for PHP_INI in "/etc/php/${PHP_VERSION}/apache2/php.ini" "/etc/php/${PHP_VERSION}/cli/php.ini"; do
    if [ -f "$PHP_INI" ]; then
        sed -i "s/^upload_max_filesize.*/upload_max_filesize = 128M/" $PHP_INI
        sed -i "s/^post_max_size.*/post_max_size = 128M/" $PHP_INI
        sed -i "s/^memory_limit.*/memory_limit = 512M/" $PHP_INI
        sed -i "s/^max_execution_time.*/max_execution_time = 600/" $PHP_INI
        sed -i "s/^max_input_vars.*/max_input_vars = 3000/" $PHP_INI
        sed -i "s/^allow_url_fopen.*/allow_url_fopen = On/" $PHP_INI
        log_success "PHP.ini configurado: $PHP_INI"
    fi
done

# Reiniciar Apache para aplicar todas as configurações
systemctl restart apache2 >> "$LOG_FILE" 2>&1
log_success "Apache reiniciado com as novas configurações."

# ==============================================================================
# Salvar credenciais em arquivo seguro
# ==============================================================================
CREDS_FILE="/root/.food-delivery-credentials"
cat > $CREDS_FILE <<CREDS
# Food Delivery - Credenciais de Instalação
# Geradas em: $(date)
IP_SERVIDOR=$PUBLIC_IP
BANCO_DE_DADOS=$DB_NAME
USUARIO_DB=$DB_USER
SENHA_DB=$DB_PASS
DIRETORIO_WEB=$WEB_DIR
URL_INSTALACAO=http://$PUBLIC_IP/install
CREDS
chmod 600 $CREDS_FILE

# ==============================================================================
# Exibir resultado final
# ==============================================================================
echo ""
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════════╗"
echo "  ║           PRÉ-INSTALAÇÃO CONCLUÍDA COM SUCESSO!                  ║"
echo "  ╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  O ambiente da VPS foi configurado como uma hospedagem convencional."
echo -e "  Todas as dependências foram instaladas e estão prontas para uso."
echo ""
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}${BOLD}  COMPONENTES INSTALADOS${NC}"
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Servidor Web:    ${GREEN}Apache $(apache2 -v 2>/dev/null | head -1 | awk '{print $3}')${NC}"
echo -e "  PHP:             ${GREEN}$(php${PHP_VERSION} -v 2>/dev/null | head -1)${NC}"
echo -e "  Banco de Dados:  ${GREEN}$(mysql --version 2>/dev/null | head -1)${NC}"
echo -e "  Composer:        ${GREEN}$(composer --version 2>/dev/null | head -1)${NC}"
echo -e "  Node.js:         ${GREEN}$(node -v 2>/dev/null)${NC}"
echo -e "  NPM:             ${GREEN}$(npm -v 2>/dev/null)${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}${BOLD}  DADOS DO BANCO DE DADOS${NC}"
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Host:            ${BLUE}127.0.0.1${NC}"
echo -e "  Porta:           ${BLUE}3306${NC}"
echo -e "  Banco de Dados:  ${BLUE}${DB_NAME}${NC}"
echo -e "  Usuário:         ${BLUE}${DB_USER}${NC}"
echo -e "  Senha:           ${BLUE}${DB_PASS}${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}${BOLD}  DADOS DO SERVIDOR${NC}"
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Endereço IP:     ${BLUE}${PUBLIC_IP}${NC}"
echo -e "  Porta HTTP:      ${BLUE}80${NC}"
echo -e "  Diretório Web:   ${BLUE}${WEB_DIR}${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}${BOLD}  PRÓXIMOS PASSOS${NC}"
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  1. Faça o upload do arquivo 'Admin panel new install V9.0.zip'"
echo -e "     para o diretório: ${BLUE}${WEB_DIR}${NC}"
echo ""
echo -e "  2. Extraia os arquivos:"
echo -e "     ${CYAN}cd ${WEB_DIR} && unzip 'Admin panel new install V9.0.zip'${NC}"
echo ""
echo -e "  3. Ajuste as permissões:"
echo -e "     ${CYAN}sudo chown -R www-data:www-data ${WEB_DIR}${NC}"
echo -e "     ${CYAN}sudo chmod -R 775 ${WEB_DIR}/storage ${WEB_DIR}/bootstrap/cache${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}${BOLD}  LINK DE INSTALACAO WEB${NC}"
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Apos enviar os arquivos, acesse o link abaixo para concluir:"
echo ""
echo -e "  ${GREEN}${BOLD}  -->  http://${PUBLIC_IP}/install${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  As credenciais foram salvas em: ${BLUE}/root/.food-delivery-credentials${NC}"
echo -e "  Log completo disponivel em:     ${BLUE}${LOG_FILE}${NC}"
echo ""
echo -e "${GREEN}${BOLD}  Instalacao concluida! Seu servidor esta pronto para receber o Food Delivery.${NC}"
echo ""

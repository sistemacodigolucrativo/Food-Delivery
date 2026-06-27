#!/bin/bash

# ==============================================================================
# Pré-Instalador Automatizado - Food Delivery (StackFood)
# Compatível com Ubuntu 22.04 LTS e Ubuntu 24.04 LTS
# Versão: 3.0
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

# Variáveis de configuração
PHP_VERSION="8.2"
DB_NAME="stackfood_db"
DB_USER="stackfood_user"
DB_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
WEB_DIR="/var/www/html/food-delivery"
LOG_FILE="/var/log/food-delivery-install.log"
PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
REPO_URL="https://github.com/sistemacodigolucrativo/Food-Delivery.git"

# Arquivo de log
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/food-delivery-install.log"

clear
echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════╗"
echo "  ║         PRÉ-INSTALADOR - FOOD DELIVERY (STACKFOOD)           ║"
echo "  ║                  Versão 3.0 | Completo                       ║"
echo "  ╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
log_info "Iniciando configuração completa do ambiente e aplicação..."
echo ""

# ==============================================================================
# ETAPAS DE INFRAESTRUTURA
# ==============================================================================

log_step "ETAPA 1/11 - Atualizando sistema e utilitários"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >> "$LOG_FILE" 2>&1
apt-get install -y curl wget git unzip zip software-properties-common ca-certificates lsb-release apt-transport-https gnupg2 openssl cron supervisor >> "$LOG_FILE" 2>&1
log_success "Infraestrutura básica pronta."

log_step "ETAPA 2/11 - Instalando PHP $PHP_VERSION e Extensões"
if ! grep -r "ondrej/php" /etc/apt/sources.list.d/ &>/dev/null; then
    add-apt-repository ppa:ondrej/php -y >> "$LOG_FILE" 2>&1
    apt-get update -y >> "$LOG_FILE" 2>&1
fi
apt-get install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-mysql php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-curl php${PHP_VERSION}-xml php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl php${PHP_VERSION}-readline php${PHP_VERSION}-opcache php${PHP_VERSION}-soap libapache2-mod-php${PHP_VERSION} >> "$LOG_FILE" 2>&1
apt-get install -y php${PHP_VERSION}-imagick >> "$LOG_FILE" 2>&1 || true
log_success "PHP configurado."

log_step "ETAPA 3/11 - Configurando Servidor Web Apache"
a2enmod rewrite headers ssl php${PHP_VERSION} >> "$LOG_FILE" 2>&1 || true
systemctl enable apache2 >> "$LOG_FILE" 2>&1
systemctl start apache2 >> "$LOG_FILE" 2>&1
log_success "Apache pronto."

log_step "ETAPA 4/11 - Instalando MariaDB e Criando Banco de Dados"
apt-get install -y mariadb-server mariadb-client >> "$LOG_FILE" 2>&1
systemctl enable mariadb >> "$LOG_FILE" 2>&1
systemctl start mariadb >> "$LOG_FILE" 2>&1
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> "$LOG_FILE" 2>&1
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" >> "$LOG_FILE" 2>&1
mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" >> "$LOG_FILE" 2>&1
mysql -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1
log_success "Banco de dados configurado."

log_step "ETAPA 5/11 - Instalando Composer e Node.js"
if ! command -v composer &>/dev/null; then
    curl -sS https://getcomposer.org/installer | php >> "$LOG_FILE" 2>&1
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y nodejs >> "$LOG_FILE" 2>&1
fi
log_success "Ferramentas de desenvolvimento instaladas."

# ==============================================================================
# ETAPAS DA APLICAÇÃO (O QUE FALTAVA)
# ==============================================================================

log_step "ETAPA 6/11 - Preparando diretório e baixando arquivos do projeto"
mkdir -p ${WEB_DIR}
cd /tmp
log_info "Clonando repositório para obter os arquivos de instalação..."
rm -rf food-delivery-temp
git clone ${REPO_URL} food-delivery-temp >> "$LOG_FILE" 2>&1

log_step "ETAPA 7/11 - Processando arquivos do Painel Administrativo"
# O repositório contém um zip multi-parte. Vamos extrair.
cd food-delivery-temp/"Admin panel new install V9.0"
log_info "Combinando e extraindo arquivos do painel admin..."
zip -FF "Admin panel new install V9.0.zip" --out combined.zip >> "$LOG_FILE" 2>&1
unzip -o combined.zip -d ${WEB_DIR} >> "$LOG_FILE" 2>&1
log_success "Arquivos extraídos para ${WEB_DIR}"

log_step "ETAPA 8/11 - Configurando permissões de arquivos"
chown -R www-data:www-data ${WEB_DIR}
find ${WEB_DIR} -type d -exec chmod 755 {} \;
find ${WEB_DIR} -type f -exec chmod 644 {} \;
chmod -R 775 ${WEB_DIR}/storage ${WEB_DIR}/bootstrap/cache
log_success "Permissões configuradas."

log_step "ETAPA 9/11 - Configurando VirtualHost do Apache"
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
a2dissite 000-default.conf >> "$LOG_FILE" 2>&1 || true
a2ensite food-delivery.conf >> "$LOG_FILE" 2>&1
systemctl restart apache2 >> "$LOG_FILE" 2>&1
log_success "Servidor web apontando para a aplicação."

log_step "ETAPA 10/11 - Ajustando limites do PHP"
for PHP_INI in "/etc/php/${PHP_VERSION}/apache2/php.ini" "/etc/php/${PHP_VERSION}/cli/php.ini"; do
    if [ -f "$PHP_INI" ]; then
        sed -i "s/^upload_max_filesize.*/upload_max_filesize = 128M/" $PHP_INI
        sed -i "s/^post_max_size.*/post_max_size = 128M/" $PHP_INI
        sed -i "s/^memory_limit.*/memory_limit = 512M/" $PHP_INI
        sed -i "s/^max_execution_time.*/max_execution_time = 600/" $PHP_INI
        sed -i "s/^max_input_vars.*/max_input_vars = 3000/" $PHP_INI
        sed -i "s/^allow_url_fopen.*/allow_url_fopen = On/" $PHP_INI
    fi
done
systemctl restart apache2 >> "$LOG_FILE" 2>&1
log_success "Limites de PHP otimizados."

log_step "ETAPA 11/11 - Finalizando"
# Salvar credenciais
CREDS_FILE="/root/.food-delivery-credentials"
cat > $CREDS_FILE <<CREDS
IP_SERVIDOR=$PUBLIC_IP
BANCO_DE_DADOS=$DB_NAME
USUARIO_DB=$DB_USER
SENHA_DB=$DB_PASS
URL_INSTALACAO=http://$PUBLIC_IP/install
CREDS
chmod 600 $CREDS_FILE

clear
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════════════╗"
echo "  ║           INSTALAÇÃO COMPLETA CONCLUÍDA!                         ║"
echo "  ╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  A VPS foi configurada e os arquivos do Food Delivery já foram"
echo -e "  extraídos e preparados. O ambiente está 100% pronto."
echo ""
echo -e "  ${YELLOW}${BOLD}DADOS PARA O INSTALADOR WEB:${NC}"
echo -e "  Host do Banco:   ${BLUE}127.0.0.1${NC}"
echo -e "  Nome do Banco:   ${BLUE}${DB_NAME}${NC}"
echo -e "  Usuário DB:      ${BLUE}${DB_USER}${NC}"
echo -e "  Senha DB:        ${BLUE}${DB_PASS}${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}LINK DE ACESSO IMEDIATO:${NC}"
echo -e "  ${GREEN}${BOLD}➜  http://${PUBLIC_IP}/install${NC}"
echo ""
echo -e "  ${CYAN}As credenciais acima foram salvas em: /root/.food-delivery-credentials${NC}"
echo ""

#!/bin/bash
# ==============================================================================
# Food Delivery (StackFood) - Pré-Instalador Automatizado Patched
# ==============================================================================
set -e
# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
LOG_FILE="/var/log/food_delivery_install.log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
# Configurações
PHP_VERSION="8.2"
DB_NAME="stackfood_db"
DB_USER="stackfood_user"
DB_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
WEB_DIR="/var/www/html/food-delivery"
REPO_URL="https://github.com/sistemacodigolucrativo/Food-Delivery.git"
PUBLIC_IP=$(curl -s https://ifconfig.me)
log_step() { echo -e "${BLUE}${BOLD}>>> $1${NC}"; }
log_success() { echo -e "${GREEN}✔ $1${NC}"; }
log_info() { echo -e "${CYAN}i $1${NC}"; }
if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root (sudo)."
    exit 1
fi
log_step "ETAPA 1/12 - Atualizando o sistema"
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get upgrade -y >> "$LOG_FILE" 2>&1
log_success "Sistema atualizado."
log_step "ETAPA 2/12 - Instalando dependências básicas"
apt-get install -y curl wget git unzip zip software-properties-common ca-certificates lsb-release apt-transport-https >> "$LOG_FILE" 2>&1
log_success "Dependências instaladas."
log_step "ETAPA 3/12 - Instalando Apache e PHP $PHP_VERSION"
add-apt-repository ppa:ondrej/php -y >> "$LOG_FILE" 2>&1
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get install -y apache2 libapache2-mod-php$PHP_VERSION >> "$LOG_FILE" 2>&1
apt-get install -y php$PHP_VERSION-{common,mysql,xml,xmlrpc,curl,gd,imagick,cli,dev,imap,mbstring,opcache,soap,zip,intl,bcmath} >> "$LOG_FILE" 2>&1
a2enmod rewrite >> "$LOG_FILE" 2>&1
systemctl restart apache2 >> "$LOG_FILE" 2>&1
log_success "Apache e PHP instalados."
log_step "ETAPA 4/12 - Instalando e configurando MariaDB"
apt-get install -y mariadb-server >> "$LOG_FILE" 2>&1
systemctl start mariadb >> "$LOG_FILE" 2>&1
systemctl enable mariadb >> "$LOG_FILE" 2>&1
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >> "$LOG_FILE" 2>&1
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" >> "$LOG_FILE" 2>&1
mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" >> "$LOG_FILE" 2>&1
mysql -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1
log_success "Banco de dados configurado."
log_step "ETAPA 5/12 - Instalando Composer e Node.js"
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
log_step "ETAPA 6/12 - Baixando arquivos do projeto"
mkdir -p ${WEB_DIR}
cd /tmp
rm -rf food-delivery-temp
git clone ${REPO_URL} food-delivery-temp >> "$LOG_FILE" 2>&1
log_step "ETAPA 7/12 - Extraindo arquivos do Painel Administrativo"
cd food-delivery-temp/"Admin panel new install V9.0"
zip -FF "Admin panel new install V9.0.zip" --out combined.zip >> "$LOG_FILE" 2>&1
unzip -o combined.zip -d ${WEB_DIR} >> "$LOG_FILE" 2>&1
log_success "Arquivos extraídos para ${WEB_DIR}"
log_step "ETAPA 8/12 - Aplicando Patches de Ativação e Melhorias"
cp /tmp/food-delivery-temp/Patched-Source/ActivationClass.php ${WEB_DIR}/app/Traits/ActivationClass.php
cp /tmp/food-delivery-temp/Patched-Source/HomeController.php ${WEB_DIR}/app/Http/Controllers/HomeController.php
log_success "Patches aplicados com sucesso."
log_step "ETAPA 9/12 - Configurando permissões"
chown -R www-data:www-data ${WEB_DIR}
find ${WEB_DIR} -type d -exec chmod 755 {} \;
find ${WEB_DIR} -type f -exec chmod 644 {} \;
chmod -R 775 ${WEB_DIR}/storage ${WEB_DIR}/bootstrap/cache
log_success "Permissões configuradas."
log_step "ETAPA 10/12 - Configurando Apache"
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
log_success "Servidor web configurado."
log_step "ETAPA 11/12 - Ajustando limites do PHP"
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
log_success "PHP otimizado."
log_step "ETAPA 12/12 - Finalizando"
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
echo -e "${GREEN}${BOLD}INSTALAÇÃO CONCLUÍDA!${NC}"
echo -e "DADOS PARA O INSTALADOR WEB:"
echo -e "Host do Banco: 127.0.0.1"
echo -e "Nome do Banco: ${DB_NAME}"
echo -e "Usuário DB:    ${DB_USER}"
echo -e "Senha DB:      ${DB_PASS}"
echo ""
echo -e "LINK DE ACESSO: http://${PUBLIC_IP}/install"

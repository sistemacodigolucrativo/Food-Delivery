#!/bin/bash
# ==============================================================================
# Food Delivery (StackFood) - Restaurador de Sistema (Fix Erro 500)
# ==============================================================================
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

WEB_DIR="/var/www/html/food-delivery"
REPO_URL="https://github.com/sistemacodigolucrativo/Food-Delivery.git"

log_step() { echo -e "${BLUE}${BOLD}>>> $1${NC}"; }
log_success() { echo -e "${GREEN}✔ $1${NC}"; }
log_info() { echo -e "${YELLOW}i $1${NC}"; }

if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root (sudo)."
    exit 1
fi

log_step "Iniciando restauração do sistema para corrigir Erro 500"

# 1. Corrigir permissões críticas (Causa comum de erro 500 no Laravel)
log_step "Restaurando permissões das pastas storage e cache..."
chown -R www-data:www-data "$WEB_DIR/storage" "$WEB_DIR/bootstrap/cache"
chmod -R 775 "$WEB_DIR/storage" "$WEB_DIR/bootstrap/cache"

# 2. Re-aplicar os Patches de Ativação (Garantir que não foram sobrescritos)
log_step "Re-aplicando patches de ativação..."
TEMP_REPO="/tmp/food-delivery-restore"
rm -rf "$TEMP_REPO"
git clone --depth 1 "$REPO_URL" "$TEMP_REPO" -q

cp "$TEMP_REPO/Patched-Source/ActivationClass.php" "$WEB_DIR/app/Traits/ActivationClass.php"
cp "$TEMP_REPO/Patched-Source/HomeController.php" "$WEB_DIR/app/Http/Controllers/HomeController.php"

# 3. Limpar arquivos desnecessários que podem ter sido copiados
log_step "Limpando arquivos temporários..."
rm -rf "$TEMP_REPO"

# 4. Reiniciar Apache para garantir que tudo seja recarregado
log_step "Reiniciando servidor web..."
systemctl restart apache2

log_success "RESTAURAÇÃO CONCLUÍDA!"
log_info "Por favor, verifique se o acesso ao site foi restabelecido."
log_info "Se o erro persistir, limpe o cache do navegador."

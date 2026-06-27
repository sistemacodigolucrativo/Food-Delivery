#!/bin/bash
# ==============================================================================
# Food Delivery (StackFood) - Corretor de Imagens e Assets Oficiais
# ==============================================================================
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ASSETS_URL="https://files.manuscdn.com/user_upload_by_module/session_file/310519663797544015/GjRYpSjoDPEXgkbm.zip"
WEB_DIR="/var/www/html/food-delivery"
TEMP_DIR="/tmp/stackfood_assets_fix"

log_step() { echo -e "${BLUE}${BOLD}>>> $1${NC}"; }
log_success() { echo -e "${GREEN}✔ $1${NC}"; }
log_info() { echo -e "${YELLOW}i $1${NC}"; }

if [ "$EUID" -ne 0 ]; then 
    echo "Por favor, execute como root (sudo)."
    exit 1
fi

if [ ! -d "$WEB_DIR" ]; then
    echo "Erro: Diretório do projeto não encontrado em $WEB_DIR"
    exit 1
fi

log_step "Iniciando correção de imagens oficiais do StackFood"

# 1. Preparar diretório temporário
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# 2. Baixar pacote de assets oficiais (extraídos do demo oficial)
log_step "Baixando pacote de assets oficiais (57MB)..."
curl -L "$ASSETS_URL" -o assets.zip

# 3. Extrair assets
log_step "Extraindo arquivos..."
unzip -q assets.zip -d extracted

# 4. Sincronizar com o diretório do projeto
log_step "Sincronizando imagens com o projeto em $WEB_DIR..."
# Usar rsync para copiar apenas os arquivos mantendo a estrutura
# Se rsync não estiver instalado, usa cp
if command -v rsync &>/dev/null; then
    rsync -av extracted/ "$WEB_DIR/" >> /var/log/food_delivery_assets.log 2>&1
else
    cp -rv extracted/* "$WEB_DIR/" >> /var/log/food_delivery_assets.log 2>&1
fi

# 5. Corrigir permissões
log_step "Ajustando permissões..."
chown -R www-data:www-data "$WEB_DIR/public/assets"
find "$WEB_DIR/public/assets" -type d -exec chmod 755 {} \;
find "$WEB_DIR/public/assets" -type f -exec chmod 644 {} \;

# 6. Limpeza
rm -rf "$TEMP_DIR"

log_success "IMAGENS CORRIGIDAS COM SUCESSO!"
log_info "Agora o seu sistema deve exibir todos os logos, ícones e banners oficiais."
log_info "Dica: Limpe o cache do seu navegador para ver as mudanças imediatamente."

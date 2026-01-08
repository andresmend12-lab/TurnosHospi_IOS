#!/bin/bash
# ===========================================
# Script de Deploy para Firebase
# TurnosHospi - Shift Manager
# ===========================================

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorio del proyecto
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Shift Manager - Firebase Deploy${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Verificar que Firebase CLI está instalado
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Error: Firebase CLI no está instalado${NC}"
    echo "Instálalo con: npm install -g firebase-tools"
    exit 1
fi

# Verificar login de Firebase
echo -e "${YELLOW}Verificando autenticación de Firebase...${NC}"
if ! firebase projects:list &> /dev/null; then
    echo -e "${RED}No has iniciado sesión en Firebase${NC}"
    echo "Ejecuta: firebase login"
    exit 1
fi
echo -e "${GREEN}✓ Autenticado en Firebase${NC}"

# Cambiar al directorio del proyecto
cd "$PROJECT_DIR"

# Menú de opciones
echo ""
echo -e "${YELLOW}¿Qué deseas desplegar?${NC}"
echo "1) Solo reglas de Database"
echo "2) Solo Cloud Functions"
echo "3) Todo (Database + Functions)"
echo "4) Cancelar"
echo ""
read -p "Selecciona una opción (1-4): " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}Desplegando reglas de Database...${NC}"
        firebase deploy --only database
        echo -e "${GREEN}✓ Reglas de Database desplegadas${NC}"
        ;;
    2)
        echo ""
        echo -e "${BLUE}Instalando dependencias de Functions...${NC}"
        cd functions && npm install && cd ..

        echo -e "${BLUE}Desplegando Cloud Functions...${NC}"
        firebase deploy --only functions
        echo -e "${GREEN}✓ Cloud Functions desplegadas${NC}"
        ;;
    3)
        echo ""
        echo -e "${BLUE}Instalando dependencias de Functions...${NC}"
        cd functions && npm install && cd ..

        echo -e "${BLUE}Desplegando todo...${NC}"
        firebase deploy
        echo -e "${GREEN}✓ Deploy completo${NC}"
        ;;
    4)
        echo -e "${YELLOW}Operación cancelada${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Opción no válida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   Deploy completado exitosamente${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Panel de Firebase: ${BLUE}https://console.firebase.google.com/project/turnoshospi-f4870${NC}"
echo ""

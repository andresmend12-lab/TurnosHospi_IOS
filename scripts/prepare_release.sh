#!/bin/bash
# ===========================================
# Script de Preparación para Release
# TurnosHospi - Shift Manager
# ===========================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Shift Manager - Release Checklist${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Función para verificar
check() {
    if [ "$1" = "ok" ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ERRORS=$((ERRORS + 1))
    fi
}

ERRORS=0

# 1. Verificar archivos críticos
echo -e "${YELLOW}Verificando archivos críticos...${NC}"

if [ -f "$PROJECT_DIR/TurnosHospi_IOS/Info.plist" ]; then
    check "ok" "Info.plist existe"
else
    check "fail" "Info.plist NO existe"
fi

if [ -f "$PROJECT_DIR/TurnosHospi_IOS/TurnosHospi_IOS.entitlements" ]; then
    check "ok" "Entitlements existe"
else
    check "fail" "Entitlements NO existe"
fi

if [ -f "$PROJECT_DIR/database.rules.json" ]; then
    check "ok" "Firebase rules existe"
else
    check "fail" "Firebase rules NO existe"
fi

# 2. Verificar configuración de entitlements para producción
echo ""
echo -e "${YELLOW}Verificando configuración de producción...${NC}"

if grep -q "development" "$PROJECT_DIR/TurnosHospi_IOS/TurnosHospi_IOS.entitlements"; then
    echo -e "${YELLOW}⚠${NC}  aps-environment está en 'development'"
    echo -e "    ${YELLOW}Cambiar a 'production' antes de subir a App Store${NC}"
else
    check "ok" "aps-environment configurado para producción"
fi

# 3. Verificar versión
echo ""
echo -e "${YELLOW}Verificando versión...${NC}"
VERSION=$(grep "MARKETING_VERSION" "$PROJECT_DIR/TurnosHospi_IOS.xcodeproj/project.pbxproj" | head -1 | grep -o '[0-9.]*')
BUILD=$(grep "CURRENT_PROJECT_VERSION" "$PROJECT_DIR/TurnosHospi_IOS.xcodeproj/project.pbxproj" | head -1 | grep -o '[0-9]*')
echo -e "${BLUE}Versión actual: ${VERSION} (Build ${BUILD})${NC}"

# 4. Verificar deployment target
echo ""
echo -e "${YELLOW}Verificando deployment target...${NC}"
TARGET=$(grep "IPHONEOS_DEPLOYMENT_TARGET = " "$PROJECT_DIR/TurnosHospi_IOS.xcodeproj/project.pbxproj" | head -1 | grep -o '[0-9.]*')
if [ "$TARGET" = "16.0" ]; then
    check "ok" "Deployment target: iOS ${TARGET}"
else
    echo -e "${YELLOW}⚠${NC}  Deployment target: iOS ${TARGET} (recomendado: 16.0)"
fi

# 5. Verificar que no hay secretos expuestos
echo ""
echo -e "${YELLOW}Verificando secretos...${NC}"
if git ls-files | xargs grep -l "AIzaSy" 2>/dev/null | grep -v ".gitignore" > /dev/null; then
    echo -e "${YELLOW}⚠${NC}  Posible API key expuesta en archivos tracked"
else
    check "ok" "No se encontraron API keys expuestas"
fi

# Resumen
echo ""
echo -e "${BLUE}=========================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}   Verificación completada sin errores${NC}"
else
    echo -e "${RED}   Se encontraron ${ERRORS} error(es)${NC}"
fi
echo -e "${BLUE}=========================================${NC}"

# Recordatorios
echo ""
echo -e "${YELLOW}Recordatorios antes de subir a App Store:${NC}"
echo "1. Cambiar aps-environment a 'production'"
echo "2. Generar screenshots para App Store"
echo "3. Desplegar reglas de Firebase: ./scripts/deploy_firebase.sh"
echo "4. Probar en dispositivo físico"
echo "5. Verificar política de privacidad en URL pública"
echo ""

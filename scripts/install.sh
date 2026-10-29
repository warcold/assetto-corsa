#!/bin/bash
# install.sh — Instalación completa de Assetto Corsa Server en vps-preprod
# Uso: bash install.sh [steam_user] [steam_pass]
# NOTA: Requiere Steam license (app 244210)

set -e

HOST="root@154.53.35.102"
SSH="ssh -p 1333 -i ~/.ssh/id_ed25519_kalimete"
SCP="scp -P 1333 -i ~/.ssh/id_ed25519_kalimete"

STEAM_USER="${1:-}"
STEAM_PASS="${2:-}"

REMOTE_DIR="/srv/assetto-corsa"
DOCKER_COMPOSE="$REMOTE_DIR/docker-compose.yml"
CONFIG_YML="$REMOTE_DIR/config.yml"

echo "=== Assetto Corsa Server Installation ==="
echo "Target: vps-preprod (154.53.35.102)"
echo ""

# Verificar que Steam credentials fueron proporcionadas
if [ -z "$STEAM_USER" ] || [ -z "$STEAM_PASS" ]; then
    echo "⚠️  WARNING: No se proporcionaron credenciales de Steam."
    echo "   Assetto Corsa (app 244210) REQUIERE una cuenta con el juego comprado."
    echo ""
    echo "   Uso: bash install.sh [steam_user] [steam_pass]"
    echo ""
    echo "   Opciones alternativas:"
    echo "   1. Comprar AC en Steam (~$15 USD) y usar esas credenciales"
    echo "   2. Copiar manualmente la carpeta de Steam desde PC local:"
    echo "      scp -P 1333 -r ~/steamapps/* $HOST:$REMOTE_DIR/"
    echo ""
    read -p "¿Continuar sin Steam (solo Server Manager)? [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Abortado. Se requiere Steam license para el juego."
        exit 1
    fi
    USE_STEAM="false"
else
    USE_STEAM="true"
    echo "Steam: $STEAM_USER (license required for app 244210)"
fi

echo ""
echo "=== Step 1: Crear directorio remoto ==="
$SSH $HOST "mkdir -p $REMOTE_DIR"

echo ""
echo "=== Step 2: Instalar Docker si no existe ==="
$SSH $HOST "
    if ! command -v docker &> /dev/null; then
        echo 'Installing Docker...'
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker root
    else
        echo 'Docker already installed: '$($SSH $HOST 'docker --version')
    fi
"

echo ""
echo "=== Step 3: Crear docker-compose.yml ==="
$SCP docker-compose.yml $HOST:$DOCKER_COMPOSE

echo ""
echo "=== Step 4: Crear config.yml ==="
$SCP config.yml $HOST:$CONFIG_YML

echo ""
echo "=== Step 5: Pull Docker image ==="
$SSH $HOST "cd $REMOTE_DIR && docker-compose pull"

if [ "$USE_STEAM" = "true" ]; then
    echo ""
    echo "=== Step 6: Descargar Assetto Corsa vía SteamCMD ==="
    $SSH $HOST "
        cd $REMOTE_DIR
        if [ -f steamcmd.sh ]; then
            echo 'SteamCMD already exists'
        else
            wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
            tar -xvzf steamcmd_linux.tar.gz
        fi
        ./steamcmd.sh +login $STEAM_USER $STEAM_PASS +app_update 244210 validate +quit
    "
fi

echo ""
echo "=== Step 7: Iniciar servidor ==="
$SSH $HOST "cd $REMOTE_DIR && docker-compose up -d"

echo ""
echo "=== Verificación ==="
$SSH $HOST "
    echo '--- Docker containers ---'
    docker ps | grep assetto || echo 'No container running yet'
    echo ''
    echo '--- Server Manager status ---'
    curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:8772 || echo 'Not accessible'
    echo ''
    echo '--- Ports ---'
    ss -tln | grep -E '8772|9600' || echo 'Ports not open yet'
"

echo ""
echo "=== DONE ==="
echo "Server Manager UI: http://154.53.35.102:8772"
echo "Game ports: 9600-9601 (UDP) — still need Cloudflare tunnel"
echo ""
echo "Next steps:"
echo "  1. Configurar Cloudflare tunnel (assetto.armada.do)"
echo "  2. Acceder a http://154.53.35.102:8772 para configurar el server"
echo "  3. Añadir tracks y cars en el panel"

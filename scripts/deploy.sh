#!/bin/bash
# deploy.sh — Deploy del proyecto Assetto Corsa a la VPS
# Uso: bash deploy.sh

set -e

REMOTE_DIR="/srv/assetto-corsa"
SSH="ssh -p 1333 -i ~/.ssh/id_ed25519_kalimete"
SCP="scp -P 1333 -i ~/.ssh/id_ed25519_kalimete"

echo "=== Deploy Assetto Corsa Server ==="
echo "Target: vps-preprod (154.53.35.102)"
echo ""

# Crear directorio remoto
echo "=== Step 1: Crear directorio remoto ==="
$SSH root@154.53.35.102 "mkdir -p $REMOTE_DIR"

# Subir docker-compose.yml
echo "=== Step 2: Subir docker-compose.yml ==="
$SCP scripts/docker-compose.yml root@154.53.35.102:$REMOTE_DIR/docker-compose.yml

# Subir config.yml si existe
if [ -f "scripts/config.yml" ]; then
    echo "=== Step 3: Subir config.yml ==="
    $SCP scripts/config.yml root@154.35.102:$REMOTE_DIR/config.yml
else
    echo "=== Step 3: Crear config.yml (usar ejemplo) ==="
    $SCP scripts/config.example.yml root@154.53.35.102:$REMOTE_DIR/config.yml
fi

# Subir datos de AC (si existen)
if [ -d "scripts/assetto" ]; then
    echo "=== Step 4: Subir contenido de AC ==="
    $SCP -r scripts/assetto/* root@154.53.35.102:$REMOTE_DIR/assetto/
fi

# Hacer deploy con Docker
echo ""
echo "=== Step 5: Deploy con Docker ==="
$SSH root@154.53.35.102 "
    cd $REMOTE_DIR
    docker-compose up -d
    echo '--- Container status ---'
    docker ps | grep assetto || echo 'No container running'
    echo ''
    echo '--- Server Manager status ---'
    curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:8772 || echo 'Not accessible'
"

echo ""
echo "=== Deploy completado ==="
echo "Panel web: http://154.53.35.102:8772"
echo "Game ports: 9600-9601 (UDP)"
echo ""
echo "NOTA: El dominio assetto.armada.do requiere configurar Cloudflare tunnel"

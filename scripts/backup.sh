#!/bin/bash
# backup.sh — Backup completo del servidor Assetto Corsa
# Uso: bash backup.sh [destino]

set -e

BACKUP_DIR="${1:-/tmp/assetto-backup-$(date +%Y%m%d-%H%M%S)}"
REMOTE_DIR="/srv/assetto-corsa"
SSH="ssh -p 1333 -i ~/.ssh/id_ed25519_kalimete"
SCP="scp -P 1333 -i ~/.ssh/id_ed25519_kalimete"

echo "=== Assetto Corsa Backup ==="
echo "Fecha: $(date)"
echo "Destino: $BACKUP_DIR"
echo ""

# Crear directorio local
mkdir -p "$BACKUP_DIR"

# Backup del contenido remoto
echo "=== Backup del servidor remoto ==="
$SSH $HOST "
    tar -czf /tmp/ac-backup-$(date +%Y%m%d).tar.gz \
        --exclude='*.log' \
        -C $REMOTE_DIR .
    ls -lh /tmp/ac-backup-*.tar.gz
"

# Descargar el backup
$SCP root@154.53.35.102:/tmp/ac-backup-*.tar.gz "$BACKUP_DIR/"

# Backup de la DB de Server Manager
echo ""
echo "=== Backup de DB de Server Manager ==="
$SSH root@154.53.35.102 "
    if [ -f /srv/assetto-corsa/data/ac-server-manager.db ]; then
        cp /srv/assetto-corsa/data/ac-server-manager.db /tmp/ac-db-$(date +%Y%m%d).db
        ls -lh /tmp/ac-db-*.db
    else
        echo 'No se encontro DB de Server Manager'
    fi
"
$SCP root@154.53.35.102:/tmp/ac-db-*.db "$BACKUP_DIR/" 2>/dev/null || true

# Backup del config.yml
echo ""
echo "=== Backup de config.yml ==="
$SCP root@154.53.35.102:/srv/assetto-corsa/config.yml "$BACKUP_DIR/" 2>/dev/null || true

echo ""
echo "=== Backup completado ==="
echo "Archivos de backup:"
ls -lh "$BACKUP_DIR/"
echo ""
echo "Tamaño total: $(du -sh $BACKUP_DIR | cut -f1)"

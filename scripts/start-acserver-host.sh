#!/bin/bash
# [OBSOLETO 2026-10-30] El servicio systemd fue retirado y el Server Manager es el
# único dueño del proceso. Arrancar esto a mano provoca choque de puertos/doble server.
# Usar el botón Start del panel (o `bash start-race.sh`). Se conserva solo como referencia.
#
# start-acserver.sh — Arranque limpio del servidor AC en el host (fuera de Docker)
# Usa el binario acServer del host con los configs generados por Server Manager
# Uso: bash start-acserver.sh

set -e

CFG_DIR="/srv/assetto-corsa/assetto/cfg"
SERVER_CFG="$CFG_DIR/server_cfg.ini"
ENTRY_LIST="$CFG_DIR/entry_list.ini"
ACSERVER_BIN="/srv/assetto-corsa/assetto/acServer"
LOG_FILE="/var/log/acserver-host.log"

echo "=== Assetto Corsa RD - Start AC Server (Host) ==="

# 1. Verificar binario
if [ ! -x "$ACSERVER_BIN" ]; then
    echo "ERROR: Binario acServer no encontrado en $ACSERVER_BIN"
    exit 1
fi

# 2. Verificar configs
if [ ! -f "$SERVER_CFG" ]; then
    echo "ERROR: server_cfg.ini no encontrado en $SERVER_CFG"
    exit 1
fi

if [ ! -f "$ENTRY_LIST" ]; then
    echo "ERROR: entry_list.ini no encontrado en $ENTRY_LIST"
    exit 1
fi

# 3. Inyectar [LAUNCHER] si falta (fix para bug del Server Manager)
if ! grep -q '^\[LAUNCHER\]' "$SERVER_CFG"; then
    echo "Inyectando [LAUNCHER] en $SERVER_CFG"
    cat >> "$SERVER_CFG" <<'LAUNCHER_EOF'

[LAUNCHER]
; Required by acServer to avoid "section 'LAUNCHER' does not exist" panic
; Empty section is sufficient - just needs to exist
LAUNCHER_EOF
fi

# 4. Verificar steam_appid.txt
if [ ! -f "/srv/assetto-corsa/assetto/steam_appid.txt" ]; then
    echo 302550 > /srv/assetto-corsa/assetto/steam_appid.txt
fi

# 5. Matar procesos previos
pkill -9 -f "acServer" 2>/dev/null || true
sleep 1

# 6. Arrancar acServer en background con logging
echo "Arrancando acServer en host..."
cd /srv/assetto-corsa/assetto
nohup ./acServer >> "$LOG_FILE" 2>&1 &
AC_PID=$!

# 7. Esperar y verificar puertos
echo "Esperando a que bindee puertos..."
for i in {1..15}; do
    sleep 1
    if ss -uln | grep -q ':9600'; then
        echo "✅ UDP 9600 escuchando"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ Timeout: UDP 9600 no bindeó"
        tail -20 "$LOG_FILE"
        exit 1
    fi
done

# 7. Verificar estado final
echo "=== Estado Final ==="
ss -ulnp | grep 9600
ss -tlpn | grep -E '8081|8082|9600'
echo "PID: $AC_PID"
echo "Log: $LOG_FILE"
echo ""
echo "✅ Servidor AC ONLINE en host"
echo "Conectar: srv00.assetto.armada.do:9600"
echo "Panel SM: https://assetto.armada.do (admin/colador)"
#!/bin/bash
# start-race.sh — Inicia una carrera guardada en el Server Manager y verifica el arranque
# Flujo verificado 2026-10-30 (SM v1.7.9). Uso: bash start-race.sh [race_id]
#
# El SM no tiene API de start: el botón Start es GET /custom/load/{uuid} (302 -> /live-timing).
# Race por defecto: fd8236dc… = "🇩🇴 | Another day of practice at Nürburgring GP" (12 coches, 30 min).

set -euo pipefail

RACE_ID="${1:-fd8236dc-1871-41e7-90f4-c35b5b686308}"
VPS="root@154.53.35.102"
SSH=(ssh -p 1333 -i ~/.ssh/id_ed25519_kalimete "$VPS")

echo "=== Assetto Corsa RD — Start race ==="
echo "Race ID: $RACE_ID"

# 1. Contenedor arriba (tras un docker restart la UI tarda ~35-45 s)
echo "--- 1. Contenedor"
"${SSH[@]}" "docker ps --format '{{.Names}}' | grep -qx assetto-corsa-server" \
  || { echo "ERROR: contenedor assetto-corsa-server no está corriendo"; exit 1; }

# 2. Login al panel (password leída en el VPS; no se imprime)
echo "--- 2. Login"
"${SSH[@]}" 'PW=$(awk -F": " "/^Password:/{print \$2}" /srv/assetto-corsa/.sm-admin-credentials)
curl -s -c /tmp/smcj -o /dev/null --data-urlencode "Username=admin" --data-urlencode "Password=$PW" http://127.0.0.1:8772/login'

# 3. Start de la carrera guardada
echo "--- 3. Start"
"${SSH[@]}" "curl -s -b /tmp/smcj -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://127.0.0.1:8772/custom/load/$RACE_ID"

# 4. Esperar arranque y verificar proceso, puertos y /INFO
echo "--- 4. Verificación (12 s)"
sleep 12
"${SSH[@]}" "docker exec assetto-corsa-server ps -ef | grep [a]cServer"
"${SSH[@]}" "ss -lunp | grep 9600; ss -ltnp | grep 9600"
"${SSH[@]}" "curl -s http://127.0.0.1:8081/INFO | head -c 240; echo"

echo "=== OK (si /INFO devuelve el evento y 9600 está bindeado) ==="

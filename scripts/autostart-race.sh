#!/bin/bash
# autostart-race.sh - Watchdog: levanta la carrera default si el acServer esta caido
# SOLO carga la carrera via SM y aplica fixes de estabilidad. NUNCA mata el acServer.

RACE_UUID="fd8236dc-1871-41e7-90f4-c35b5b686308"
CRED="/srv/assetto-corsa/.sm-admin-credentials"
SM="http://127.0.0.1:8772"

if [ -f /srv/assetto-corsa/.autostart-paused ]; then
    echo "[autostart] pausado, skip"
    exit 0
fi

# Fix de estabilidad en el config del container (si existen las claves)
docker exec assetto-corsa-server sh -c \
    "sed -i -e 's/^REGISTER_TO_LOBBY=.*/REGISTER_TO_LOBBY=0/' -e 's/^SLEEP_TIME=.*/SLEEP_TIME=1/' /home/assetto/server-manager/assetto/content/config/server_cfg.ini" 2>/dev/null

AC_PID=$(docker exec assetto-corsa-server sh -c "pidof acServer.real" 2>/dev/null || true)

if [ -n "$AC_PID" ]; then
    echo "[autostart] acServer activo (PID $AC_PID), ok"
    exit 0
fi

echo "[autostart] acServer inactivo -> cargando carrera $RACE_UUID..."

for i in $(seq 1 40); do
    curl -sf -o /dev/null --max-time 3 "$SM/" && break
    sleep 3
done

if ! curl -sf -o /dev/null --max-time 3 "$SM/"; then
    echo "[autostart] ERROR: SM no respondio" >&2
    exit 1
fi

PW=$(sed -n "s/^Password: //p" "$CRED")
CJ=$(mktemp)
curl -s -c "$CJ" -o /dev/null --data-urlencode "Username=admin" --data-urlencode "Password=$PW" "$SM/login"
curl -s -b "$CJ" -o /dev/null -w "[autostart] carrera %{http_code}\n" "$SM/custom/load/$RACE_UUID"
rm -f "$CJ"

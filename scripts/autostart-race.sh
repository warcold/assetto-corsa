#!/bin/bash
# autostart-race.sh — espera al Server Manager y lanza la carrera guardada por defecto.
# Lo invoca assetto-sm-autostart.service (oneshot) al boot del VPS.
set -u

RACE_UUID="9205601d-413c-400a-a477-52bf42c75469"   # 🇩🇴 | Another day of practice at Highlands
CRED="/srv/assetto-corsa/.sm-admin-credentials"
SM="http://127.0.0.1:8772"

# Flag de pausa: si existe, el watchdog no relanza (control manual del owner)
if [ -f /srv/assetto-corsa/.autostart-paused ]; then
    echo "[autostart] pausado (.autostart-paused presente), skip"
    exit 0
fi

# Si el acServer ya esta corriendo (contenedor reiniciado con carrera viva), no tocar
if ss -lun 2>/dev/null | grep -q ':9600'; then
    echo "[autostart] acServer ya activo (UDP 9600), no se relanza"
    exit 0
fi

# Esperar a que el SM responda (hasta ~120 s: la UI tarda 35-45 s en calentar)
for i in $(seq 1 40); do
    curl -sf -o /dev/null --max-time 3 "$SM/" && break
    sleep 3
done

if ! curl -sf -o /dev/null --max-time 3 "$SM/"; then
    echo "[autostart] ERROR: Server Manager no respondio en :8772" >&2
    exit 1
fi

PW=$(awk -F': ' '/^Password:/{print $2}' "$CRED")
CJ=$(mktemp)
curl -s -c "$CJ" -o /dev/null --data-urlencode "Username=admin" --data-urlencode "Password=$PW" "$SM/login"
curl -s -b "$CJ" -o /dev/null -w "[autostart] carrera %{http_code}\n" "$SM/custom/load/$RACE_UUID"

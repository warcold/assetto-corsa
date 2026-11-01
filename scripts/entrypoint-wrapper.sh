#!/bin/bash
# entrypoint-wrapper.sh - Server Manager (seejy/assetto-server-manager)
# Prepara la config que el binario v1.15 exige ANTES de que SM arranque.
# SOLO estabilidad: NO pisa el diseño de la carrera (eso lo decide la UI del SM).

CFG_FILE="/home/assetto/server-manager/assetto/content/config/server_cfg.ini"
CFG_LINK="/home/assetto/server-manager/assetto/cfg/server_cfg.ini"

# 0) Patcher de estabilidad en background (REGISTER_TO_LOBBY=0, SLEEP_TIME=1)
if [ -f /tmp/config-patcher.sh ]; then
    nohup bash /tmp/config-patcher.sh >/dev/null 2>&1 &
    echo "[entrypoint] config patcher started in background (PID $!)"
fi

# 1) [LAUNCHER] obligatorio: el binario v1.15 hace panic si la seccion no existe
if [ -f "$CFG_FILE" ] && ! grep -q '^\[LAUNCHER\]' "$CFG_FILE"; then
    printf '\n[LAUNCHER]\n' >> "$CFG_FILE"
    echo "[entrypoint] [LAUNCHER] inyectado"
fi

# 2) [WEATHER_0] obligatorio: sin ella panic "invalid argument to Intn" en UpdateWeather
if [ -f "$CFG_FILE" ] && ! grep -q '^\[WEATHER_0\]' "$CFG_FILE"; then
    printf '\n[WEATHER_0]\nGRAPHICS=3_clear\nBASE_TEMPERATURE_AMBIENT=22\nBASE_TEMPERATURE_ROAD=8\n' >> "$CFG_FILE"
    echo "[entrypoint] [WEATHER_0] inyectado"
fi

# 3) Symlink cfg/server_cfg.ini -> content/config/server_cfg.ini (lo que lee el binario)
mkdir -p "$(dirname "$CFG_LINK")"
ln -sfn "$CFG_FILE" "$CFG_LINK"

# 4) Estabilidad: lobby Kunos muerto (404) apaga el server tras 5 intentos;
#    SLEEP_TIME=0 causa CPU overload. Forzado en cada arranque del contenedor.
if [ -f "$CFG_FILE" ]; then
    sed -i -e 's/^REGISTER_TO_LOBBY=.*/REGISTER_TO_LOBBY=0/' \
           -e 's/^SLEEP_TIME=.*/SLEEP_TIME=1/' "$CFG_FILE" || true
fi

echo "[entrypoint] config preparada, lanzando Server Manager en :8772..."
exec /usr/bin/server-manager "$@"

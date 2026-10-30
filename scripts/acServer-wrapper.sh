#!/bin/bash
# acServer wrapper — Assetto Corsa Server Manager (assetto.armada.do)
# 1) Normaliza content/config/server_cfg.ini: deja UNA sola seccion [LAUNCHER]
#    (el binario v1.15 hace panic si la seccion no existe) y garantiza [WEATHER_0].
# 2) Estabilidad: REGISTER_TO_LOBBY=0 (el lobby de Kunos 93.57.10.21 da 404 y
#    v1.15 se apaga solo tras 5 intentos: "LOBBY COULD NOT BE RACHED") y SLEEP_TIME>=1.
# 3) Mantiene los symlinks cfg/ -> content/config/ que espera el binario.
# 4) Ejecuta el binario real: acServer.real
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1

CFG="content/config/server_cfg.ini"
ENTRY="content/config/entry_list.ini"
mkdir -p cfg

if [ -f "$CFG" ]; then
    if grep -q '^\[LAUNCHER\]' "$CFG"; then
        tmp="$(mktemp)"
        awk '
            /^\[/ {
                if ($0 ~ /^\[LAUNCHER\]/) { skip = 1; next }
                skip = 0
            }
            !skip { print }
        ' "$CFG" > "$tmp" && cat "$tmp" > "$CFG" && rm -f "$tmp"
    fi
    printf '\n[LAUNCHER]\n' >> "$CFG"

    if ! grep -q '^\[WEATHER_0\]' "$CFG"; then
        printf '\n[WEATHER_0]\nGRAPHICS=3_clear\nBASE_TEMPERATURE_AMBIENT=22\nBASE_TEMPERATURE_ROAD=8\n' >> "$CFG"
    fi

    # Estabilidad: lobby muerto (404) apaga el server; SLEEP_TIME=0 causa CPU overload
    sed -i -e 's/^REGISTER_TO_LOBBY=.*/REGISTER_TO_LOBBY=0/' \
           -e 's/^SLEEP_TIME=.*/SLEEP_TIME=1/' "$CFG"

    # Nürburgring sin layout explicito: el paquete dedicado no tiene data/ en la raiz
    # de la pista; forzar el GP (carpeta layout_gp_a) si SM lo deja vacio.
    if grep -q '^TRACK=ks_nurburgring$' "$CFG" && grep -q '^CONFIG_TRACK=$' "$CFG"; then
        sed -i 's/^CONFIG_TRACK=$/CONFIG_TRACK=layout_gp_a/' "$CFG"
    fi

    ln -sfn ../content/config/server_cfg.ini cfg/server_cfg.ini
fi

[ -f "$ENTRY" ] && ln -sfn ../content/config/entry_list.ini cfg/entry_list.ini

exec ./acServer.real "$@"

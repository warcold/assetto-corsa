#!/bin/bash
# Patcher loop - SOLO fixes de estabilidad. NO toca el diseño de la carrera
# (pickup/loop/sesiones los decide el Server Manager UI = fuente de verdad)

CFG_FILE="/home/assetto/server-manager/assetto/content/config/server_cfg.ini"

while true; do
    if [ -f "$CFG_FILE" ]; then
        sed -i \
            -e "s/^REGISTER_TO_LOBBY=.*/REGISTER_TO_LOBBY=0/" \
            -e "s/^SLEEP_TIME=.*/SLEEP_TIME=1/" \
            "$CFG_FILE"
    fi
    sleep 0.1
done

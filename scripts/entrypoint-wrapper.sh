#!/bin/bash
# entrypoint-wrapper.sh — Inyecta [LAUNCHER] y [WEATHER_0] en server_cfg.ini ANTES de que Server Manager lance acServer
# Fix para bugs del Server Manager:
# 1. Omite [LAUNCHER] al generar server_cfg.ini → acServer crashea
# 2. Omite [WEATHER_0] al generar server_cfg.ini → acServer crashea (panic: invalid argument to Intn)

set -e

CFG_FILE="/home/assetto/server-manager/assetto/content/config/server_cfg.ini"
CFG_LINK="/home/assetto/server-manager/assetto/cfg/server_cfg.ini"

# Función para inyectar [LAUNCHER] si no existe
inject_launcher() {
    if [ -f "$CFG_FILE" ] && ! grep -q '^\[LAUNCHER\]' "$CFG_FILE"; then
        echo "Inyectando [LAUNCHER] en $CFG_FILE"
        cat >> "$CFG_FILE" <<'LAUNCHER_EOF'

[LAUNCHER]
; Required by acServer to avoid "section 'LAUNCHER' does not exist" panic
; Empty section is sufficient - just needs to exist
LAUNCHER_EOF
    fi
}

# Función para inyectar [WEATHER_0] si no existe
inject_weather() {
    if [ -f "$CFG_FILE" ] && ! grep -q '^\[WEATHER_0\]' "$CFG_FILE"; then
        echo "Inyectando [WEATHER_0] en $CFG_FILE"
        cat >> "$CFG_FILE" <<'WEATHER_EOF'

[WEATHER_0]
GRAPHICS=3_clear
BASE_TEMPERATURE_AMBIENT=27
BASE_TEMPERATURE_ROAD=39
VARIATION_AMBIENT=0.68
VARIATION_ROAD=1.1
WEATHER_EOF
    fi
}

# Asegurar que el symlink existe
ensure_symlink() {
    if [ ! -L "$CFG_LINK" ] || [ "$(readlink "$CFG_LINK")" != "$CFG_FILE" ]; then
        echo "Creando symlink $CFG_LINK -> $CFG_FILE"
        ln -sf "$CFG_FILE" "$CFG_LINK"
    fi
}

# Inyectar [LAUNCHER] ANTES de que Server Manager haga cualquier cosa
inject_launcher

# Inyectar [WEATHER_0] ANTES de que Server Manager haga cualquier cosa
inject_weather

# Asegurar symlink
ensure_symlink

# Ejecutar el Server Manager original
exec /usr/bin/server-manager "$@"
#!/bin/bash
# [OBSOLETO 2026-10-30] Escrito para la era standalone (systemd + cfg/server_cfg.ini).
# Hoy el SM genera content/config/*.ini y es el único dueño del proceso: este script
# debe reescribirse para crear carreras vía UI/SM antes de volver a usarse.
#
# switch-zone.sh — Activa una zona temática del servidor Assetto Corsa RD
# Uso: ./switch-zone.sh [drift|touge|trackday|race|status]
#
# Zonas de pista (el resto de la comunidad vive en Discord):
#   drift    → DRIFT ZONE      pista `drift`        · coches de drift
#   touge    → TOUGE / STREET  `ks_highlands/long`  · coches de calle
#   trackday → TRACK DAYS      `spa`                · mixto GT3 + calle
#   race     → RACE EVENTS     `ks_nurburgring/gp_a`· grid GT3
#
# DOMINICAN GARAGE no es zona de pista: es el espacio de setups/coches en Discord.

set -euo pipefail

CFG_DIR="/srv/assetto-corsa/assetto/cfg"
SERVICE="assetto-acserver"
BACKUP_DIR="/srv/assetto-corsa/cfg-backups"
TS="$(date +%Y%m%d-%H%M%S)"

RD_NAME='🇩🇴 Assetto Corsa RD - Comunidad Dominicana'
RD_DESC='Servidor oficial de la comunidad dominicana de Assetto Corsa | Carreras, Drift, Touge & Comunidad 🇩🇴'
RD_WELCOME='🇩🇴 ¡BIENVENIDO A LA COMUNIDAD DOMINICANA DE ASSETTO CORSA! 🏁'
RD_MOTD='🇩🇴 ¡BIENVENIDO A LA COMUNIDAD DOMINICANA DE ASSETTO CORSA! 🏁\n\n¡Qué lo qué, piloto! Bienvenido a nuestro espacio dedicado a compartir nuestra pasión por el automovilismo y las carreras virtuales.\n\n🏎️ Carreras, Drift, Touge, Track Days, Competencias y Comunidad.\n💬 Discord: https://discord.gg/6Sc5KAg3Sk\n📱 WhatsApp: https://chat.whatsapp.com/FUpozjvDAjLHeEFY7IJmxe\n\n🤝 Respeta a los demás pilotos. ¡Nos vemos en la pista! 🏁\n🇩🇴 Representando a República Dominicana en cada curva!'

usage() {
  echo "Uso: $0 [drift|touge|trackday|race|status]"
  echo ""
  echo "  drift    → DRIFT ZONE      (pista drift, coches de drift)"
  echo "  touge    → TOUGE / STREET  (ks_highlands/long, coches de calle)"
  echo "  trackday → TRACK DAYS      (spa, mixto GT3 + calle)"
  echo "  race     → RACE EVENTS     (ks_nurburgring/gp_a, grid GT3)"
  echo "  status   → muestra la zona activa y el estado del servicio"
  exit 1
}

require_cfg() {
  [ -f "$CFG_DIR/server_cfg.ini" ] || { echo "ERROR: no existe $CFG_DIR/server_cfg.ini"; exit 1; }
}

admin_pw() {
  grep -m1 '^ADMIN_PASSWORD=' "$CFG_DIR/server_cfg.ini" 2>/dev/null | cut -d= -f2- || echo "admin123"
}

backup_current() {
  mkdir -p "$BACKUP_DIR"
  cp "$CFG_DIR/server_cfg.ini" "$BACKUP_DIR/server_cfg.ini.$TS" 2>/dev/null || true
  cp "$CFG_DIR/entry_list.ini" "$BACKUP_DIR/entry_list.ini.$TS" 2>/dev/null || true
  echo "  backup → $BACKUP_DIR/*.$TS"
}

write_server_cfg() {
  local cars="$1" track="$2" ctrack="$3" maxc="$4" prac="$5" qual="$6" laps="$7" zone="$8"
  local pw
  pw="$(admin_pw)"
  cat > "$CFG_DIR/server_cfg.ini" <<EOF
[SERVER]
NAME=$RD_NAME
DESCRIPTION=$RD_DESC
CARS=$cars
TRACK=$track
CONFIG_TRACK=$ctrack
SUN_ANGLE=60
GAS_PENALTY_DISABLED=0
ALLOWED_TYRES_OUT=2
QUALIFY_MAX_WAIT_PERC=100
PICKUP_MODE_ENABLED=1
LOOP_MODE=1
SLEEP_TIME=0
SESSION_WAIT_TIME=120
REVERSE_GRID=0
MAX_CLIENTS=$maxc
ADMIN_PASSWORD=$pw
FUEL_RATE=20
TYRE_WEAR_RATE=40
DAMAGE_MULTIPLIER=100
DYNAMIC_TRACK_MODE=0
IS_SPECTATOR_MODE=0
RACE_OVER_TIME=120
START_TIME=0
TIME_OF_DAY_MULT=0
BLACKLIST_MODE=0
REGISTER_TO_LOBBY=0
CLIENT_SEND_INTERVAL_HZ=18
UDP_PORT=9600
TCP_PORT=9600
HTTP_PORT=8081
WELCOME_MESSAGE=$RD_WELCOME
RESULT_SCREEN_TIME=90

[MOTD]
Text=$RD_MOTD

[PRACTICE]
NAME=$zone — Práctica
TIME=$prac
IS_OPEN=1

[QUALIFY]
NAME=$zone — Clasificación
TIME=$qual
IS_OPEN=1

[RACE]
NAME=$zone — Carrera
LAPS=$laps
WAIT_TIME=60
IS_OPEN=2

[DYNAMIC_TRACK]
SESSION_START=95
RANDOMNESS=2
SESSION_TRANSFER=50
LAP_GAIN=132

[WEATHER_0]
GRAPHICS=3_clear
BASE_TEMPERATURE_AMBIENT=27
BASE_TEMPERATURE_ROAD=39
VARIATION_AMBIENT=0.68
VARIATION_ROAD=1.1

[DATA]
DESCRIPTION=🇩🇴 Servidor Dominicano AC — $zone
EXSERVEREXE=
EXSERVERBAT=
EXSERVERHIDEWIN=0
WEBLINK=
WELCOME_PATH=
EOF
}

write_entry_list() {
  local zone="$1"; shift
  local i=0
  : > "$CFG_DIR/entry_list.ini"
  for model in "$@"; do
    cat >> "$CFG_DIR/entry_list.ini" <<EOF
[CAR_$i]
MODEL=$model
SKIN=0
DRIVERNAME=
TEAM=Republica Dominicana Racing
GUID=
BALLAST=0
RESTRICTOR=0

EOF
    i=$((i+1))
  done
}

restart_and_report() {
  systemctl restart "$SERVICE"
  sleep 10
  echo "  servicio: $(systemctl is-active "$SERVICE")"
  if ss -uln | grep -q ':9600'; then
    echo "  UDP 9600: LISTENING ✅"
  else
    echo "  UDP 9600: NO LISTENING ❌ (revisar /var/log/acserver-rd.log)"
  fi
  echo "  pista: $(grep -m1 '^TRACK=' "$CFG_DIR/server_cfg.ini") $(grep -m1 '^CONFIG_TRACK=' "$CFG_DIR/server_cfg.ini")"
  echo "  coches: $(grep -m1 '^CARS=' "$CFG_DIR/server_cfg.ini" | cut -d= -f2- | tr ';' ' ' | wc -w) modelos"
}

case "${1:-}" in
  drift)
    require_cfg; echo "== DRIFT ZONE =="; backup_current
    write_server_cfg \
      "bmw_m3_e30_drift;bmw_m3_e92_drift;bmw_z4_drift;bmw_m3_e30;bmw_z4;ks_mazda_rx7_tuned" \
      "drift" "" 20 1440 5 3 "DRIFT ZONE"
    write_entry_list drift \
      bmw_m3_e30_drift bmw_m3_e92_drift bmw_z4_drift bmw_m3_e30 bmw_z4 \
      bmw_m3_e30_drift bmw_m3_e92_drift bmw_z4_drift
    restart_and_report
    ;;
  touge)
    require_cfg; echo "== TOUGE / STREET =="; backup_current
    write_server_cfg \
      "bmw_m3_e30;bmw_m3_e92;bmw_z4;alfa_romeo_giulietta_qv;abarth500;bmw_1m;ks_mazda_rx7_spirit_r" \
      "ks_highlands" "long" 20 1440 5 3 "TOUGE"
    write_entry_list touge \
      bmw_m3_e30 bmw_m3_e92 bmw_z4 alfa_romeo_giulietta_qv abarth500 bmw_1m \
      ks_mazda_rx7_spirit_r bmw_m3_e30
    restart_and_report
    ;;
  trackday)
    require_cfg; echo "== TRACK DAYS =="; backup_current
    write_server_cfg \
      "ks_ferrari_488_gt3;ks_lamborghini_huracan_gt3;ks_audi_r8_lms;ks_mclaren_650_gt3;ks_mercedes_amg_gt3;ks_nissan_gtr_gt3;ks_porsche_911_gt3_r_2016;bmw_m3_e92;bmw_z4;ks_mazda_rx7_spirit_r" \
      "spa" "" 22 1440 5 3 "TRACK DAY"
    write_entry_list trackday \
      ks_ferrari_488_gt3 ks_lamborghini_huracan_gt3 ks_audi_r8_lms ks_mclaren_650_gt3 \
      ks_mercedes_amg_gt3 ks_nissan_gtr_gt3 ks_porsche_911_gt3_r_2016 bmw_m3_e92 \
      bmw_z4 ks_mazda_rx7_spirit_r ks_ferrari_488_gt3 ks_audi_r8_lms
    restart_and_report
    ;;
  race)
    require_cfg; echo "== RACE EVENTS =="; backup_current
    write_server_cfg \
      "ks_ferrari_488_gt3;ks_lamborghini_huracan_gt3;ks_audi_r8_lms;ks_mclaren_650_gt3;ks_mercedes_amg_gt3;ks_nissan_gtr_gt3;ks_porsche_911_gt3_r_2016;ks_mazda_rx7_spirit_r;bmw_m3_e30" \
      "ks_nurburgring" "gp_a" 18 30 15 5 "RACE EVENT"
    write_entry_list race \
      ks_ferrari_488_gt3 ks_lamborghini_huracan_gt3 ks_audi_r8_lms ks_mclaren_650_gt3 \
      ks_mercedes_amg_gt3 ks_nissan_gtr_gt3 ks_porsche_911_gt3_r_2016 ks_ferrari_488_gt3 \
      ks_lamborghini_huracan_gt3 ks_audi_r8_lms
    restart_and_report
    ;;
  status)
    require_cfg
    echo "== ZONA ACTIVA =="
    grep -E '^(NAME|TRACK|CONFIG_TRACK|CARS)=' "$CFG_DIR/server_cfg.ini" | cut -c1-120
    echo ""
    echo "  servicio: $(systemctl is-active "$SERVICE")"
    ss -uln | grep ':9600' && echo "  UDP 9600: LISTENING ✅" || echo "  UDP 9600: NO LISTENING ❌"
    echo "  slots entry_list: $(grep -c '^\[CAR_' "$CFG_DIR/entry_list.ini")"
    ;;
  *)
    usage
    ;;
esac

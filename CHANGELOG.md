# CHANGELOG — Assetto Corsa Server

## 2026-10-30

### [15:46] - Restauración del paquete oficial v1.15 + servidor controlado por el Server Manager
- **Tipo**: infra + servicio + config
- **Modificado**:
  - `/srv/assetto-corsa/assetto/{acServer,acServer.real}` (wrapper v3 + ELF real v1.15)
  - `/srv/assetto-corsa/assetto/content/{cars,tracks,weather}` (paquete auténtico: 178 coches con `data.acd`, 21 pistas con `layout_*`, 7 weather; `ui/` copiado a las 21 pistas)
  - `/srv/assetto-corsa/assetto/system/` (paquete oficial)
  - `/srv/assetto-corsa/config.yml` (`scan_content_folder_for_changes: false`, backup `.bkup-20261030-lobby`)
  - `/etc/systemd/system/assetto-acserver.service` → **eliminado** (backup `/root/assetto-acserver.service.bkup-20261030`, `daemon-reload`; `is-enabled` → `not-found`)
  - `/tmp/ac-game` borrado (43 GB liberados; `df` 45G usados / 100G libres)
- **Afecta a**: vps-preprod (servidor AC), comunidad dominicana
- **Causa**: un `app_update`+`validate` contra `/srv/assetto-corsa/assetto` borró el paquete real (quedó un esqueleto stub); además el arranque standalone por systemd chocaba con el Server Manager
- **Estado**: ✅ servidor **Running** arrancado desde el SM; ⚠️ join de cliente real pendiente de verificación
- **Verificación LIVE**:
  - `GET /custom/load/fd8236dc-1871-41e7-90f4-c35b5b686308` → `302 → /live-timing` (botón Start de la carrera guardada)
  - `docker exec assetto-corsa-server ps -ef | grep [a]cServer` → `./acServer.real` vivo (hijo del SM, PID 19)
  - `ss -lunp | grep 9600` + `ss -ltnp | grep 9600` → UDP/TCP escuchando; `:8081` HTTP OK
  - `curl -s http://127.0.0.1:8081/INFO` → nombre del evento, `track=ks_nurburgring`, `track_config=layout_gp_a`, 12 clients
  - Log `logs/session/output_2026-30-10_15-45-06.log`: `DRS Zones found at 'layout_gp_a/data/drs_zones.ini'`, `CHECKSUM: .../layout_gp_a/data/surfaces.ini=cd21500d7f079700b7953897932d1250`, `Server started`; estable a 20/30/90 s
  - Panel: home **"Assetto Server Running"**; `error/` vacío; contenedor `RestartCount=0`, `OOMKilled=false`
  - `CPU overload`: 24 warnings en ~20 min, agrupados tras cada sondeo `GET /INFO` del SM (pasos 100-400 ms por serializar 178 coches); cosmético, el proceso sigue vivo
- **Causa raíz del apagado silencioso**: `REGISTER_TO_LOBBY=1` → el lobby de Kunos (`93.57.10.21`) responde 404 y v1.15 se apaga solo tras 5 intentos (`LOBBY COULD NOT BE RACHED, SHUTTING SERVER DOWN`), con exit limpio (SM solo loguea "process ended" si hay error)
- **Wrapper v3** (`assetto/acServer`, copia versionada en `scripts/acServer-wrapper.sh`): dedupe `[LAUNCHER]`, garantiza `[WEATHER_0]`, fuerza `REGISTER_TO_LOBBY=0` y `SLEEP_TIME=1`, inyecta `CONFIG_TRACK=layout_gp_a` solo si `TRACK=ks_nurburgring` y viene vacío, mantiene symlinks `cfg/`, `exec ./acServer.real`
- **Correcciones a entradas previas**:
  - El config real que lee el binario es `content/config/server_cfg.ini` (el wrapper crea `cfg/` como symlink); la entrada [03:30] decía lo contrario
  - `CONFIG_TRACK` correcto es el nombre literal de carpeta **`layout_gp_a`** (no `gp_a`)
  - App **244210** (depot Windows con force platform, cuenta `warc0ld`) — la App 302550 **no** tiene depot Linux (descartada con evidencia)
  - Ya no hay servicio systemd: el SM es el único dueño del proceso
- **Pendientes**:
  - Join real de un cliente por `srv00.assetto.armada.do:9600` (checksums `data.acd`/pista)
  - Rotar `ADMIN_PASSWORD` (juego) y la del panel (una se filtró en un output de diagnóstico)
  - Auto-arranque tras reboot del VPS (hoy requiere Start manual en la UI)
  - `data/map.ini` del live timing (cosmético; no viene en el paquete dedicado)

### [03:30] - Servidor AC VIVO + Identidad Dominicana completa 🇩🇴
- **Tipo**: infra + config + comunidad
- **Modificado**:
  - `/srv/assetto-corsa/assetto/cfg/server_cfg.ini` (MOTD con `\n` reales, CARS alineado al grid)
  - `/etc/systemd/system/assetto-acserver.service` (nuevo, `enable --now`)
  - `/var/log/acserver-rd.log` (log del servicio)
- **Afecta a**: vps-preprod (servidor AC), comunidad dominicana
- **Causa**: el motor AC nunca arrancaba (sin listener UDP 9600) — el Server Manager corría pero no el juego
- **Estado**: ✅ servidor activo y alcanzable desde internet
- **Verificación LIVE**:
  - `systemctl is-active assetto-acserver` → `active`
  - `ss -uln | grep 9600` → UDP escuchando
  - `ss -tln | grep 9600` → TCP escuchando
  - TCP 9600 alcanzable desde kalimete (test externo)
  - `dig +short srv00.assetto.armada.do` → 154.53.35.102
  - Log: `Server started` + `HTTP server running @ :8081`
- **Identidad aplicada**:
  - Nombre: `🇩🇴 Assetto Corsa RD - Comunidad Dominicana`
  - MOTD con Discord + WhatsApp (saltos de línea corregidos)
  - Grid: 10 slots GT3 (488 GT3, Huracán GT3, R8 LMS, 650S GT3, AMG GT3, GT-R GT3, 911 GT3 R 2016, Mazda RX-7, BMW M3 E30)
  - Pista: `ks_nurburgring` layout `gp_a`
- **Bloqueante resuelto**: `entry_list.ini` tenía 10 coches pero `CARS=` solo permitía 3 → acServer abortaba con `car <modelo> is illegal` y systemd lo reintentaba en loop. Se alineó `CARS=` con el grid completo.
- **Notas**:
  - ⚠️ **Superada por [15:46]**: el config real es `content/config/server_cfg.ini` (no `cfg/`), ya no hay systemd y la App 302550 fue descartada. Ver esa entrada.
  - `ADMIN_PASSWORD` sigue en valor débil de setup — **recomendado rotar**
  - Backups: `server_cfg.ini.bkup-20261030-rd`, `server_cfg.ini.bkup-20261030-motd`

## 2026-10-28

### [20:00] - Creación del proyecto Assetto Corsa
- **Tipo**: infra + proyecto nuevo
- **Modificado**: estructura completa del proyecto + agente
- **Afecta a**: kalimete (nuevo subagente `Assetto Corsa`)
- **Causa**: crear servidor de carreras online para República Dominicana
- **Estado**: ✅ estructura creada, ⚠️ bloqueado (Steam license)
- **Notas**: 
  - Agente `assetto.md` creado en `~/armada-sync/agents/`
  - Harness JSON creado en `~/armada-sync/harness/`
  - PROJECT.md creado con arquitectura completa
  - Repo Server Manager archivado pero Docker image funciona
  - Steam license es bloqueante (~$15 USD) — **SUPERADO 2026-10-30**: se instaló el paquete dedicado con la licencia del juego (App 244210, depot Windows con force platform)

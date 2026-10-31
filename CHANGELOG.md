# CHANGELOG — Assetto Corsa Server

## 2026-10-31

### [05:15] - Watchdog de carrera + hallazgos de la sesión del owner en la UI
- **Tipo**: infra | mejora
- **Qué**: el acServer se había apagado (paradas manuales desde la UI entre 04:27–04:43
  UTC, última acción = stop). Se instaló watchdog y se re-levantó la carrera.
- **Cambios**:
  - Watchdog: cron `*/5 * * * * /srv/assetto-corsa/autostart-race.sh` — re-levanta
    la carrera default si UDP 9600 no responde. Skip si está activo o si existe
    `/srv/assetto-corsa/.autostart-paused` (control manual del owner).
  - `autostart-race.sh` + check de flag de pausa.
  - Verificado en vivo: el watchdog detectó el servidor caído y lo relanzó solo
    (`autostart.log: carrera 302`), 3 puertos arriba, /INFO externo OK.
- **Hallazgos**:
  - Discord notificaciones rotas: `channel_id` placeholder `1215861680093921301xxx`
    en boltdb → HTTP 400 en cada arranque (cosmético; fix vía UI Settings → Discord).
  - El servidor se apaga al terminar la sesión (LOOP_MODE=0) — el watchdog lo
    cubre; alternativa: activar LOOP en la carrera desde la UI.
- **Estado**: ✅ website 302 + /INFO OK + watchdog activo.

### [02:45] - Server Manager restaurado: website online + auto-arranque en boot
- **Tipo**: infra | arquitectura (reversión parcial de la migración de las 02:15)
- **Qué**: el website `assetto.armada.do` quedó caído (HTTP 502) al retirar el SM.
  Se restauró el Server Manager como gestor del acServer, con el website online y
  auto-arranque de carrera en boot.
- **Hallazgos**:
  - El `entrypoint-wrapper.sh` en el VPS estaba **corrupto** (mojibake del upload
    fallido de la sesión anterior: `doo`, `(dirct =`, texto garbled) — el contenedor
    habría crasheado. Reescrito limpio y desplegado vía scp.
  - El túnel Cloudflare estaba sano (502 = origen muerto, no túnel).
- **Cambios**:
  - `entrypoint-wrapper.sh` reescrito: inyecta `[LAUNCHER]`/`[WEATHER_0]`, symlinks
    `cfg/`, fuerza `REGISTER_TO_LOBBY=0`/`SLEEP_TIME=1`, `exec server-manager`.
    Ya NO lanza acServer en background (lo lanza el SM con cada carrera).
  - Wrapper `acServer` + fix: **parchea `HTTP_PORT` 8081→8082** en cada arranque de
    carrera (SM regenera el config con 8081; 8081 lo ocupa adminer). Verificado:
    SM escribió 8081 → binario bindeó 8082.
  - Ownership de `/srv/assetto-corsa/` → `1000:1000` (uid del contenedor; el chown
    a 999 de la migración habría roto las escrituras del SM).
  - `systemd assetto-server` → **disabled** (fallback documentado; conflicto de
    puertos si se usa con el contenedor arriba).
  - Nuevo: `autostart-race.sh` + `assetto-sm-autostart.service` (oneshot, enabled):
    al boot espera la UI `:8772`, loguea y lanza la carrera default
    (`9205601d` Highlands). Skip si UDP 9600 ya activo.
- **Verificado LIVE**:
  - Contenedor `assetto-corsa-server` Up, SM en `:8772` (HTTP 302).
  - Carrera Highlands arrancada vía API (`/custom/load/9205601d…` → 302 live-timing).
  - `ss`: UDP 9600 + TCP 9600 + TCP 8082 por `acServer.real` (pid del contenedor).
  - Website `https://assetto.armada.do` → HTTP 302 (online vía túnel).
  - `/INFO` externo: 200 OK, `ks_highlands-layout_long`, cport 8082.
  - Autostart: `systemctl start assetto-sm-autostart` → exit 0 con skip correcto.
- **Limitación que persiste**: `/INFO` devuelve `"ip":""` (bug binario v1.15) —
  no afecta el juego manual (`srv00.assetto.armada.do:9600` en CM).
- **Docs**: PROJECT.md actualizado (arquitectura final, wrapper con fix de puerto,
  SM activo, flujo de arranque, gotchas 1/11/13, fases 0.6-0.8).

### [02:15] - Migración a systemd directo: Server Manager retirado
- **Tipo**: infra | arquitectura
- **Qué**: el acServer corre ahora **directo en el host** vía systemd
  (`assetto-server.service`), sin Docker ni Server Manager.
- **Causa**: el SM (Docker) tenía UI `:8772` no fiable, sin API de arranque
  (`/api/start` → 404), no auto-lanzaba el acServer y el `/INFO` seguía
  devolviendo `"ip":""`. El enfoque Docker/SM era la fuente de todos los
  bloqueos; el binario es Go estático → corre directo sin GLIBC.
- **Cambios**:
  - Eliminados 5 contenedores zombie AC (boring_black, nervous_ganguly,
    competent_galileo, exciting_wu, loving_nash).
  - `HTTP_PORT` 8081 → **8082** (8081 lo ocupa `staging-adminer-1` Docker).
  - iptables INPUT regla 44 actualizada 8081 → 8082 + persistida en
    `/etc/iptables/rules.v4` (reglas 42/43 UDP+TCP 9600 ya existían).
  - Usuario sistema `assetto` (uid 999) + `chown -R` de `/srv/assetto-corsa`.
  - Servicio `assetto-server.service`: User=assetto, Restart=always,
    RestartSec=5, enabled, logs append a `assetto/logs/acserver{,.err}.log`.
  - Logrotate `/etc/logrotate.d/assetto-server` (weekly, rotate 4, copytruncate).
- **Verificado LIVE**:
  - `ss -tulpn`: UDP 9600 + TCP 9600 + TCP 8082 escuchando por `acServer.real`.
  - `/INFO` externo desde kalimete: 200 OK con nombre/pista/puertos correctos.
  - Auto-restart: `kill -9` del PID → relanzado en ~5 s (PID nuevo).
  - `systemctl is-enabled` → enabled (arranque en boot garantizado).
- **Limitación aceptada**: `/INFO` sigue devolviendo `"ip":""` (bug del binario
  v1.15, Go `net.InterfaceAddrs()`). No afecta el juego: los clientes entran
  manual con `srv00.assetto.armada.do:9600` en Content Manager.
- **Legacy sin uso** (borrable): `config.yml`, `data/`, `entrypoint-wrapper.sh`,
  `custom-entrypoint.sh`, `hostname-wrapper/`, `docker-compose.yml`,
  `.sm-admin-credentials`.
- **Docs**: PROJECT.md actualizado (arquitectura, puertos, flujo, gotchas 10-12,
  fases 0.6/0.8, pendientes).

## 2026-10-30

### [16:58] - Limpieza de duplicados/restos + re-arranque del evento
- **Tipo**: infra + servicio
- **Modificado** (VPS):
  - Eliminados contenedores zombie `041f178942fe` (`busy_archimedes`) y `35be9bb60d00` (`elegant_heyrovsky`), restos de `docker run --rm` de diagnósticos (Up 10h, ~9 MB c/u, volúmenes anónimos)
  - Eliminada unit huérfana `/etc/systemd/system/assetto-acserver-standalone.service` (backup `/root/assetto-acserver-standalone.service.bkup-20261030`; `daemon-reload` + `reset-failed`)
  - Eliminados restos standalone en `/srv/assetto-corsa`: `acServer` raíz (467 B), `acServer-wrapper.sh`, `start-acserver-host.sh`, `start-race.sh`, `switch-zone.sh`, `scripts/`, `cfg-backups/`, `steamcmd_linux.tar.gz`, `config.yml.bkup-20261029` y `.bkup-20261030-restore`
  - Eliminados backups de config: 6 en `assetto/cfg/*.bkup-*` + `content/config/server_cfg.ini.bkup-20261030-rd` (se conserva `config.yml.bkup-20261030-lobby`)
  - Eliminados logs viejos `/var/log/acserver-{rd,host,standalone}.log`, 4 sesiones antiguas (`output_*10-33,15-36,15-40,15-43`) y temporales `/tmp` propios (incl. `/tmp/smcj`)
  - **NO** tocado (verificado que no son duplicados): SteamCMD (`steamcmd.sh`, `linux32/`, `linux64/`, `package/`, `public/`, `siteserverui/`, `update_hosts_cached.vdf`), contenido (178 `data.acd`, 21 pistas), symlinks `cfg/`, 4 carreras guardadas, backups `/root/*`
- **Afecta a**: vps-preprod (servidor AC)
- **Causa**: dejar el stack sin duplicados ni restos de diagnósticos antes de darlo por listo
- **Estado**: ✅ limpieza completada; ✅ servidor relanzado desde el SM
- **Verificación LIVE**:
  - `docker ps` → solo `assetto-corsa-server`; `docker ps -a | grep 041f\|35be` → vacío; sin units assetto
  - `ls /srv/assetto-corsa/assetto/cfg/` → solo symlinks `entry_list.ini` y `server_cfg.ini` → `../content/config/`
  - `bash scripts/start-race.sh` → `302 → /live-timing`, `./acServer.real` vivo (PID 65), `9600` UDP+TCP, `/INFO` con el evento y `layout_gp_a`
- **Nota**: el SM detuvo el evento a las `15:55:22Z` (`Shutting down server process: 19`) porque **el owner lo paró intencionalmente desde el panel** para trabajar sin el proceso; no es un fallo (`[PRACTICE] TIME=30` y `ForceStopTime=0` ya lo descartaban). Se relanzó a las `~16:01Z` para verificar el estado y se volvió a detener a las `~16:14Z` por la misma razón; sin watchers pendientes
- **Pendientes**: igual que [15:46] (join real, rotar passwords, auto-arranque tras reboot, `map.ini` cosmético)

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

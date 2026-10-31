# Assetto Corsa Server — República Dominicana

## Visión General

Servidor de **Assetto Corsa** online para la comunidad de República Dominicana:
carreras online con panel web (Server Manager), eventos configurables y contenido
oficial del juego. El servidor corre en **vps-preprod** dentro del contenedor del
Server Manager, que lanza el binario Linux `acServer` v1.15.

**Dominio público (panel)**: `assetto.armada.do` (Cloudflare Tunnel → :8772)
**Conexión de pilotos**: `srv00.assetto.armada.do:9600` (UDP, DNS-only → 154.53.35.102)

## Arquitectura real (verificada 2026-10-31)

```
Jugador (Assetto Corsa)
    │ UDP/TCP 9600  (srv00.assetto.armada.do, DNS-only)
    ▼
vps-preprod 154.53.35.102
    │
    ├─ contenedor assetto-corsa-server (seejy/assetto-server-manager, host network,
    │     restart: unless-stopped, docker compose en /srv/assetto-corsa/)
    │     │
    │     ├─ server-manager v1.7.9 (Go) ── UI :8772 ── Cloudflare Tunnel ── assetto.armada.do
    │     │        │ lanza al iniciar una carrera (API /custom/load/{uuid} o UI):
    │     │        ▼
    │     └─ assetto/acServer (wrapper: parchea HTTP_PORT 8081→8082, [LAUNCHER],
    │              │           REGISTER_TO_LOBBY=0, SLEEP_TIME=1, symlinks cfg/)
    │              └─exec──► assetto/acServer.real (ELF 32-bit Go, STATICALLY LINKED)
    │                       ├─ UDP+TCP 9600 (juego)
    │                       └─ HTTP 8082   (API /INFO; 8081 lo ocupa adminer Docker)
    │
    ├─ systemd: assetto-sm-autostart.service (oneshot, enabled)
    │     └─ al boot: espera UI :8772 → lanza la carrera guardada por defecto
    │       (9205601d = Highlands practice). Skip si UDP 9600 ya está activo.
    │
    ├─ systemd: assetto-server.service (FALLBACK, disabled)
    │     └─ acServer directo en host sin SM. NO arrancar con el contenedor arriba
    │       (conflicto de puertos). Si se usa: chown -R 999:987 /srv/assetto-corsa
    │       y detener el contenedor primero.
    │
    └─ /srv/assetto-corsa/
          ├─ assetto/{acServer,acServer.real,content,cfg,system,logs,results,...}
          ├─ config.yml            (config del Server Manager)
          ├─ data/                 (boltdb del SM: carreras guardadas)
          ├─ entrypoint-wrapper.sh (entrypoint del contenedor: prepara config)
          ├─ autostart-race.sh     (lo invoca assetto-sm-autostart.service)
          └─ docker-compose.yml
```

> **Historia 2026-10-31**: se probó acServer directo vía systemd (sin SM) para
> estabilizar; funcionó pero dejó el website `assetto.armada.do` caído (502).
> Estado final: **SM restaurado** gestiona el acServer, systemd queda como
> fallback deshabilitado, y un oneshot auto-arranca la carrera al boot.

## Instalación — método verificado

1. **Se requiere la licencia del juego en Steam** (App **244210**, cuenta `warc0ld`).
   El binario Linux del servidor dedicado **viene dentro del depot Windows**.
2. Descargar con SteamCMD forzando plataforma Windows y directorio destino:

   ```bash
   /srv/assetto-corsa/linux64/steamcmd \
     +@sSteamCmdForcePlatformType windows \
     +force_install_dir /tmp/ac-game \
     +login warc0ld \
     +app_update 244210 \
     +quit
   ```
   - depot 244211: 27.5 GB en disco / 9.05 GB de descarga (más DLC de la cuenta → ~43 GB).
   - El paquete queda en la **raíz** de `/tmp/ac-game` (no en `steamapps/common`).
   - El servidor Linux está en `/tmp/ac-game/server/` (`acServer`, `cfg/`, `content/`, `system/`).

3. Instalar en `/srv/assetto-corsa/assetto/`:
   - `server/acServer` → `acServer.real` (5.4 MB, 1000:1000, 755).
   - `server/system/` → `system/`.
   - `server/content/cars/*` (178 coches con `data.acd`) → `content/cars/`.
   - `server/content/tracks/*` (21 pistas auténticas, con `layout_*`) → `content/tracks/`.
   - `server/content/weather/*` (7 presets) → `content/weather/`.
   - No se copian skins (el SM avisa y omite `SKIN=`; los clientes usan la skin por defecto).

4. **Nunca** ejecutar `app_update`/`validate` contra `/srv/assetto-corsa/assetto`:
   el depósito no coincide con la instalación viva y la borra (causa raíz del incidente).

> App **302550** (Server Tools) **no sirve**: no tiene depot Linux
> (`No subscription` / `Invalid platform`). Descartada con evidencia.

## Wrapper `assetto/acServer` (obligatorio)

El SM genera `content/config/server_cfg.ini` con bugs/omisiones que el binario v1.15
no tolera. El wrapper se ejecuta en cada arranque de carrera (SM → acServer) y:

1. Deja **una sola** sección `[LAUNCHER]` (el binario hace panic si no existe; vacía basta).
2. Garantiza `[WEATHER_0]` (sin ella: `panic: invalid argument to Intn` en `UpdateWeather`).
3. Fuerza `REGISTER_TO_LOBBY=0` (el lobby de Kunos `93.57.10.21` responde 404 y el
   servidor se apaga solo tras 5 intentos: `LOBBY COULD NOT BE RACHED`).
4. Fuerza `SLEEP_TIME=1` (con 0: `CPU overload`).
5. **Parchea `HTTP_PORT` 8081 → 8082** (el SM regenera el config con 8081 en cada
   carrera; 8081 lo ocupa `staging-adminer-1` en el host — verificado 2026-10-31).
6. Si `TRACK=ks_nurburgring` y `CONFIG_TRACK=` viene vacío, inyecta
   `CONFIG_TRACK=layout_gp_a` (nombre real de la carpeta; sin esto el server busca
   `.../ks_nurburgring/data/` y los checksums de pista no cuadran).
7. Mantiene los symlinks `cfg/server_cfg.ini` y `cfg/entry_list.ini` →
   `content/config/…`, y ejecuta `./acServer.real "$@"`.

## Server Manager v1.7.9 (activo, restaurado 2026-10-31)

- Imagen `seejy/assetto-server-manager:latest`, usuario `assetto` (uid 1000 del
  contenedor → **los archivos montados deben ser 1000:1000 en el host**),
  `network_mode: host`, UI `:8772`, boltdb en `data/`, compose en
  `/srv/assetto-corsa/docker-compose.yml` con `restart: unless-stopped`.
- **Entrypoint custom** (`entrypoint-wrapper.sh`): inyecta `[LAUNCHER]`/`[WEATHER_0]`,
  symlinks `cfg/`, fuerza `REGISTER_TO_LOBBY=0`/`SLEEP_TIME=1`, y `exec server-manager`.
  El acServer lo lanza el propio SM al iniciar una carrera (no el entrypoint).
- **Arranque de carrera**: NO existe API simple (`/api/start` → 404). Se hace:
  - UI: botón **Start** de una carrera guardada (`GET /custom/load/{uuid}`).
  - API (lo que usa el autostart): login POST + `GET /custom/load/{uuid}`.
- Carreras guardadas (boltdb):
  | UUID | Nombre |
  |---|---|
  | `9205601d-413c-400a-a477-52bf42c75469` | 🇩🇴 \| Another day of practice at Highlands (**default del autostart**) |
  | `371cd0f4-3e56-416f-8e1f-235d2b9b336f` | 🇩🇴 \| BMW M235i at Zandvoort |
  | `765e6e8f-fd10-410f-86f0-0efbc0a5236f` | 🇩🇴 \| F1 2004 at Spa |
  | `fd8236dc-1871-41e7-90f4-c35b5b686308` | 🇩🇴 \| Another day of practice at Nürburgring GP |
- `config.yml`: `steam.username: "anonymous"` (el botón Install/Update de la UI fallará;
  el contenido se instala a mano) y `scan_content_folder_for_changes: false`.
- Credenciales del panel: `/srv/assetto-corsa/.sm-admin-credentials` (no imprimir).

## Puertos

| Puerto | Protocolo | Servicio | Acceso |
|--------|-----------|----------|--------|
| 8772 | TCP | Server Manager UI | Cloudflare Tunnel (`assetto.armada.do`) |
| 9600 | UDP + TCP | Juego Assetto Corsa | Internet (`srv00.assetto.armada.do`) |
| 8082 | TCP | HTTP API del juego (`/INFO`) | Internet (regla iptables 44) |

- ⚠️ **8081 NO disponible**: lo publica `staging-adminer-1` (Docker). El SM escribe
  `HTTP_PORT=8081` en cada carrera y el **wrapper acServer lo parchea a 8082**
  antes de lanzar el binario (verificado: `ss` muestra 8082, config queda 8082).
- Firewall: iptables INPUT reglas 42 (UDP 9600), 43 (TCP 9600), 44 (TCP 8082),
  persistidas en `/etc/iptables/rules.v4` (verificado 2026-10-31).
- ⚠️ **Limitación conocida `/INFO`**: el binario v1.15 responde `"ip":""` (Go
  `net.InterfaceAddrs()` con múltiples interfaces). **No afecta el juego**: los
  clientes entran manual con `srv00.assetto.armada.do:9600` en Content Manager.
  Solo impide el auto-join por URL del server browser.

## Identidad actual

El nombre visible lo compone el SM: `La Vgz - Assetto Corsa - Republica Dominicana`
(config del SM) + nombre del evento de la carrera guardada.

| Elemento | Valor actual |
|---|---|
| Nombre en `/INFO` | `La Vgz - Assetto Corsa - Republica Dominicana - 🇩🇴 \| Another day of practice at Highlands` |
| Pista | `ks_highlands` · layout `layout_long` |
| Parrilla | 12 slots libres (entry_list sin AI) |
| Sesión | Practice 30 min (`[PRACTICE]` IS_OPEN=1) |
| Admin | `ADMIN_PASSWORD` en server_cfg.ini (rotar pendiente) |
| Discord | https://discord.gg/6Sc5KAg3Sk |
| WhatsApp | https://chat.whatsapp.com/FUpozjvDAjLHeEFY7IJmxe |

Las zonas temáticas (Drift, Touge, Track Days, Race Events, Dominican Garage) siguen
como planificación de comunidad; se configuran creando carreras en el SM.

## Flujo de arranque (verificado 2026-10-31)

```bash
# 1. Estado del contenedor + SM
ssh vps-preprod "docker ps --format '{{.Names}} {{.Status}}' | grep assetto"
curl -s -o /dev/null -w '%{http_code}\n' https://assetto.armada.do   # 302 = online

# 2. Arrancar carrera manualmente (si el autostart no lo hizo)
ssh vps-preprod 'PW=$(awk -F": " "/^Password:/{print \$2}" /srv/assetto-corsa/.sm-admin-credentials); CJ=$(mktemp); curl -s -c $CJ -o /dev/null --data-urlencode "Username=admin" --data-urlencode "Password=$PW" http://127.0.0.1:8772/login; curl -s -b $CJ -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8772/custom/load/9205601d-413c-400a-a477-52bf42c75469'

# 3. Verificación de puertos + /INFO
ssh vps-preprod "ss -tulpn | grep -E '9600|8082'"
curl -s http://154.53.35.102:8082/INFO | head -c 200

# 4. Logs
ssh vps-preprod "docker logs assetto-corsa-server --tail 20"
```

- **Boot del VPS**: docker compose levanta el contenedor (`restart: unless-stopped`)
  → `assetto-sm-autostart.service` (oneshot, enabled) espera la UI y lanza la
  carrera default (Highlands). Skip automático si UDP 9600 ya está activo.
- **Watchdog (cron cada 5 min)**: `/srv/assetto-corsa/autostart-race.sh` re-levanta
  la carrera default si el acServer cae (fin de sesión, crash, stop accidental).
  Skip si UDP 9600 activo o si existe `/srv/assetto-corsa/.autostart-paused`
  (crear ese archivo para detener el watchdog; borrarlo para reactivar).
  Log: `/srv/assetto-corsa/autostart.log`.
  - El script parchea `ADDRESS=154.53.35.102` en el config ANTES de cargar la carrera.
- **IPv6 deshabilitado (VPS)**: `/etc/sysctl.d/99-disable-ipv6.conf` fuerza
  `net.ipv6.conf.all.disable_ipv6=1` → el acServer se bind SOLO a IPv4.
  Sin esto, el LAN browser del AC mostraba `2605:a142:...` (IPv6 del túnel CF).
- **Fallback sin SM**: `assetto-server.service` (disabled) corre el acServer directo
  en host. NO usar con el contenedor arriba (conflicto de puertos); requiere
  `chown -R 999:987 /srv/assetto-corsa` (el servicio corre como uid 999).
- Rotación de logs del fallback: `/etc/logrotate.d/assetto-server` (weekly, rotate 4).

## Gotchas verificados en vivo (2026-10-31)

1. **El SM es el dueño del servidor** (restaurado 2026-10-31): el acServer lo lanza
   el SM al iniciar una carrera. `docker restart assetto-corsa-server` mata el
   acServer; el autostart systemd lo relanza al boot, o arrancar carrera a mano
   (UI o `GET /custom/load/{uuid}`).
2. **Config real**: `content/config/server_cfg.ini` + `entry_list.ini`. `cfg/` son symlinks
   creados por el wrapper; editar `cfg/` no persiste.
3. **Layout de pista**: el binario usa `content/tracks/<track>/<CONFIG_TRACK>/data/...`
   con el nombre **literal** de la carpeta → para Nürburgring GP es `layout_gp_a`
   (no `gp_a`). Sin layout, no hay checksum de `surfaces.ini` y los clientes fallan.
4. **Lobby muerto**: con `REGISTER_TO_LOBBY=1` el server se apaga solo (404 tras 5 intentos).
   El wrapper lo fuerza a 0 en cada arranque.
5. **`[LAUNCHER]` y `[WEATHER_0]`**: sin ellas, panic al arrancar (el wrapper las garantiza).
6. **No hay skins**: los clientes usan la skin por defecto (no es error).
7. **`CPU overload` en el log no es saturación del host**: warnings agrupados tras
   sondeos `/INFO`; no matan el proceso.
8. **Los mapas de pista** (`ui/ui_track.json`, `data/map.ini`) no vienen en el
   paquete dedicado; se copiaron los `ui/` de las 21 pistas (cosmético).
9. **Credenciales débiles**: `ADMIN_PASSWORD` del juego está en valor de setup; rotar.
10. **`/INFO` devuelve `"ip":""`**: limitación del binario v1.15 (Go + múltiples
    interfaces). No afecta el juego manual; impide auto-join por URL del browser.
11. **Puerto 8081 ocupado por adminer** (Docker): el SM escribe `HTTP_PORT=8081`
    en cada carrera y el wrapper acServer lo parchea a 8082 antes de lanzar el
    binario. Si algún día se libera 8081, quitar el sed del wrapper y la regla
    iptables 44 de 8082.
12. **Binario estáticamente enlazado**: `acServer.real` es Go 32-bit static →
    corre en cualquier host sin depender de GLIBC (verificado con `ldd`:
    "not a dynamic executable"). Es lo que permite el fallback systemd directo.
13. **Ownership de los montajes**: el contenedor corre como uid 1000 → los
    archivos de `/srv/assetto-corsa/` deben ser `1000:1000`. El fallback systemd
    usa uid 999 (`assetto`): si se alterna entre ambos, ajustar el `chown`.
14. **Discord notificaciones rotas (cosmético)**: el boltdb tiene un `channel_id`
    placeholder inválido (`1215861680093921301xxx`) → en cada arranque de carrera
    SM loguea `couldn't send discord message: HTTP 400 ... is not snowflake`.
    No afecta el servidor. Fix: UI → Settings → Discord → poner un channel_id
    real o vaciar la config de notificaciones.
15. **El servidor se apaga al terminar la sesión** (LOOP_MODE=0): Practice 30 min
    → acServer exit → SM marca el evento terminado. El watchdog lo re-levanta en
    ≤5 min. Si se quiere loop continuo sin watchdog, activar LOOP en la carrera
    desde la UI del SM.

## Fases

| Fase | Estado | Descripción |
|------|--------|-------------|
| 0 | ✅ | Estructura del proyecto + documentación |
| 0.5 | ✅ | Paquete oficial v1.15 restaurado (App 244210, depot Windows) |
| 0.6 | ✅ | Server Manager + Docker (restaurado 2026-10-31 tras prueba sin SM) |
| 0.7 | ✅ | DNS `srv00.assetto.armada.do` (UDP/TCP 9600) + túnel `assetto.armada.do` |
| 0.8 | ✅ | Servidor AC vivo + website online + auto-arranque en boot (2026-10-31) |
| 1 | ⏳ | Verificar join de un cliente real + ajustar carreras/zonas |
| 2 | ⏳ | Contenido adicional (tracks/cars) si la comunidad lo pide |
| 3 | ⏳ | Discord/Stracker |
| 4 | ⏳ | QA y deploy final |

## Notas de troubleshooting (2026-10-31)

### Crash del acServer cada ~2 min
- **Causa**: El binario v1.15 se crashea con "signal: terminated" cuando se ejecuta
  en el contenedor con `network_mode: host` y el SM lo reinicia constantemente.
  El problema se resuelve reiniciando el contenedor (`docker restart assetto-corsa-server`)
  después de parchear el config del race.
- **Solución**: 
  1. Deshabilitar IPv6 en el VPS: `/etc/sysctl.d/99-disable-ipv6.conf`
  2. Parchear `config.yml` con `monitoring.plugins: []`
  3. Reiniciar el contenedor
  4. Usar `autostart-race.sh` para cargar la carrera automáticamente

### Config del race no se aplica al acServer
- El acServer lee el config SOLO al iniciar. Si se parchea el config después de que
  el acServer arranca, los cambios NO se aplican hasta el siguiente reinicio.
- **Solución**: El script `autostart-race.sh` parchea el config ANTES de cargar la
  carrera (cuando el SM regenera el config) y luego matar el acServer para que
  se reinicie con los valores nuevos.
- **Config aplicada**: `SESSION_START=30`, `WAIT_TIME=30`, `PICKUP_MODE_ENABLED=1`,
  `LOOP_MODE=1`, `RACE_PIT_WINDOW_START=0`, `RACE_PIT_WINDOW_END=0`.

### IPv6 deshabilitado (VPS)
- Se deshabilitó IPv6 en el VPS para forzar que el acServer se bind SOLO a IPv4.
- Sin esto, el LAN browser del AC mostraba `2605:a142:...` (IPv6 del túnel Cloudflare).
- Archivo: `/etc/sysctl.d/99-disable-ipv6.conf`
- Contenido: `net.ipv6.conf.all.disable_ipv6=1` y `net.ipv6.conf.default.disable_ipv6=1`
- Comando de aplicar: `sysctl -w net.ipv6.conf.all.disable_ipv6=1`

## Pendientes conocidos

- **Join real de cliente** por `srv00.assetto.armada.do:9600` (checksums `data.acd`/pista).
- Rotar `ADMIN_PASSWORD` (juego).
- (Opcional) proxy que parchee `"ip":""` en `/INFO` si se quiere auto-join por URL.
- `ui_track.json`/`map.ini` del live timing (cosmético).
- **Config del race**: El autostart parchea la config del container (no el host mount)
  ANTES de cargar la carrera, y luego mata el acServer para que se reinicie con
  los valores nuevos. Esto evita que el SM sobrescriba los valores de `SESSION_START`,
  `WAIT_TIME`, etc.

## Upstream References

- Server Manager: https://github.com/JustaPenguin/assetto-server-manager
- Docker Image: https://hub.docker.com/r/seejy/assetto-server-manager
- Content Manager: https://content-manager.net/
- Steam App (juego): https://store.steampowered.com/app/244210/

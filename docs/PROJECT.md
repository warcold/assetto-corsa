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
    ├─ systemd: assetto-server.service (User=assetto, Restart=always, enabled)
    │     │
    │     └─ assetto/acServer (wrapper) ──exec──► assetto/acServer.real
    │              │            (ELF 32-bit Go, STATICALLY LINKED → sin dependencia GLIBC)
    │              ├─ UDP+TCP 9600 (juego)
    │              └─ HTTP 8082   (API /INFO; 8081 lo ocupa adminer Docker)
    │
    └─ /srv/assetto-corsa/
          ├─ assetto/{acServer,acServer.real,content,cfg,system,logs,results,...}
          ├─ config.yml            (legacy del SM, ya sin uso)
          └─ data/                 (legacy boltdb del SM, ya sin uso)
```

> **2026-10-31**: el Server Manager (Docker, `:8772`) fue **retirado** — su UI no
> respondía, no auto-arrancaba el acServer y el `/INFO` del juego seguía vacío.
> El acServer corre ahora **directo en el host** vía systemd. Los contenedores
> zombie AC fueron eliminados. `config.yml`, `data/`, `entrypoint-wrapper.sh`,
> `custom-entrypoint.sh`, `hostname-wrapper/` y `docker-compose.yml` quedan como
> legacy (se pueden borrar).

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
no tolera. El wrapper (1227 B) se ejecuta en cada arranque y:

1. Deja **una sola** sección `[LAUNCHER]` (el binario hace panic si no existe; vacía basta).
2. Garantiza `[WEATHER_0]` (sin ella: `panic: invalid argument to Intn` en `UpdateWeather`).
3. Fuerza `REGISTER_TO_LOBBY=0` (el lobby de Kunos `93.57.10.21` responde 404 y el
   servidor se apaga solo tras 5 intentos: `LOBBY COULD NOT BE RACHED`).
4. Fuerza `SLEEP_TIME=1` (con 0: `CPU overload`).
5. Si `TRACK=ks_nurburgring` y `CONFIG_TRACK=` viene vacío, inyecta
   `CONFIG_TRACK=layout_gp_a` (nombre real de la carpeta; sin esto el server busca
   `.../ks_nurburgring/data/` y los checksums de pista no cuadran).
6. Mantiene los symlinks `cfg/server_cfg.ini` y `cfg/entry_list.ini` →
   `content/config/…`, y ejecuta `./acServer.real "$@"`.

## Server Manager v1.7.9 — RETIRADO (2026-10-31)

> ⚠️ **Deprecado**: la UI `:8772` no respondía de forma fiable, no existía API de
> arranque (`/api/start` → 404) y no auto-lanzaba el acServer. Se retiró el
> contenedor y el acServer corre directo vía systemd. Las carreras guardadas del
> boltdb (`data/server_manager.db`) ya no se usan; la config viva es
> `content/config/server_cfg.ini` + `entry_list.ini`.
> Si algún día se revive el SM, sus imágenes/entrypoints legacy siguen en
> `/srv/assetto-corsa/` (config.yml, data/, entrypoint-wrapper.sh).

## Puertos

| Puerto | Protocolo | Servicio | Acceso |
|--------|-----------|----------|--------|
| 9600 | UDP + TCP | Juego Assetto Corsa | Internet (`srv00.assetto.armada.do`) |
| 8082 | TCP | HTTP API del juego (`/INFO`) | Internet (regla iptables 44) |

- ⚠️ **8081 NO disponible**: lo publica `staging-adminer-1` (Docker) → el HTTP del
  juego se movió a **8082** (`HTTP_PORT` en `server_cfg.ini`).
- Firewall: iptables INPUT reglas 42 (UDP 9600), 43 (TCP 9600), 44 (TCP 8082),
  persistidas en `/etc/iptables/rules.v4` (verificado 2026-10-31).
- ⚠️ **Limitación conocida `/INFO`**: el binario v1.15 responde `"ip":""` (Go
  `net.InterfaceAddrs()` con múltiples interfaces). **No afecta el juego**: los
  clientes entran manual con `srv00.assetto.armada.do:9600` en Content Manager.
  Solo impide el auto-join por URL del server browser.

## Identidad actual

El nombre visible viene directo de `NAME=` en `content/config/server_cfg.ini`
(antes lo componía el SM, ya retirado).

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
# Estado del servicio
ssh vps-preprod "systemctl status assetto-server --no-pager | head -8"

# Reinicio manual
ssh vps-preprod "systemctl restart assetto-server"

# Verificación de puertos + /INFO
ssh vps-preprod "ss -tulpn | grep -E '9600|8082'"
curl -s http://154.53.35.102:8082/INFO | head -c 200

# Logs en vivo
ssh vps-preprod "tail -f /srv/assetto-corsa/assetto/logs/acserver.log"
```

- Auto-restart verificado: `kill -9` del PID → systemd relanza en ~5 s (`RestartSec=5`).
- Auto-arranque en boot: `systemctl is-enabled assetto-server` → enabled.
- Rotación de logs: `/etc/logrotate.d/assetto-server` (weekly, rotate 4, copytruncate).

## Gotchas verificados en vivo (2026-10-31)

1. **systemd es el dueño del servidor** (desde 2026-10-31): `systemctl restart
   assetto-server` reinicia todo limpio. Ya no hay contenedor ni UI.
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
11. **Puerto 8081 ocupado por adminer** (Docker): el HTTP del juego vive en 8082.
    Si algún día se libera 8081, revertir `HTTP_PORT` y la regla iptables 44.
12. **Binario estáticamente enlazado**: `acServer.real` es Go 32-bit static →
    corre en cualquier host sin depender de GLIBC (verificado con `ldd`:
    "not a dynamic executable").

## Fases

| Fase | Estado | Descripción |
|------|--------|-------------|
| 0 | ✅ | Estructura del proyecto + documentación |
| 0.5 | ✅ | Paquete oficial v1.15 restaurado (App 244210, depot Windows) |
| 0.6 | ✅ | Server Manager + Docker → **retirado 2026-10-31** (UI rota, sin auto-start) |
| 0.7 | ✅ | DNS `srv00.assetto.armada.do` (UDP/TCP 9600) |
| 0.8 | ✅ | Servidor AC vivo vía **systemd directo** (`assetto-server`, 2026-10-31) |
| 1 | ⏳ | Verificar join de un cliente real + ajustar carreras/zonas |
| 2 | ⏳ | Contenido adicional (tracks/cars) si la comunidad lo pide |
| 3 | ⏳ | Discord/Stracker |
| 4 | ⏳ | QA y deploy final |

## Pendientes conocidos

- **Join real de cliente** por `srv00.assetto.armada.do:9600` (checksums `data.acd`/pista).
- Rotar `ADMIN_PASSWORD` (juego).
- (Opcional) limpiar legacy del SM en `/srv/assetto-corsa/`: `config.yml`, `data/`,
  `entrypoint-wrapper.sh`, `custom-entrypoint.sh`, `hostname-wrapper/`,
  `docker-compose.yml`, `.sm-admin-credentials`.
- (Opcional) proxy que parchee `"ip":""` en `/INFO` si se quiere auto-join por URL.
- `ui_track.json`/`map.ini` del live timing (cosmético).

## Upstream References

- Server Manager: https://github.com/JustaPenguin/assetto-server-manager
- Docker Image: https://hub.docker.com/r/seejy/assetto-server-manager
- Content Manager: https://content-manager.net/
- Steam App (juego): https://store.steampowered.com/app/244210/

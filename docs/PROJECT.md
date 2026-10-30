# Assetto Corsa Server — República Dominicana

## Visión General

Servidor de **Assetto Corsa** online para la comunidad de República Dominicana:
carreras online con panel web (Server Manager), eventos configurables y contenido
oficial del juego. El servidor corre en **vps-preprod** dentro del contenedor del
Server Manager, que lanza el binario Linux `acServer` v1.15.

**Dominio público (panel)**: `assetto.armada.do` (Cloudflare Tunnel → :8772)
**Conexión de pilotos**: `srv00.assetto.armada.do:9600` (UDP, DNS-only → 154.53.35.102)

## Arquitectura real (verificada 2026-10-30)

```
Jugador (Assetto Corsa)
    │ UDP/TCP 9600  (srv00.assetto.armada.do, DNS-only)
    ▼
vps-preprod 154.53.35.102
    │
    ├─ contenedor assetto-corsa-server (seejy/assetto-server-manager, host network)
    │     │
    │     ├─ server-manager v1.7.9 (Go) ── UI :8772 ── Cloudflare Tunnel ── assetto.armada.do
    │     │        │ genera content/config/{server_cfg,entry_list}.ini y lanza:
    │     │        ▼
    │     └─ assetto/acServer (wrapper) ──exec──► assetto/acServer.real (ELF 32-bit, v1.15)
    │              │
    │              ├─ UDP+TCP 9600 (juego)
    │              └─ HTTP 8081   (API /INFO, solo local)
    │
    └─ /srv/assetto-corsa/
          ├─ assetto/{acServer,acServer.real,content,cfg,system,logs,results,...}
          ├─ config.yml            (config del Server Manager)
          ├─ data/                 (boltdb del SM)
          └─ entrypoint-wrapper.sh (entrypoint del contenedor)
```

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

## Server Manager v1.7.9

- Imagen `seejy/assetto-server-manager:latest` (módulo JustaPenguin), usuario `assetto` (uid 1000),
  `network_mode: host`, UI `:8772`, boltdb en `data/`.
- **Arranque de servidor**: NO existe API simple (`/api/start` → 404). Se hace desde la UI:
  - `GET /custom/load/{uuid}` → botón **Start** de una carrera guardada (redirige a `/live-timing`).
  - `POST /quick/submit` (`action=startRace`) o `POST /custom/new/submit` para carreras nuevas.
- Carreras guardadas actuales (2026-10-30):
  | UUID | Nombre |
  |---|---|
  | `9205601d-413c-400a-a477-52bf42c75469` | 🇩🇴 \| Another day of practice at Highlands |
  | `371cd0f4-3e56-416f-8e1f-235d2b9b336f` | 🇩🇴 \| BMW M235i at Zandvoort |
  | `765e6e8f-fd10-410f-86f0-0efbc0a5236f` | 🇩🇴 \| F1 2004 at Spa |
  | `fd8236dc-1871-41e7-90f4-c35b5b686308` | 🇩🇴 \| Another day of practice at Nürburgring GP |
- La carrera por defecto (`fd8236dc…`) corre **Practice 30 min**, 12 coches mixtos
  (BMW 1M/M3, Abarth 500, Alfa Giulietta) en Nürburgring GP.
- `config.yml`: `steam.username: "anonymous"` (el botón Install/Update de la UI fallará;
  el contenido se instala a mano) y `scan_content_folder_for_changes: false`
  (evita rescans que interrumpen el servidor en marcha).
- Credenciales del panel: `/srv/assetto-corsa/.sm-admin-credentials` (no imprimir).

## Puertos

| Puerto | Protocolo | Servicio | Acceso |
|--------|-----------|----------|--------|
| 8772 | TCP | Server Manager UI | Cloudflare Tunnel (`assetto.armada.do`) |
| 9600 | UDP + TCP | Juego Assetto Corsa | Internet (`srv00.assetto.armada.do`) |
| 8081 | TCP | HTTP API del juego (`/INFO`) | Solo local |

Firewall: reglas ACCEPT udp/tcp 9600 persistidas (iptables/nft, verificado 2026-10-30).

## Identidad actual

El nombre visible lo compone el SM: `La Vgz - Assetto Corsa - Republica Dominicana`
(config del SM) + nombre del evento (`🇩🇴 | Another day of practice at Nürburgring GP`).

| Elemento | Valor actual |
|---|---|
| Panel | https://assetto.armada.do |
| Nombre en `/INFO` | `La Vgz - Assetto Corsa - Republica Dominicana - 🇩🇴 \| Another day of practice at Nürburgring GP` |
| Pista | `ks_nurburgring` · layout `layout_gp_a` (GP) |
| Parrilla | 12 coches (entry list de la carrera guardada) |
| Sesión | Practice 30 min |
| Discord | https://discord.gg/6Sc5KAg3Sk |
| WhatsApp | https://chat.whatsapp.com/FUpozjvDAjLHeEFY7IJmxe |

Las zonas temáticas (Drift, Touge, Track Days, Race Events, Dominican Garage) siguen
como planificación de comunidad; se configuran creando carreras en el SM.

## Flujo de arranque (verificado)

```bash
# 1. (si el contenedor se reinició) esperar la UI ~35-45 s
ssh vps-preprod "docker ps --format '{{.Names}} {{.Status}}' | grep assetto"

# 2. Login al panel y Start de la carrera guardada
PW=$(ssh vps-preprod "awk -F': ' '/^Password:/{print \$2}' /srv/assetto-corsa/.sm-admin-credentials")
ssh vps-preprod "curl -s -c /tmp/smcj -o /dev/null --data-urlencode 'Username=admin' --data-urlencode 'Password=$PW' http://127.0.0.1:8772/login"
ssh vps-preprod "curl -s -b /tmp/smcj -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://127.0.0.1:8772/custom/load/fd8236dc-1871-41e7-90f4-c35b5b686308"

# 3. Verificación
ssh vps-preprod "docker exec assetto-corsa-server ps -ef | grep [a]cServer"
ssh vps-preprod "ss -lunp | grep 9600; curl -s http://127.0.0.1:8081/INFO | head -c 200"
```
La UI muestra **"Assetto Server Running"** cuando el proceso está vivo.

## Gotchas verificados en vivo (2026-10-30)

1. **El SM es el dueño del servidor**: no hay systemd. `docker restart assetto-corsa-server`
   mata el acServer; hay que volver a dar Start en la UI.
2. **Config real**: `content/config/server_cfg.ini` + `entry_list.ini`. `cfg/` son symlinks
   creados por el wrapper; editar `cfg/` no persiste.
3. **Layout de pista**: el binario usa `content/tracks/<track>/<CONFIG_TRACK>/data/...`
   con el nombre **literal** de la carpeta → para Nürburgring GP es `layout_gp_a`
   (no `gp_a`). Sin layout, no hay checksum de `surfaces.ini` y los clientes fallan.
4. **Lobby muerto**: con `REGISTER_TO_LOBBY=1` el server se apaga solo (404 tras 5 intentos).
5. **`[LAUNCHER]` y `[WEATHER_0]`**: sin ellas, panic al arrancar (el wrapper las garantiza).
6. **No hay skins**: el SM avisa "has no skins uploaded" y omite `SKIN=` (no es error).
7. **`CPU overload` en el log no es saturación del host**: los warnings (pasos de 100-400 ms)
   aparecen agrupados justo después de cada sondeo `GET /INFO` del SM (serializa el listado de
   178 coches). Con el servidor estable son ~1/min; no matan el proceso ni indican falta de CPU.
8. **Los mapas de pista del panel** (`ui/ui_track.json`, `data/map.ini`) no vienen en el
   paquete dedicado; se copiaron los `ui/` de las 21 pistas. El mapa SVG del live timing
   queda sin `data/map.ini` (cosmético).
9. **Credenciales débiles**: `ADMIN_PASSWORD` del juego y la del panel están en valor de
   setup; rotar (una se filtró en un output de diagnóstico).
10. **`docker exec … server-manager --version`** arranca una segunda instancia y cuelga:
   no usarlo (la versión se lee del CSS: `?cb=v1.7.9`).

## Fases

| Fase | Estado | Descripción |
|------|--------|-------------|
| 0 | ✅ | Estructura del proyecto + documentación |
| 0.5 | ✅ | Paquete oficial v1.15 restaurado (App 244210, depot Windows) |
| 0.6 | ✅ | Server Manager + Docker (`assetto-corsa-server`) |
| 0.7 | ✅ | Cloudflare Tunnel + DNS UDP (`srv00.assetto.armada.do`) |
| 0.8 | ✅ | Servidor AC vivo y controlado por el SM (2026-10-30) |
| 1 | ⏳ | Verificar join de un cliente real + ajustar carreras/zonas |
| 2 | ⏳ | Contenido adicional (tracks/cars) si la comunidad lo pide |
| 3 | ⏳ | Discord/Stracker |
| 4 | ⏳ | QA y deploy final |

## Pendientes conocidos

- **Join real de cliente** por `srv00.assetto.armada.do:9600` (checksums `data.acd`/pista).
- Rotar `ADMIN_PASSWORD` (juego) y la del panel.
- Auto-arranque tras reboot del VPS (hoy requiere Start manual en la UI).
- `ui_track.json`/`map.ini` del live timing (cosmético).

## Upstream References

- Server Manager: https://github.com/JustaPenguin/assetto-server-manager
- Docker Image: https://hub.docker.com/r/seejy/assetto-server-manager
- Content Manager: https://content-manager.net/
- Steam App (juego): https://store.steampowered.com/app/244210/

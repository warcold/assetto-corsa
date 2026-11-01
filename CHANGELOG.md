# CHANGELOG — Assetto Corsa Server

## 2026-11-01

### [04:00] - Restauración completa del servidor (pickup=True, estable 26+ min)
- **Tipo**: infra | restauración
- **Qué**: El servidor AC estaba caído (acServer no corría, puertos sin listener). Se restauró con:
  - Patcher config que corre cada 0.1s dentro del container
  - Entrypoint-wrapper que parchea config PERSISTENTMENTE antes de que el SM arranque
  - Docker-compose actualizado para montar el patcher en /tmp/config-patcher.sh
  - Cron autostart re-activado (cada 5 min, sin loops)
- **Verificado**: El servidor se mantiene estable por 26+ minutos con `pickup=True`
- **Config correcta**: `PICKUP_MODE=1, LOOP_MODE=1, WAIT_TIME=30, SESSION_START=30`
- **Estado**: ✅ Servidor RESTAURADO y estable

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
## 2026-11-02

### [00:10] - Fix: el servidor no respetaba la config del manager + autostart con UUID muerto
- **Tipo**: infra | fix
- **Qué**: el owner modificó sus custom races en la UI del SM y el server no reflejaba
  los cambios. Dos causas encontradas y corregidas:
  1. **Autostart con UUID muerto**: el cron apuntaba a `9205601d-...` (Highlands vieja,
     borrada al editar las races hoy 19:37-19:46). El UUID nuevo es `fd8236dc-...`.
     El cron no podía levantar nada → server caído.
  2. **El config-patcher pisaba el diseño de la carrera**: forzaba
     `PICKUP_MODE=1, LOOP_MODE=1, WAIT_TIME=30, SESSION_START=30` sobre CUALQUIER
     carrera, ignorando lo configurado en la UI del manager.
- **Fix**:
  - `config-patcher.sh` reducido a SOLO estabilidad (`REGISTER_TO_LOBBY=0`,
    `SLEEP_TIME=1`). El diseño de la carrera ahora lo decide exclusivamente la UI del SM.
  - `entrypoint-wrapper.sh` sin overrides de diseño (solo [LAUNCHER], [WEATHER_0],
    symlink y los 2 fixes de estabilidad).
  - `autostart-race.sh` con UUID nuevo `fd8236dc-1871-41e7-90f4-c35b5b686308`.
- **Verificado en vivo**: carrera "Another day of practice at Highlands" corriendo con
  la config del owner (14 cars custom, Highlands Long, Practice 30min, pickup=1,
  LOOP=0/WAIT=0 del SM sin pisar). acServer estable, 3 puertos arriba.
- **Nota**: con LOOP_MODE=0 (valor del owner en la UI), al terminar la Practice el
  server se detiene; el watchdog lo re-levanta en ≤5 min. Para loop infinito,
  activar "Loop" en la race desde la UI.

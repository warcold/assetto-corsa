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

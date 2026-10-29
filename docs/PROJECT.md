# Assetto Corsa Server — República Dominicana

## Visión General

Servidor de **Assetto Corsa** online para la comunidad de República Dominicana. El servidor ofrece:
- Carreras online con panel web (Server Manager)
- Modo Championship con puntos de clasificación
- Race Weekends (sesiones secuenciales)
- Contenido modular (tracks, cars, Sol Weather)
- Integración con Discord y Stracker para stats

**Dominio público**: `assetto.armada.do` (vía Cloudflare Tunnel en vps-preprod)

## Estructura del Proyecto

```
~/dev/games/assetto-corsa/
├── docs/
│   ├── PROJECT.md        ← este archivo
│   ├── CHANGELOG.md      ← historial de cambios
│   └── config/           ← ejemplos de config
│       ├── servermanager.example.yml
│       └── contentmanager.example.ini
├── scripts/
│   ├── install.sh        ← script de instalación
│   ├── deploy.sh         ← despliega al VPS
│   └── backup.sh         ← backup del servidor
└── harness/
    └── assetto.harness.json  ← harness JSON para kalimete
```

## Requisitos

### Obligatorios
1. **Steam License** — Assetto Corsa app ID 244210 (~$15 USD). Sin license → no se puede instalar.
2. **VPS preprod** — 154.53.35.102 (107GB disco libre, 7.8GB RAM)
3. **Docker** — para correr Server Manager
4. **Cloudflare Tunnel** — para exposing el servidor (assetto.armada.do)

### Recomendados
- **Sol Weather** — mod de clima avanzado con day/night cycle
- **Stracker** — plugin para tracking de carreras
- **Discord Integration** — notificaciones automáticas al canal de Discord

## Puertos del Servidor

| Puerto | Protocolo | Servicio | Acceso |
|--------|-----------|----------|--------|
| 8772 | TCP | Server Manager UI | assetto.armada.do:8772 (Cloudflare) |
| 9600-9601 | UDP | Assetto Corsa Game | assetto.armada.do (Cloudflare Tunnel) |
| 8081 | TCP | Assetto HTTP API | localhost (no expuesto) |
| 27015-27017 | TCP/UDP | SteamCMD | localhost (no expuesto) |

## Arquitectura

```
Player (Steam)
    ↓ (TCP/UDP)
assetto.armada.do
    ↓ Cloudflare Tunnel
vps-preprod:8772 → Server Manager (Go web UI)
    ↓ (gestiona)
Assetto Corsa Server (steam_app_244210)
    ↓ (UDP)
9600/9601 → Clientes
```

## Fases de Desarrollo

| Fase | Estado | Descripción |
|------|--------|-------------|
| 0 | ✅ | Estructura del proyecto + documentación |
| 0.5 | ⚠️ | Instalar SteamCMD + AC (bloqueado: requiere license) |
| 0.6 | | Instalar Server Manager + Docker |
| 0.7 | | Configurar Cloudflare Tunnel |
| 1 | | Configurar carreras y championships |
| 2 | | Añadir tracks, cars y Sol Weather |
| 3 | | Integrar Discord + Stracker |
| 4 | | QA y deploy final |

## Comandos Rápidos

```bash
# Ver estado del proyecto
git -C ~/dev/games/assetto-corsa log --oneline -5

# Ver estado del servidor (en VPS)
ssh vps-preprod "systemctl status assetto-server"

# Ver logs del servidor
ssh vps-preprod "journalctl -u assetto-server --no-pager -n 50"

# Reiniciar el servidor
ssh vps-preprod "systemctl restart assetto-server"

# Acceder al panel web
open http://assetto.armada.do:8772
```

## Notas Importantes

1. **No hay ambiente preprod**: el servidor corre directo en producción (vps-preprod).
2. **Steam license es obligatoria**: no se puede bypass. Opción: comprar el juego en Steam o usar una cuenta existente.
3. **Repo archivado**: `JustaPenguin/assetto-server-manager` fue archivado en Aug 2026, pero los releases y Docker image siguen funcionales.
4. **Backup obligatorio**: antes de cualquier cambio, hacer backup de la DB de Server Manager.

## Upstream References

- Server Manager: https://github.com/JustaPenguin/assetto-server-manager
- Docker Image: https://hub.docker.com/r/seejy/assetto-server-manager
- Content Manager: https://content-manager.net/
- Sol Weather: https://assettocorsa.net/threads/sol-weather.46499/

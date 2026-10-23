# Ágora Joven

App Flutter para **comprender temas públicos**, **consultar debates ciudadanos** y **publicar
preguntas, argumentos o propuestas**, con un backend propio en FastAPI.

> **Estado: Bloque 0 (base del proyecto).** Hoy solo existen la pantalla inicial con estado de
> arranque en GetX y el endpoint `GET /health`. Autenticación, debates, aportes, guardados y
> asistente están **planificados, no implementados**. Ver [docs/SEGUIMIENTO.md](docs/SEGUIMIENTO.md).

## Estructura

```
agora-joven/
├── app/        App Flutter (Android)
├── backend/    API FastAPI + Docker Compose
├── docs/       ALCANCE.md · ARQUITECTURA.md · SEGUIMIENTO.md
├── AGENTS.md   Reglas para agentes de código (CLAUDE.md lo importa)
└── README.md
```

## Requisitos

| Herramienta | Versión comprobada |
|---|---|
| Flutter / Dart | 3.47.5 / 3.13.4 (canal stable) |
| Python local (solo para `.venv` y pytest) | 3.11.9 |
| Python del contenedor | 3.12 (`python:3.12-slim`; comprobado 3.12.15) |
| Docker / Compose | 29.8.2 / v5.6.0 (Docker Desktop debe estar en ejecución) |
| Android | Emulador o dispositivo para ejecutar la app |

## Backend

### Con Docker Compose (recomendado)

```bash
cd backend
docker compose up --build -d api
docker compose ps                     # agora-joven-api debe aparecer como (healthy)
curl http://localhost:8010/health
# {"status":"ok","servicio":"agora-joven-api"}
docker compose down                   # detiene solo el servicio de este proyecto
```

En PowerShell, si `curl` no devuelve el JSON, usa `curl.exe` o
`Invoke-RestMethod http://localhost:8010/health`.

El puerto del host es `8010` por defecto (variable `API_PORT`, ver `backend/.env.example`) para
no chocar con otros backends del curso en `8000`.

### Sin Docker (Windows, PowerShell)

Entorno de desarrollo con Python 3.11 local; no reemplaza la comprobación del contenedor (3.12).

```powershell
cd backend
py -3.11 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m uvicorn app.main:app --host 127.0.0.1 --port 8010
# En otra terminal:
curl.exe http://127.0.0.1:8010/health
```

Usa este modo o Docker, no ambos a la vez: los dos ocupan el puerto 8010.

Pruebas del backend:

```powershell
cd backend
.venv\Scripts\python -m pytest -q
```

## App

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run          # con un emulador Android abierto
```

Direcciones del backend por entorno (se usarán desde el Bloque 3):

| Entorno | URL base |
|---|---|
| Emulador Android | `http://10.0.2.2:8010` |
| Dispositivo físico en la misma red | `http://<IP-del-PC>:8010` |

## Arquitectura

Pantalla (`screens/`) → controlador GetX (`controllers/`) → repositorio (`repositories/`) →
fuente de datos (`data/`). Detalle, modelos y contrato de endpoints en
[docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

## Seguridad

- No hay claves en el repositorio. `.env` está ignorado; solo se versiona `.env.example`.
- El token de sesión se guardará con `flutter_secure_storage` (previsto).
- Asistente con Gemini a través del backend propio; la clave vivirá únicamente en el `.env` del
  servidor (previsto). No se envían correos, credenciales ni tokens al proveedor.
- `AGENTS.md` y `.claude/settings.json` guían a los agentes de código, pero no son una barrera
  técnica absoluta; ver sus límites en [AGENTS.md](AGENTS.md#límites-conocidos-de-los-permisos).

## Créditos y licencias

- Contenido de debates: material editorial de demostración elaborado para este proyecto (previsto).
- Paquetes: Flutter (BSD-3), GetX `get` (MIT), FastAPI (MIT), Uvicorn (BSD-3).

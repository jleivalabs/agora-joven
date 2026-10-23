# Seguimiento — Ágora Joven

Leyenda: ✅ comprobado con evidencia · ⏳ pendiente · ⛔ bloqueado

## Bloques

| Bloque | Contenido | Estado |
|---|---|---|
| 0 | Base: repositorio, app mínima con GetX, `/health`, Docker Compose, documentación | ✅ Comprobado; pendiente del primer commit |
| 1 | Backend: SQLite, usuarios, JWT (`/auth/*`) y pruebas | ⏳ |
| 2 | Backend: debates (20 en semilla) y aportes con propiedad comprobada | ⏳ |
| 3 | App: sesión (login, registro, logout, token seguro, número de sesión) | ⏳ |
| 4 | App: lista por categorías y detalle con estados de carga/vacío/error | ⏳ |
| 5 | App: aportes (crear, editar, eliminar propios) | ⏳ |
| 6 | App: debates guardados con Hive | ⏳ |
| 7 | Asistente: endpoint del backend y pantalla en la app | ⏳ |
| 8 | CI, workflow de Release, README final, auditoría de secretos | ⏳ |

## Bloque 0 — comprobaciones (2026-10-22)

| Comprobación | Resultado |
|---|---|
| `flutter analyze` (app/) | ✅ No issues found |
| `flutter test` (app/) | ✅ 3 pruebas pasan (bienvenida, carga, error con reintento) |
| `pytest` (backend/) | ✅ 1 prueba pasa (`GET /health`) |
| `uvicorn` local + `GET /health` en 127.0.0.1:8010 | ✅ HTTP 200 `{"status":"ok","servicio":"agora-joven-api"}` |
| `docker compose config` (backend/) | ✅ Configuración válida |
| `docker compose up` real (primer intento) | ⛔ Docker Desktop no estaba en ejecución |
| `docker compose up --build -d api` (segundo intento) | ✅ Imagen `agora-joven-api:dev` construida; contenedor `agora-joven-api` *healthy* |
| `GET http://localhost:8010/health` contra el contenedor | ✅ HTTP 200 `{"status":"ok","servicio":"agora-joven-api"}` |
| Python y paquetes dentro del contenedor | ✅ Python 3.12.15; FastAPI 0.142.2, Starlette 1.7.0, Pydantic 2.13.5, Uvicorn 0.54.0; usuario no root `agora` |
| App en emulador (`flutter run` en `emulator-5554`) | ✅ **Realizada por la persona autora**, no por el agente: compilación e instalación correctas; captura con la bienvenida y las tarjetas Comprende, Consulta y Participa, sin pantalla roja ni desbordamientos visibles |
| `git diff --check` (archivos nuevos, vía `--no-index`) | ✅ Sin errores de espacios; `.gitattributes` fija LF |
| Búsqueda de patrones de claves | ✅ Sin coincidencias |

Salvo la fila del emulador, las comprobaciones las ejecutó el agente y su salida quedó registrada
en la sesión.

**Qué no se comprobó en el Bloque 0** (no existe todavía): navegación entre pantallas, integración
app-backend, autenticación, debates, aportes, guardados y asistente. La prueba en emulador solo
cubre el arranque y la pantalla de bienvenida.

## Pendientes conocidos

- Primer commit del Bloque 0 (lo decide la persona autora).
- Versión de Python: local 3.11.9 (no hay 3.12 instalado) para `.venv` y pytest; el contenedor
  usa 3.12.15. Las pruebas locales no sustituyen la validación del contenedor.

## Decisiones registradas (2026-10-22)

- Se mantiene `flutter_lints ^6.0.0`.
- Debates y aportes requieren sesión; públicos solo `/health`, `/auth/registro`, `/auth/login`.
- IA: Gemini vía backend propio, clave solo en el servidor, sin modo de demostración.

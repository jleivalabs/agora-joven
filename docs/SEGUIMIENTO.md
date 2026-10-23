# Seguimiento — Ágora Joven

Leyenda: ✅ comprobado con evidencia · ⏳ pendiente · ⛔ bloqueado

## Bloques

| Bloque | Contenido | Estado |
|---|---|---|
| 0 | Base: repositorio, app mínima con GetX, `/health`, Docker Compose, documentación | ✅ Comprobado; commit `5a8611d` |
| 1 | Backend: SQLite, autenticación JWT y catálogo de 20 debates | ✅ Comprobado (pruebas y Docker con volumen); pendiente de commit |
| 2 | Backend: aportes con propiedad comprobada en el servidor | ⏳ |
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

- Commit del Bloque 0 registrado: `5a8611d`.
- Commit del Bloque 1 (lo decide la persona autora).
- Versión de Python: local 3.11.9 (no hay 3.12 instalado) para `.venv` y pytest; el contenedor
  usa 3.12.15. Las pruebas locales no sustituyen la validación del contenedor.

## Bloque 1 — autenticación y catálogo (2026-10-22)

### Pruebas automáticas (ejecutadas por el agente)

`backend/.venv` (Python 3.11.9), `python -m pytest -q` → **41 passed**. Base SQLite temporal por
prueba y secreto sintético generado en cada ejecución; no usan `.env`.

| Archivo | Cubre |
|---|---|
| `test_auth.py` | Registro correcto (sin contraseña ni hash en la respuesta, correo normalizado); correo duplicado aunque cambien mayúsculas (400); datos inválidos (422); hash Argon2id en la base; índice único de correo; login válido (HS256, `expira_en`) e inválido (401 genérico); `/auth/me` con token válido, ausente, mal formado, otro esquema, firma alterada, otro secreto, `alg: none`, caducado y usuario inexistente; configuración sin secreto o con secreto corto falla; usuario persiste al reabrir la base |
| `test_debates.py` | Las tres rutas del catálogo exigen token (401); 20 debates en orden estable con origen editorial; filtro por categoría; categoría inválida (422); categorías en orden fijo con totales; detalle con contexto y ≥2 perspectivas; inexistente (404); id no numérico (422) |
| `test_catalogo.py` | Archivo editorial válido (20, origen, perspectivas); carga idempotente sin tocar usuarios; actualización editorial sin duplicar; catálogo y usuarios persisten al reabrir; `PRAGMA foreign_keys = 1` |
| `test_health.py` | `GET /health` 200 |

### Comprobaciones manuales (ejecutadas por el agente)

| Comprobación | Resultado |
|---|---|
| `docker compose config --quiet` sin `JWT_SECRET` | ✅ Falla como se espera: `required variable JWT_SECRET is missing a value` |
| `docker compose config --quiet` con secreto sintético solo en el proceso | ✅ Configuración válida |
| `docker build -t agora-joven-api:dev .` | ✅ Imagen construida |
| Contenedor efímero aislado `agora-joven-prueba-b1` (puerto 8019, sin volumen, secreto sintético) | ✅ Python 3.12.15, usuario `agora`; `/health` 200; `/debates` sin token 401; registro 201; `/auth/me` 200; 20 debates; `/debates/999` 404; `agora.db` creado por `agora` en `/srv/data`. Contenedor detenido y eliminado |
| Registros de ese contenedor | ✅ 0 coincidencias de `authorization`, `bearer` o `eyJ`; solo método, ruta y código |

### Persistencia real con el servicio del proyecto (ejecutada por el agente)

`backend/.env` preparado por la persona autora; el agente solo comprobó que existe, sin leerlo,
mostrarlo ni modificarlo. No se imprimió la configuración resuelta ni el entorno del contenedor.

Puerto 8010 antes de actualizar: `com.docker.backend` (puerto publicado por Docker) y `wslrelay`
(reenvío de `localhost` IPv6 de WSL2 usado por Docker Desktop). Ambos de Docker; no se detuvo nada.

| Paso | Resultado |
|---|---|
| `docker compose up --build -d api` | ✅ Imagen reconstruida; volumen `agora-joven_agora_datos` creado; `agora-joven-api` recreado y *healthy* |
| `GET /health` | ✅ 200 |
| `GET /debates` sin token | ✅ 401 |
| Registro de una cuenta de prueba generada (`@example.com`, contraseña aleatoria en memoria) | ✅ 201, sin contraseña ni hash en la respuesta |
| Login y `GET /auth/me` | ✅ 200; `/auth/me` devuelve el id (1) y el correo de esa cuenta |
| `GET /debates` | ✅ 20 debates |
| `docker compose up -d --force-recreate api` | ✅ *healthy* de nuevo en ~12 s |
| Login con la misma cuenta, sin registrarla otra vez | ✅ 200; mismo id (1) |
| `GET /debates` tras recrear | ✅ 20 debates, mismos ids |
| `docker compose exec -T api python -m app.catalogo` | ✅ `0 insertados, 0 actualizados, 20 en total`; la API sigue con 20 debates y la cuenta intacta |
| Base en el volumen | ✅ `/srv/data/agora.db` propiedad de `agora` (no root) |
| Registros del contenedor | ✅ 0 coincidencias de `authorization`, `bearer`, `eyJ` o `password` |

No se usó `down -v` ni se borró el volumen. La cuenta de prueba queda en la base del volumen; la
contraseña no se guardó en ningún archivo, así que esa cuenta no se puede volver a usar.

## Decisiones registradas (2026-10-22)

- Se mantiene `flutter_lints ^6.0.0`.
- Debates y aportes requieren sesión; públicos solo `/health`, `/auth/registro`, `/auth/login`.
- IA: Gemini vía backend propio, clave solo en el servidor, sin modo de demostración.
- Bloque 1: tablas con `create_all` (sin Alembic); orden del catálogo por `id`; correo duplicado
  → 400 explícito; arranque con `uvicorn app.main:create_app --factory`.

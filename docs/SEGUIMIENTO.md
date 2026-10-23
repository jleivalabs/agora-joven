# Seguimiento — Ágora Joven

Leyenda: ✅ comprobado con evidencia · ⏳ pendiente · ⛔ bloqueado

## Bloques

| Bloque | Contenido | Estado |
|---|---|---|
| 0 | Base: repositorio, app mínima con GetX, `/health`, Docker Compose, documentación | ✅ Commit `5a8611d` |
| 1 | Backend: SQLite, autenticación JWT y catálogo de 20 debates | ✅ Commit `4238dd5` |
| 2 | App: sesión (registro, acceso, restauración, cierre) y catálogo con filtro y detalle | ✅ Comprobado (43 pruebas automáticas y recorrido manual en emulador); pendiente de commit y push |
| 3 | Aportes: backend con propiedad comprobada y pantallas en la app | ⏳ |
| 4 | Debates guardados con Hive | ⏳ |
| 5 | Asistente con Gemini: endpoint del backend y pantalla en la app | ⏳ |
| 6 | CI, workflow de Release, README final, auditoría de secretos | ⏳ |

La numeración de los bloques 2 a 6 se ajustó al plan de trabajo vigente: el Bloque 2 pasó a ser
la sesión y el catálogo en la app.

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

- Commits registrados: Bloque 0 `5a8611d`, Bloque 1 `4238dd5`.
- Bloque 2: commit y push (los hace la persona autora).
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

## Bloque 2 — sesión y catálogo en la app (2026-10-22)

Paquetes añadidos (versiones de ExploraEC, fijadas exactas): `dio` 5.11.1 y
`flutter_secure_storage` 11.2.0. Se eliminaron `ArranqueController`, `InicioScreen` y su prueba:
la restauración de sesión sustituye al arranque del Bloque 0. El backend no se modificó, así que
no se repitieron sus 41 pruebas.

### Pruebas automáticas (ejecutadas por el agente)

`flutter analyze` → **No issues found**. `flutter test --timeout 30s` → **43 passed** (unos 2 s).
Sin backend real: servidor falso conectado como adaptador de Dio (la app usa su `ApiClient` real)
y almacén de token en memoria con fallo de escritura simulable.

| Archivo | Pruebas | Cubre |
|---|---|---|
| `api_client_test.dart` | 4 | 400, 401, 403, 404, 422 y 5xx clasificados, con mensajes distintos y sin mostrar el detalle del servidor; desconexión frente a tiempo agotado; cabecera Bearer solo cuando hay token; respuesta con forma inesperada |
| `sesion_controller_test.dart` | 18 | Restauración sin token, válida, caducada (borra el token), con fallo de red o 5xx (conserva el token) y reintento; restauración pendiente que no reactiva tras cerrar; login válido, inválido (mensaje propio, sin aviso de caducidad), tiempo agotado, fallo al guardar el token, envíos duplicados y login pendiente invalidado; registro correcto, duplicado (400) y 422 con campos; cierre de sesión; 401 de una sesión anterior que no cierra la actual; varios 401 simultáneos con un único cierre |
| `debates_controller_test.dart` | 7 | 20 debates y categorías; filtro y vuelta a Todas; categoría vacía; respuestas de filtros fuera de orden; error 500 y reintento; 401 durante la carga; detalle completo y 404 |
| `app_flujo_test.dart` | 14 | Flujos con la app completa: acceso, credenciales inválidas, mostrar contraseña, login y saludo, registro con aviso y correo escrito, duplicado, filtro, detalle y vuelta, vacío, error con reintento, detalle inexistente, restauración con fallo de red, token caducado al abrir, caducidad en el detalle, cierre de sesión y botón Atrás |

Dos ajustes durante las pruebas, ambos en las pruebas y no en la app: inicializar el binding de
Flutter en las pruebas unitarias (`Get.key` lo necesita) y desplazar la fila horizontal de chips
antes de pulsar los que quedan fuera de la vista.

### Comprobaciones estáticas (agente)

- `lib/screens` y `lib/controllers` no importan Dio ni `flutter_secure_storage`.
- `setState` solo para mostrar u ocultar la contraseña (estado local del formulario).
- `lib/` no contiene `print`, `debugPrint` ni `LogInterceptor`.

### Comprobación manual en emulador (realizada por la persona autora, no por el agente)

Recorrido en `emulator-5554` contra el backend real en Docker (puerto 8010). La persona autora
confirmó correcto el recorrido funcional; el agente no ejecutó la app en el emulador ni compiló el
APK. No se registran correos, contraseñas ni tokens usados.

| Comprobación | Resultado aportado |
|---|---|
| Backend *healthy* y `GET /health` | ✅ Respuesta correcta |
| Compilación e instalación del APK de depuración | ✅ Correctas (incluye el manifiesto con `INTERNET`, `networkSecurityConfig` y `dataExtractionRules`) |
| Registro e inicio de sesión | ✅ |
| Mensajes de correo duplicado y de credenciales incorrectas | ✅ |
| Catálogo, filtro Educación (3 debates) y regreso a Todas | ✅ |
| Detalle con contexto, perspectivas y aviso editorial | ✅ |
| Restauración de sesión tras `am force-stop` y apertura desde el icono | ✅ |
| Backend detenido (`docker compose stop api`) | ✅ Aparece el error con "Reintentar"; la captura corresponde al **detalle de un debate** |
| Backend iniciado (`docker compose start api`) y reintento | ✅ Recupera la conexión |
| Cierre de sesión, retorno al acceso y botón Atrás | ✅ |

**Sin comprobación manual** (solo cobertura automática, ver tabla anterior): caducidad o
invalidez del token, 401 de una sesión anterior, varios 401 simultáneos, respuestas tardías de
login, restauración o filtros, y fallo al guardar el token.

## Decisiones registradas (2026-10-22)

- Se mantiene `flutter_lints ^6.0.0`.
- Debates y aportes requieren sesión; públicos solo `/health`, `/auth/registro`, `/auth/login`.
- IA: Gemini vía backend propio, clave solo en el servidor, sin modo de demostración.
- Bloque 1: tablas con `create_all` (sin Alembic); orden del catálogo por `id`; correo duplicado
  → 400 explícito; arranque con `uvicorn app.main:create_app --factory`.

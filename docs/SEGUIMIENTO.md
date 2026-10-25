# Seguimiento — Ágora Joven

Leyenda: ✅ comprobado con evidencia · ⏳ pendiente · ⛔ bloqueado

## Estado actual (24/10/2026)

- Último commit publicado: `5df1279` (Bloque 4, en `origin/main`).
- Bloque 5 (asistente con Gemini) **comprobado**: pruebas reales y comprobación visual del Markdown
  en emulator-5554 por la persona autora; pruebas automáticas del agente en verde. Pendiente:
  revisión, commit y push.
- Se mantiene el pendiente técnico conocido de Hive (ver "Bloque 4 → Revisión del fallo de disco").
- No comenzar el Bloque 6.

## Bloques

| Bloque | Contenido | Estado |
|---|---|---|
| 0 | Base: repositorio, app mínima con GetX, `/health`, Docker Compose, documentación | ✅ Commit `5a8611d` |
| 1 | Backend: SQLite, autenticación JWT y catálogo de 20 debates | ✅ Commit `4238dd5` |
| 2 | App: sesión (registro, acceso, restauración, cierre) y catálogo con filtro y detalle | ✅ Commit `285f020`, publicado en `origin/main` |
| 3 | Aportes: backend con propiedad comprobada y pantallas en la app | ✅ Commit `317cf23`, publicado en `origin/main` |
| 4 | Debates guardados con Hive | ✅ Commit `5df1279`, publicado en `origin/main` (con el pendiente técnico de Hive documentado) |
| 5 | Asistente con Gemini: endpoint del backend y pantalla en la app | ✅ Comprobado (Gemini real y Markdown en emulador; pruebas automáticas en verde); pendiente de revisión, commit y push |
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

- Commits registrados: Bloque 0 `5a8611d`, Bloque 1 `4238dd5`, Bloque 2 `285f020`, Bloque 3
  `317cf23`, Bloque 4 `5df1279` (publicados en `origin/main`).
- Bloque 5: revisión, commit y push (persona autora).
- Pendiente técnico conocido: excepción asíncrona no capturada de Hive (Bloque 4).
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

## Bloque 3 — aportes compartidos (2026-10-22)

Sin dependencias nuevas. Backend: modelo `Aporte` con claves foráneas a `usuarios` y `debates`,
esquemas con `extra="forbid"`, repositorio y rutas. App: modelo, `AportesRepository`,
`AportesController`, sección en el detalle y `AporteFormScreen`; `ApiClient` gana `patch` y
`delete`.

### Pruebas automáticas (ejecutadas por el agente)

| Suite | Resultado |
|---|---|
| Backend `pytest -q` (Python 3.11 local, base temporal) | **68 passed** (41 anteriores + 27 de `test_aportes.py`) |
| `flutter analyze` | **No issues found** |
| `flutter test --timeout 30s` | **72 passed** (43 anteriores + 18 de `aportes_controller_test.dart` + 11 de `aportes_flujo_test.dart`) |

Backend (`test_aportes.py`): A crea y B ve el mismo aporte con `es_propio` correcto; B recibe 403
al editar y al eliminar y el contenido queda intacto; A edita parcialmente (solo tipo, solo texto)
y elimina (204 sin cuerpo); PATCH sin cambios reales no marca edición; `autor_id`, `debate_id`,
`id` y `es_propio` en el cuerpo → 422; 401 sin token o con token inválido en las cuatro rutas;
404 de debate y de aporte; tipo inválido, texto corto, corto tras quitar espacios, más de 1000,
campos ausentes o nulos → 422; límites 10 y 1000 tras recortar; PATCH vacío, nulo, inválido o con
campos extra → 422 sin cambios; orden más recientes primero, estable entre usuarios y con
desempate por id; respuestas sin correo, contraseña, hash, `autor_id` ni tokens; persistencia al
reabrir la base; claves foráneas que rechazan aportes huérfanos.

Flutter (servidor falso con dos usuarios y almacén simulado): lista vacía, propios y ajenos,
error y reintento, carga antigua que no pisa a la reciente; publicar sin duplicar al actualizar,
envíos duplicados ignorados, sin red al publicar (aviso de que pudo guardarse y sin reintento),
editar enviando solo lo cambiado, editar sin cambios sin petición, 403 y 404 al editar; eliminar
solo tras confirmación del servidor, 403 y sin red sin retirar, 404 que retira; publicación
tardía tras cambiar de sesión, 401 tardío de la sesión anterior, respuestas tras cerrar el
detalle, debates distintos sin mezclarse. Flujos con widgets: vacío y publicación, validación
local sin petición, Editar/Eliminar solo en propios, edición con "Editado", error al guardar que
conserva texto y formulario, confirmar y cancelar eliminación, 403 al eliminar, fallo de carga
de aportes que mantiene el contexto, actualización con aportes de otra persona, salida del detalle
con carga pendiente y sesión que caduca al publicar.

Ajuste durante las pruebas (en la prueba, no en la app): con una carga de aportes pendiente,
`pumpAndSettle` no termina porque el indicador gira; esa prueba avanza los fotogramas a mano.

### Docker (ejecutado por el agente)

| Paso | Resultado |
|---|---|
| Antes de actualizar (recuento, sin leer contenido) | Tablas `debates`, `usuarios`; 20 debates, 2 usuarios |
| `docker compose up --build -d api` | ✅ Contenedor recreado y *healthy*; volumen `agora-joven_agora_datos` conservado |
| Después de actualizar | ✅ Tablas `aportes`, `debates`, `usuarios`; 20 debates, 2 usuarios, 0 aportes |
| Claves foráneas de `aportes` | ✅ `autor_id → usuarios.id`, `debate_id → debates.id` |
| `/health` · aportes sin token (GET, POST, PATCH, DELETE) | ✅ 200 · 401 en las cuatro |
| Rutas publicadas (OpenAPI) | ✅ `/debates/{debate_id}/aportes`, `/aportes/{aporte_id}` |

El agente no creó, modificó ni borró cuentas o contenido del volumen real.

### Comprobación manual en emulador (realizada por la persona autora, no por el agente)

**Confirmación general de la persona autora:** las pruebas funcionales de aportes en el emulador
fueron satisfactorias.

**Observado en las capturas aportadas:**

| Comprobación | Resultado |
|---|---|
| Publicación de aportes | ✅ |
| Lectura de un aporte desde otra cuenta | ✅ |
| Editar y Eliminar visibles solo en aportes propios | ✅ |
| Diálogo de confirmación al eliminar | ✅ |
| El aporte ajeno se conserva | ✅ |

No se registran aquí otras evidencias específicas (por ejemplo, el 403 real con dos tokens o el
comportamiento con el backend detenido) más allá de la confirmación general. La incidencia del
menú flotante del teclado del emulador se resolvió cambiando la configuración del teclado del
emulador, sin cambios en la aplicación.

## Bloque 4 — debates guardados con Hive (2026-10-23)

Dependencias añadidas, con las versiones de ExploraEC fijadas exactas: `hive` 2.2.3 y
`hive_flutter` 1.1.0. Entra además `path_provider` 2.1.6 como dependencia transitiva. El
`pubspec.lock` solo añadió entradas: no cambió ninguna otra versión. Backend sin cambios (no se
repitieron sus 68 pruebas).

Archivos nuevos: `models/debate_guardado.dart`, `data/guardados_local.dart`,
`repositories/guardados_repository.dart`, `controllers/guardados_controller.dart`,
`screens/guardados_screen.dart`. Modificados: `main.dart` (inicializa Hive), `app.dart`
(inyección), `detalle_debate_screen.dart` (marcador), `debates_screen.dart` (acceso a Guardados).

### Pruebas automáticas (ejecutadas por el agente)

`flutter analyze` → **No issues found**. `flutter test --timeout 30s` → **92 passed** (72
anteriores + 20 nuevas). Las pruebas de widgets existentes ahora inyectan un almacén de
guardados en memoria.

| Archivo | Pruebas | Cubre |
|---|---|---|
| `guardados_hive_test.dart` | 6 | **Hive real** en un directorio temporal: persistencia tras cerrar y reabrir Hive, una caja por cuenta, sin duplicados, quitar persiste, solo campos editoriales mínimos, registro dañado omitido sin borrarlo |
| `guardados_controller_test.dart` | 9 | Sin sesión no se guarda; guardar, duplicados y quitar; fallo de escritura (no se marca), fallo al quitar (se mantiene), fallo de lectura con reintento sin borrar datos; aislamiento entre cuentas y conservación tras cerrar sesión; guardado y lectura pendientes de la cuenta A que no afectan a la cuenta B; guardado que termina durante una lectura no se pierde |
| `guardados_flujo_test.dart` | 5 | Guardar desde el detalle, verlo en Guardados, abrirlo y quitarlo; fallo de escritura sin marcar; lista legible con el backend caído y detalle con error y Reintentar; error de lectura con reintento; cambio de cuenta con lista vacía para la nueva |

Durante el trabajo se retiró una prueba que provocaba un fallo real del sistema de archivos:
Hive lanza una excepción interna asíncrona fuera de la llamada (la envoltura sí devolvió el error
tipado). Los errores de almacenamiento quedan cubiertos con el almacén simulado.

Comprobación estática: ninguna pantalla ni controlador importa Hive (solo `data/` y `main.dart`).

### Comprobación manual en emulator-5554 (24/10/2026, persona autora, no el agente)

**Confirmación de la persona autora:** completó satisfactoriamente el recorrido manual:

| Comprobación | Resultado confirmado |
|---|---|
| Guardar, listar y abrir un debate | ✅ |
| Persistencia tras cierre completo y reapertura | ✅ |
| Separación de guardados entre dos cuentas (Jleiva y patu) | ✅ |
| Lista local disponible con el backend detenido; error al abrir el detalle y recuperación con Reintentar tras arrancarlo | ✅ |
| Quitar un guardado y comprobar que sigue eliminado tras cerrar y reabrir | ✅ |

**Observado en las capturas aportadas:** debate guardado, listado de Guardados, detalle abierto,
segunda cuenta con la lista vacía, otro debate guardado en esa cuenta y eliminación. Lo demás
(cierre completo, backend detenido, persistencia de la eliminación) consta por la confirmación de
la persona autora, no por capturas.

### Revisión del fallo de disco de Hive (24/10/2026, agente)

Reproducción acotada con una prueba temporal, ya borrada, sobre un directorio temporal aislado (sin
tocar datos de la app ni del emulador), en el entorno de pruebas de Flutter en Windows.

**Condición provocada:** `Hive.init` recibió como ruta un **archivo existente** en lugar de un
directorio. Al abrir la caja, Hive intentó crear el directorio en esa ruta y el sistema respondió
que ya existía un archivo con ese nombre (`PathExistsException`, errno 183).

**Observado en esa reproducción:**

- Nuestra capa (`HiveAlmacenGuardados`) devolvió un **error controlado** (`ErrorAlmacenLocal`) en
  `leer`, `guardar`, `quitar` y un segundo `leer`; con ese error la app muestra un mensaje y no
  marca nada como guardado.
- **Además**, cada una de esas cuatro operaciones produjo una `PathExistsException` **asíncrona no
  capturada** por nuestro `try/catch`, detectada con un `runZonedGuarded` alrededor de la prueba.
  La traza no permitió localizar en qué punto de Hive se origina.
- Tras volver a inicializar Hive con un directorio válido en el mismo proceso, guardar y leer
  funcionaron.

**Alcance de la conclusión:** solo cubre esa condición concreta. No se probaron otros fallos de
almacenamiento (disco lleno, permisos, archivos de caja dañados…) ni se descarta que la excepción
pueda capturarse con otro tratamiento. **Su efecto en Android no se verificó**: no se reprodujo en
emulador ni en dispositivo. Las pruebas automáticas de errores del Bloque 4 usan un almacén
simulado, que no reproduce este comportamiento de Hive.

**Pendiente técnico conocido:** excepción asíncrona no capturada de Hive cuando la apertura de una
caja falla por la condición anterior. El Bloque 4 **no** debe considerarse tolerante a cualquier
fallo de almacenamiento. No se cambió código ni se añadió un manejador global; la decisión sobre su
tratamiento queda abierta.

## Bloque 5 — asistente educativo con Gemini (24/10/2026)

Sin dependencias nuevas ni actualizadas (backend: `urllib` de la biblioteca estándar; app: paquetes
existentes). Modelo por defecto `gemini-3.5-flash-lite`, elegido con la documentación oficial de
ai.google.dev consultada el 24/10/2026 (ver `docs/ARQUITECTURA.md → Asistente`).

Backend nuevo: `app/ia.py`, `app/asistente.py`, `app/routers/asistente.py`; modificados
`config.py` (variables `GEMINI_*` opcionales), `schemas.py`, `main.py` (versión 0.5.0),
`.env.example` y `docker-compose.yml` (variables de ejemplo, sin secretos). App nueva:
`models/asistente.dart`, `repositories/asistente_repository.dart`,
`controllers/asistente_controller.dart`, `screens/seccion_asistente.dart`; modificados
`api_client.dart` (espera ampliada por petición), `api_exception.dart` (429), `app_config.dart`,
`detalle_debate_screen.dart` y `app.dart`.

### Pruebas automáticas con proveedor SIMULADO (agente)

Ninguna prueba llamó a Gemini ni a la red real.

| Suite | Resultado |
|---|---|
| Backend `pytest -q` | **102 passed** (68 anteriores + 34 de `test_asistente.py`) |
| `flutter analyze` | **No issues found** |
| `flutter test --timeout 30s` | **107 passed** (92 anteriores + 9 de `asistente_controller_test.dart` + 6 de `asistente_flujo_test.dart`) |

Backend: 401 sin token o con token inválido; 422 con acción ausente, inválida, nula o con campos
extra; 404 de debate; contexto sin aportes en los datos; perspectivas sin aportes sin llamar al
proveedor (también sin clave); solo tipo y texto de los aportes, sin nombres, correos, contraseña,
`Bearer`, `autor_id` ni `autor_nombre`; límites de cantidad y longitud con indicador `parcial`;
selección determinista; texto hostil enviado como dato dentro de un JSON válido; `truncado`; sin
clave el backend arranca y el asistente responde 503; errores del proveedor → 429, 503 y 502 con
solo `detail`; clave vacía tratada como ausente. Cliente Gemini con `urlopen` sustituido: URL,
cabecera `x-goog-api-key`, `systemInstruction`, `maxOutputTokens` y tiempo de espera; 429, 503,
403, sin red y tiempo agotado clasificados sin exponer la clave; respuestas bloqueadas, vacías o
inesperadas; `MAX_TOKENS` como truncado; cuerpo no JSON.

Flutter: resultado del contexto (petición con espera de 40 s), sin aportes, parcial, mensajes
propios para 503, 502, 429 y sin red, reintento solo explícito, sin duplicados, respuestas tardías
tras cambiar de sesión o cerrar la pantalla, 401 que cierra la sesión, respuesta con forma
inesperada. Flujos con widgets: dos acciones visibles, resultado marcado como IA y sin crear
aportes, sin aportes, parcial, error con Reintentar, botones desactivados durante la consulta y
salida del detalle con consulta pendiente.

Durante el trabajo fallaron tres pruebas por errores de las propias pruebas (una palabra del texto
de ejemplo, la búsqueda del botón y el momento del recuento de peticiones); se corrigieron sin
cambiar la app.

### Docker (agente)

`docker compose up --build -d api` → *healthy*, versión 0.5.0. Recuento antes y después (sin leer
contenido): 3 usuarios, 20 debates, 1 aporte. `/health` 200 y `POST /asistente/debates/1` sin token
401. **No se llamó al asistente con token**, para no generar llamadas reales a Gemini. No se leyó
`backend/.env` ni se imprimió la configuración resuelta; `docker compose config` se validó con
`--env-file /dev/null` y un secreto sintético solo en el proceso.

### Pruebas reales con Gemini (24/10/2026, persona autora, no el agente)

Realizadas en el emulador contra el backend Docker con Gemini configurado por la persona autora.
El agente no hizo ninguna llamada real a Gemini.

| Comprobación | Resultado aportado |
|---|---|
| Explicación real del contexto de "Huertos urbanos en espacios públicos" | ✅ |
| Estado de carga con los botones desactivados | ✅ |
| Aviso de ausencia de aportes | ✅ |
| Resumen real de dos aportes de cuentas distintas, sin nombres en el resultado | ✅ |
| Los aportes siguen siendo los publicados por las personas; el asistente no publicó contenido | ✅ |

**Problema detectado:** las respuestas mostraban literalmente las marcas Markdown (`**negritas**`,
`###` encabezados, `*` listas).

### Corrección de la presentación del Markdown (24/10/2026, agente)

Solo Flutter; backend y contrato sin cambios (no se repitieron sus 102 pruebas). Sin nuevas
llamadas reales a Gemini.

- Dependencia añadida: `flutter_markdown_plus` 1.0.12 (BSD-3-Clause, editor verificado), sucesor
  que recomienda la página del descontinuado `flutter_markdown` en pub.dev. Trae `markdown` 7.3.1
  (BSD-3). El `pubspec.lock` solo añadió esas dos entradas.
- Nuevo `lib/widgets/texto_markdown_seguro.dart`; `seccion_asistente.dart` lo usa en lugar del
  `SelectableText` plano. Se conservan "Generado por IA", los avisos y todos los estados.
- Seguridad: imágenes sustituidas por texto (el paquete usaría `Image.network` por defecto),
  enlaces sin acción al pulsar, HTML no interpretado (un bloque HTML se omite).

Pruebas automáticas del agente con respuestas de ejemplo **locales** que reproducen el formato de
las capturas: `flutter analyze` → **No issues found**; `flutter test --timeout 30s` → **114 passed**
(107 anteriores + 6 de `texto_markdown_seguro_test.dart` + 1 en `asistente_flujo_test.dart`).
Cubren: sin marcas visibles y texto conservado; negrita, cursiva y encabezado con más tamaño que el
párrafo; viñetas y lista numerada; sin desbordamientos a 320 px de ancho y a 360 px con texto ×2, sin
scroll propio; sin `Image` ni HTML visible y enlace que no hace nada al pulsarlo; resultado del
asistente con formato, etiqueta y aviso.

Durante el trabajo se ajustó el estilo de los encabezados (antes `###` tenía el mismo tamaño que
el párrafo) y se corrigieron errores de las propias pruebas.

### Comprobación visual del Markdown en emulator-5554 (24/10/2026, persona autora, no el agente)

**Confirmación de la persona autora:** comprobación visual satisfactoria.

**Observado en las capturas aportadas:** explicación del contexto y resumen de aportes con
negritas, títulos y listas correctamente formateados, sin marcas Markdown literales ni
desbordamientos visibles. Se conserva la etiqueta "Generado por IA"; en la captura de contexto se
ve además el aviso completo.

**No comprobado manualmente:** el texto del sistema ampliado. Esa comprobación solo consta en las
pruebas automáticas del agente (360 px con texto ×2).

## Decisiones registradas (2026-10-22)

- Se mantiene `flutter_lints ^6.0.0`.
- Debates y aportes requieren sesión; públicos solo `/health`, `/auth/registro`, `/auth/login`.
- IA: Gemini vía backend propio, clave solo en el servidor, sin modo de demostración.
- Bloque 5: Gemini por REST con `urllib` (sin SDK); modelo `gemini-3.5-flash-lite`; campo
  `accion` (antes `modo` en el contrato inicial); 429/502/503 diferenciados.
- Bloque 1: tablas con `create_all` (sin Alembic); orden del catálogo por `id`; correo duplicado
  → 400 explícito; arranque con `uvicorn app.main:create_app --factory`.

# Seguimiento — Ágora Joven

Leyenda: ✅ comprobado con evidencia · ⏳ pendiente · ⛔ bloqueado

## Estado actual (24/10/2026)

- **Bloque 6 comprobado.** Release publicada: [v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0), generada por GitHub Actions desde
  el commit `1ce2f37` (código de la Release validada).
- CI en verde para `1ce2f37` y recorrido final sobre el APK de la Release en emulator-5554,
  confirmados por la persona autora (ver "Bloque 6 → Validación de la Release v1.0.0").
- Se mantienen las limitaciones conocidas (README → "Limitaciones conocidas"), incluido el
  pendiente técnico de Hive.
- **Solo queda entregar el enlace del repositorio en Moodle** (persona autora). No está
  registrado como realizado.
- **v1.1 en desarrollo**: Bloque 7A publicado en `origin/main` (commit `c53367f`). **Bloque 7B
  (debates de usuarios, con roles y archivo revisado por la administración) comprobado**: pruebas
  automáticas del agente y recorrido manual completo confirmado por la persona autora. Pendiente:
  revisión de cambios, commit y push. La etiqueta `v1.0.0` y sus archivos publicados no se han
  tocado. 7B.1 y 7C no han empezado.

## Punto de continuación (actualizado el 25/10/2026)

- **Último commit publicado:** `c53367f` (Bloque 7A), en `origin/main`.
- **7B comprobado, sin commit ni push**, incluidos roles (usuario/administrador), solicitudes de
  archivo con revisión administrativa y la corrección del desbordamiento del dashboard.
- **Resultados reportados por el agente:** backend 167 pruebas aprobadas (Python 3.11 local y 3.12
  en contenedor), Flutter 181 pruebas aprobadas y `flutter analyze` sin incidencias.
- **Base real migrada a la revisión `0003`**, con respaldos verificados fuera de Git:
  - Previo a 7B (esquema 7A):
    `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b-20261024-211248.db`
  - Previo a roles y solicitudes (revisión `0002`):
    `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b-roles-20261024-221206.db`
- **Recorrido manual con la política anterior**: satisfactorio, según la persona autora.
- **Cuenta administradora:** la cuenta "Admin" (id 4) fue promovida expresamente por la persona
  autora con el comando local; la salida de `listar` confirma `administrador`. Las cuentas Jleiva y
  patu siguen como usuarios normales. (Según la persona autora; el agente no ejecutó el comando.)
- **Recorrido manual de la política nueva:** confirmado en general por la persona autora; la
  **aprobación administrativa** está comprobada expresamente con capturas. Cancelación, rechazo,
  archivo directo y revisión visual del dashboard no tienen evidencia manual específica y los cubren
  las pruebas automáticas (ver "Ajuste de 7B → Comprobación manual de la persona autora").
- **Pendiente:** revisar los cambios (`git diff`), commit y push (persona autora).
- **Siguiente bloque:** 7B.1, historial y protección permanente del contexto. No empezarlo todavía.

## Bloques

| Bloque | Contenido | Estado |
|---|---|---|
| 0 | Base: repositorio, app mínima con GetX, `/health`, Docker Compose, documentación | ✅ Commit `5a8611d` |
| 1 | Backend: SQLite, autenticación JWT y catálogo de 20 debates | ✅ Commit `4238dd5` |
| 2 | App: sesión (registro, acceso, restauración, cierre) y catálogo con filtro y detalle | ✅ Commit `285f020`, publicado en `origin/main` |
| 3 | Aportes: backend con propiedad comprobada y pantallas en la app | ✅ Commit `317cf23`, publicado en `origin/main` |
| 4 | Debates guardados con Hive | ✅ Commit `5df1279`, publicado en `origin/main` (con el pendiente técnico de Hive documentado) |
| 5 | Asistente con Gemini: endpoint del backend y pantalla en la app | ✅ Commit `20fae85`, publicado en `origin/main` |
| 6 | CI, workflow de Release, README final, auditoría de secretos | ✅ Commit `1ce2f37`; CI en verde; Release `v1.0.0` publicada y validada en emulador (persona autora) |
| 7A (v1.1) | Dashboard de comunidad y participación personal; navegación Inicio · Debates · Guardados | ✅ Commit `c53367f`, publicado en `origin/main` |
| 7B (v1.1) | Creación de debates por usuarios: borradores, publicación, edición, Mis debates; archivo con solicitud y revisión administrativa; roles; migraciones 0002–0003 | ✅ Comprobado (pruebas automáticas y recorridos manuales de ambas políticas por la persona autora); pendiente revisión, commit y push |
| 7B.1 (v1.1) | Historial y protección permanente del contexto | ⏳ Siguiente bloque |

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
- Commit registrado: Bloque 5 `20fae85` (publicado en `origin/main`).
- Commit registrado: Bloque 6 `1ce2f37` (publicado; etiqueta `v1.0.0`).
- **Pendiente único: entregar en Moodle el enlace del repositorio** (persona autora).
- Capturas: el README incluye 6 capturas reales de desarrollo, no tomadas con el APK de la Release.
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

## Bloque 6 — CI, Release y documentación final (24/10/2026)

Sin funcionalidades nuevas ni dependencias nuevas o actualizadas. Archivos nuevos:
`.github/workflows/ci.yml` y `.github/workflows/release.yml`. Modificados: `README.md` (reescrito
para la entrega), `docs/ARQUITECTURA.md` (sección CI y Release), `AGENTS.md` y este archivo.

Acciones comprobadas en sus páginas oficiales de GitHub el 24/10/2026: `actions/checkout@v7`
(7.0.1), `actions/setup-python@v7` (7.1.0; `cache: pip` y `cache-dependency-path` según su
README), `actions/setup-java@v6` (6.1.0), `subosito/flutter-action@v2` (2.23.0; `flutter-version`,
`channel`, `cache`), `softprops/action-gh-release@v3` (3.0.3; `files`, `name`, `body`,
`generate_release_notes`, `fail_on_unmatched_files`; requiere `contents: write`). No se usan
`upload-artifact`/`download-artifact`: no quedó confirmada la compatibilidad entre sus versiones
actuales, así que compilación y publicación van en el mismo trabajo.

### Resultados locales (ejecutados por el agente)

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test --timeout 30s` | ✅ 114 passed |
| `flutter pub get --enforce-lockfile` | ✅ Sin cambios en el lock |
| Backend `pytest` en contenedor desechable `python:3.12-slim` (Python 3.12.15, dependencias de `requirements-dev.txt`, repositorio montado en solo lectura) | ✅ 102 passed |
| Sintaxis YAML de los dos workflows (PyYAML en el mismo contenedor) | ✅ Válida; permisos: `contents: read` global, `contents: write` solo en el trabajo `apk` |
| Comprobación etiqueta ↔ `pubspec.yaml` simulada | ✅ `v1.0.0` aceptada, `v1.0.1` rechazada |
| `flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:8010` | ✅ `app-release.apk` (51,7 MB) |
| APK local (`aapt`, `apksigner` de build-tools 36.0.0) | ✅ `ec.edu.ute.agora_joven`, versión 1.0.0 (código 1), minSdk 24, permiso `INTERNET`, etiqueta "Ágora Joven", URL `10.0.2.2:8010` incluida, firmado con `CN=Android Debug` |
| Auditoría de archivos versionados y pendientes (sin leer `.env`) | ✅ Sin `.env`, bases de datos, APK, almacenes de claves ni `local.properties` versionados; `backend/.env` ignorado y nunca en el historial; sin patrones de claves; sin correos fuera de `example.com`; ningún archivo > 1 MB |

El APK local está en `app/build/` (ignorado por Git) y **no es el de la Release**: el de GitHub se
compilará en el runner, con otra clave de depuración y otro checksum.

### Preparado pero no ejecutado (situación antes del commit `1ce2f37`; resuelta más abajo)

- Workflows de CI y Release: **nunca se han ejecutado en GitHub**. Posibles diferencias con la
  verificación local: runner Linux, descarga de Flutter y dependencias, Java 17 de Temurin.
- La Release `v1.0.0`, su APK y su `.sha256` no existen todavía.
- No se ha instalado ningún APK de Release ni se ha hecho el recorrido final con él.

### Revisión de coherencia con la rúbrica

| Criterio | Estado |
|---|---|
| Persistencia remota/colaborativa, Autenticación, Datos reales, Persistencia local, GetX, IA sin secretos, Manejo de errores, Arquitectura | Implementados y comprobados en bloques anteriores (pruebas automáticas y recorridos manuales registrados arriba) |
| Documentación y entrega | README completo; historial con un commit por bloque; CI en verde; Release `v1.0.0` con APK generado por GitHub Actions; APK probado en emulador (persona autora). Falta solo la entrega en Moodle |

Observaciones: el README incluye 6 capturas reales de desarrollo (ver "Capturas del README"). La lista de verificación del
curso sugiere un manejador global de errores no capturados ("pantalla roja"); no está
implementado y figura en README → Limitaciones, junto al pendiente técnico de Hive.

### Capturas del README (24/10/2026)

Seis capturas reales aportadas por la persona autora, tomadas en el emulador durante las pruebas de
desarrollo (app ejecutada desde el código contra el backend Docker), **no** con el APK de la
Release. El agente las inspeccionó antes de copiarlas (sin correos, contraseñas, tokens ni claves;
se ven los nombres de las cuentas de prueba) y las copió sin modificar a `docs/capturas/`:
`01-acceso.png`, `02-catalogo.png`, `03-aportes-dos-cuentas.png`, `04-guardados.png`,
`05-asistente-contexto.png` (explicación real de Gemini con Markdown) y
`06-asistente-sin-aportes.png`. Los originales no se tocaron.

El README aclara también que desinstalar la app borra la sesión y los guardados de Hive del
dispositivo, pero no los datos del backend.

Estas capturas siguen siendo de desarrollo. Las capturas del recorrido final con el APK de la
Release no se publican (una de acceso contiene un correo personal) y no son necesarias para el
cierre.

### Validación de la Release v1.0.0 (24/10/2026, persona autora, no el agente)

El agente no ejecutó workflows, no creó la etiqueta ni la Release, no descargó ni instaló el APK
y no repitió pruebas ni llamadas a Gemini para este cierre. Solo comprobó en local que la etiqueta
`v1.0.0` apunta a `1ce2f37`.

**Evidencias aportadas por la persona autora:**

| Comprobación | Resultado aportado |
|---|---|
| CI de `1ce2f37` (trabajos Flutter y backend) | ✅ En verde |
| Workflow "Release APK" para `v1.0.0`, apuntando a `1ce2f37` | ✅ En verde |
| Release publicada con el APK y el archivo SHA-256 | ✅ [v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0) |
| APK descargado: comparación del checksum SHA-256 | ✅ `True` |
| Desinstalación de la versión anterior e instalación del APK descargado con `adb` | ✅ `Success` |

**Recorrido final sobre ese APK en emulator-5554, abierto desde su icono.** La persona autora
confirma todo correcto: acceso; catálogo y detalle; aporte compartido entre cuentas; guardado
persistente tras cierre completo; asistente real; cierre de sesión con protección frente a Atrás.

**Observado en las capturas del recorrido** (aportadas, no publicadas): catálogo, detalle, aporte
y respuestas del asistente con Markdown. El resto del recorrido consta por la confirmación de la
persona autora. La captura de acceso de este recorrido **no se publica** porque contiene un correo
personal.

**Código de la Release validada:** commit `1ce2f37` (etiqueta `v1.0.0`). Los archivos de la
Release no se han reconstruido ni sustituido, y la etiqueta no se ha movido.

**Limitaciones que se mantienen** (README → "Limitaciones conocidas"): firma con clave de
depuración, APK solo para el emulador por HTTP local, pendiente técnico de Hive, sin manejador
global de errores y dependencia de Gemini.

### Pasos para la entrega (persona autora)

1. ~~Commit y push del Bloque 6~~ — hecho (`1ce2f37`).
2. ~~CI en verde~~ — hecho (persona autora).
3. ~~Etiqueta `v1.0.0` y workflow "Release APK" en verde~~ — hecho (persona autora).
4. ~~Descargar y verificar el APK y su SHA-256~~ — hecho (persona autora).
5. ~~Instalar el APK en el emulador~~ — hecho (persona autora).
6. ~~Recorrido final con dos cuentas~~ — hecho (persona autora).
7. **Entregar en Moodle el enlace del repositorio** (https://github.com/jleivalabs/agora-joven)
   antes del lunes 26/10/2026 a las 08:00 — **pendiente**.

## Bloque 7A — dashboard de comunidad y participación (v1.1)

Punto de partida comprobado: `main` = `origin/main` = `c79c9e3`, árbol limpio, `v1.0.0` → `1ce2f37`.
Sin dependencias nuevas y sin cambios en el esquema de la base.

**Backend.** Nuevos `app/repositorios/estadisticas.py` (consultas agregadas con `COUNT`,
`COUNT(DISTINCT)`, `GROUP BY` y `MAX`) y `app/routers/estadisticas.py` con
`GET /estadisticas/comunidad` y `GET /estadisticas/mias` (ambos con JWT). Esquemas en
`schemas.py`; versión de la API `1.1.0-dev`. Definiciones de cada indicador en
`docs/ARQUITECTURA.md → Dashboard`.

**App.** Nuevos `PrincipalScreen` (navegación inferior), `InicioScreen`, `InicioController`,
`PrincipalController`, `ActividadAportes`, `EstadisticasRepository`, `models/estadisticas.dart`,
`widgets/menu_cuenta.dart` y `utils/formato.dart`. `DebatesScreen` y `GuardadosScreen` pasan a ser
pestañas (el atajo de Guardados del catálogo se sustituye por la barra inferior);
`AportesController` avisa al dashboard tras cambios confirmados.

### Pruebas automáticas (ejecutadas por el agente)

| Suite | Resultado |
|---|---|
| Backend `pytest -q` | **115 passed** (102 anteriores + 13 de `test_estadisticas.py`) |
| `flutter analyze` | **No issues found** |
| `flutter test --timeout 30s` | **133 passed** (114 anteriores, adaptadas a la nueva navegación, + 8 de `inicio_controller_test.dart` + 11 de `inicio_flujo_test.dart`) |

Backend: 401 sin token o con token inválido; `/mias` ignora identificadores en la consulta;
respuestas sin correos, nombres, `autor` ni tokens; base sin aportes; recuentos exactos con tres
cuentas (una sin aportes): 6 aportes, 2 participantes, 17 debates sin aportes; una cuenta con tres
aportes en un debate cuenta una vez como participante y una vez en sus debates participados;
separación de las cifras de cada cuenta; bajada de cifras al eliminar; orden y límite de actividad
reciente, de debates sin aportes y de mis aportes recientes, con desempate por id.

Flutter: carga de ambas secciones; la consulta personal sin identificadores; error sin ceros y
reintento por sección; un fallo al recargar no deja cifras antiguas; actualización tras un cambio
de aportes; respuestas tardías de una sesión anterior, tras cerrar la pantalla o superadas por
otra carga. Flujos con widgets: navegación principal y menú de cuenta; cifras exactas;
estado sin aportes con "Explorar debates"; categoría → catálogo filtrado; actividad y mis aportes →
detalle; Mis guardados → pestaña; error sin ceros con Reintentar; publicar un aporte actualiza
Inicio; actualización manual; sin desbordamientos a 320 px y con texto ×2.

**Errores reales encontrados y corregidos por las pruebas:**

- `Get.find()` sin tipo explícito buscaba `ActividadAportes?` y la pantalla principal fallaba al
  construirse; se indica el tipo.
- El dashboard no se repintaba si una recarga traía cifras nuevas con el mismo estado (los datos se
  leían fuera del `Obx`); ahora se leen dentro.
- El encabezado "Asistente educativo" del detalle (Bloque 5) desbordaba en pantallas estrechas;
  el título es ahora flexible.

Las pruebas existentes que entraban directamente al catálogo ahora pasan antes por la pestaña
Debates (`test/helpers/navegacion.dart`); una prueba de aportes busca la última petición `PATCH`
porque el dashboard recarga sus cifras después.

### Docker (agente)

`docker compose up --build -d api` → *healthy*, versión `1.1.0-dev`. Recuento antes y después
(sin leer contenido): 3 usuarios, 20 debates, 4 aportes. `/health` 200; las dos rutas de
estadísticas responden 401 sin token. No se crearon cuentas ni aportes en el volumen real; no se
leyó `.env` ni se llamó a Gemini.

### Recorrido manual en emulator-5554 (persona autora, no el agente)

Realizado con la app ejecutada desde el código contra el backend actualizado (no con el APK
v1.0.0). **Confirmación de la persona autora:** pruebas funcionales satisfactorias, en concreto:

- Navegación por categorías y detalles desde el dashboard.
- Publicación y eliminación de un aporte con actualización de las cifras.
- Separación de "Mi participación" entre cuentas.
- El resto del recorrido propuesto (navegación principal, menú de cuenta, Mis guardados, errores
  con Reintentar, texto ampliado y cierre de sesión con Atrás) también fue satisfactorio.

**Observado en las capturas aportadas** (no publicadas en el repositorio):

- "Aportes": 4 → 5 → 4 (antes de publicar, tras publicar y tras eliminar).
- "Debates sin aportes": 17 → 16 → 17.
- "Participantes" permanece en 2.
- Acceso con las cuentas Jleiva y patu, cada una con sus aportes recientes.

### Ajustes de presentación tras el recorrido (agente)

1. **Tarjetas simétricas.** Componente compartido `TarjetaEstadistica` + `RejillaEstadisticas`
   (`lib/widgets/tarjetas_estadistica.dart`), usado por las dos secciones: igual ancho y altura
   dentro de cada grupo (2×2 en "La comunidad", dos iguales en "Mi participación"), icono,
   cifra, título y explicación alineados; todas las tarjetas llevan explicación ("En el catálogo
   actual", "Preguntas, argumentos y propuestas", "Con al menos un aporte tuyo"…). Sin recortes
   ni tipografía reducida: la altura crece con el texto y pasa a una columna cuando no cabe.
2. **Orden por categoría.** De más a menos debates; en empate, por nombre visible en orden
   alfabético español. Se mantienen cantidad, barra y navegación al catálogo filtrado. En 7A la
   cifra cuenta los debates publicados del catálogo actual (no existe estado abierto/cerrado; se
   revisará en 7B). Con el catálogo actual: Ambiente, Educación, Movilidad y Tecnología (3);
   Cultura, Empleo, Participación y Salud (2).

Sin cambios en backend, esquema ni dependencias; no se repitieron las pruebas del backend.

| Verificación (agente) | Resultado |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test --timeout 30s` | ✅ **143 passed** (133 + 5 de `tarjetas_estadistica_test.dart` + 3 de `orden_categorias_test.dart` + 2 en `inicio_flujo_test.dart`) |

Cubren: 2×2 con igual ancho y altura y separación uniforme aunque una explicación sea más larga;
textos sin `maxLines` ni recorte; una columna a 280 px; texto ×2 que aumenta la altura sin
desbordar; tarjeta pulsable con etiqueta accesible; orden alfabético español (tildes, mayúsculas,
ñ); orden exacto con los datos actuales del catálogo; cantidades distintas y empates; orden en el
dashboard (Ambiente 7, Movilidad 7, Educación 6, Cultura 0 en el servidor falso); tarjetas
simétricas en ambos grupos del dashboard.

### Revisión visual de los ajustes en emulator-5554 (persona autora, no el agente)

**Confirmación de la persona autora:** todas las comprobaciones finales de 7A fueron
satisfactorias.

**Observado en las capturas aportadas** (no publicadas en el repositorio):

- Las cuatro tarjetas de "La comunidad" con dimensiones uniformes.
- Las dos tarjetas de "Mi participación" con dimensiones uniformes.
- Las categorías ordenadas por cantidad descendente y, en empate, por nombre.

Lo demás (por ejemplo, ausencia de cortes con el texto ampliado) consta por la confirmación de la
persona autora, no por las capturas. El agente no repitió pruebas ni cambió código para este
registro.

**Estado de 7A:** comprobado. Pendiente únicamente commit y push (persona autora).

## Bloque 7B — Debates creados por usuarios (2026-10-24)

Punto de partida: `c53367f` (7A) en `origin/main`. Sin subagentes, sin llamadas a Gemini, sin
commit, push, etiquetas ni Releases. Diseño y contrato en `docs/ARQUITECTURA.md` → "Debates de
usuarios".

### Acciones realizadas (agente)

- Backend: modelo `procedencia`/`estado`/`autor_id`, tabla `borradores`, rutas `/borradores`,
  `/borradores/{id}/publicar`, `PUT /debates/{id}`, `/debates/{id}/archivar`, `/mis-debates`;
  409 para aportes en debates archivados; estadísticas solo con debates activos y
  `debates_archivados` / `mis_debates`.
- Migraciones Alembic (`0001` esquema 7A, `0002` cambios 7B) aplicadas al arrancar en lugar de
  `create_all`. Dependencias nuevas: `alembic` 1.20.0, `mako` 1.4.1, `markupsafe` 3.0.3 (versiones
  del lock del curso).
- App: asistente de creación de 6 pasos (también para editar), Mis debates con tres pestañas,
  botón "Crear debate" en el catálogo, tarjeta "Mis debates" en Inicio, aviso de contenido de la
  comunidad, menú de autor (editar/archivar), aviso de archivado, `TipoError.conflicto` (409),
  `ActividadAportes` renombrado a `ActividadComunidad`. Etiqueta del dashboard: "Debates activos".

### Resultados verificados (agente)

| Comprobación | Resultado |
|---|---|
| `pytest -q` (Python 3.11 local) | 149 passed (incluye 29 de borradores/debates de usuarios y 5 de migración) |
| `pytest -q` en contenedor desechable `python:3.12-slim` (montaje de solo lectura) | 149 passed |
| `flutter analyze` | No issues found |
| `flutter test` | 164 passed (incluye 11 del controlador y 10 de flujo de creación) |

Cubren: borradores incompletos, guardado y recuperación; aislamiento entre dos cuentas (listar,
leer, modificar, eliminar y publicar ajenos → 404); publicación válida, inválida y repetida (201/200
sin duplicados); edición bloqueada con aportes; archivo sin pérdida y 409 a nuevos aportes;
estadísticas sin borradores ni archivados; migración desde una base 7A sintética; en Flutter,
fallos de red con reintento, respuesta perdida al publicar, cambio de sesión durante la
publicación y pantallas estrechas (360 px con texto ×2).

Errores encontrados y corregidos durante el bloque:

- Reintentar "Publicar" tras perder la respuesta quedaba bloqueado (el guardado previo recibía
  409 porque el borrador ya estaba publicado). Ahora no se vuelve a guardar sin cambios y el 409
  se trata como "ya publicado".
- El botón de texto "Guardar y salir" desbordaba la barra a 360 px con texto ×2: pasó a icono con
  descripción emergente.

### Migración de la base real

1. Esquema del volumen comparado con el de 7A (solo lectura): idéntico.
2. **Copia de seguridad** con la API de copia de SQLite, fuera de Git:
   `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b-20261024-211248.db`.
   Verificada: se abre, `integrity_check` = ok, tablas `usuarios`, `debates`, `aportes`.
3. Ensayo sobre una copia temporal de esa copia: revisión `0002`, recuentos y huellas de datos
   iguales, 20 debates `editorial`/`publicado`, `integrity_check` ok, `foreign_key_check` vacío.
   La copia temporal se eliminó.
4. Migración real con `docker compose up --build -d api` (sin `down -v`; volumen conservado).
   Resultado: servicio sano, revisión `0002`, mismos recuentos que la copia (3 cuentas, 20
   debates, 4 aportes, 0 borradores), huellas SHA-256 de cuentas, aportes y debates (id, slug)
   iguales a la copia, `integrity_check` ok, `foreign_key_check` vacío; `/health` 200 y
   `/borradores`, `/mis-debates` → 401 sin token. No se mostraron datos personales en las
   comprobaciones.

Restauración: ver `docs/ARQUITECTURA.md` → "Restaurar la copia previa a 7B".

### Pendiente: recorrido manual con dos cuentas (persona autora)

No ejecutado por el agente en emulador. Requiere el backend migrado y `flutter run`.

1. Cuenta A: Debates → "Crear debate". En el paso 1 pulsa "Siguiente" sin categoría: error junto
   al campo y no avanza.
2. Completa tema y pregunta, avanza al paso 3, vuelve atrás: los datos siguen ahí.
3. Escribe parte del contexto y pulsa atrás del sistema: aparece el aviso de cambios sin guardar;
   elige "Guardar y salir".
4. **Cierre completo**: quita la app de recientes (o detenla) y vuelve a abrirla. Inicio → "Mis
   debates" → Borradores: el borrador está, y al abrirlo retoma el paso y los datos.
5. Con el backend detenido (`docker compose stop api`), pulsa "Siguiente": error con "Reintentar
   guardado" y datos intactos. Arranca la API (`docker compose start api`) y reintenta.
6. Completa perspectivas (prueba añadir hasta 5 y quitar hasta 2) y objetivo; en Revisión pulsa
   "Publicar debate". Se abre el detalle con "Debate creado por …" (nombre, no correo).
7. Inicio y catálogo: "Debates activos" y la categoría suben en 1; Mis debates → Publicados lo
   muestra. Edita el debate desde el menú del detalle y guarda.
8. Cuenta B (cierra sesión de A): ve el debate en el catálogo con "CREADO POR …", no ve el menú de
   autor ni los borradores de A; publica un aporte y guarda el debate.
9. Cuenta A: el menú indica "Editar debate" bloqueado (ya tiene aportes). Archiva con
   confirmación; deja de estar en el catálogo, pasa a Archivados y el contador baja.
10. Cuenta B: abre el debate desde Guardados: aviso de archivado, sin "Publicar un aporte" y sin
    editar/eliminar su aporte, que sigue visible.
11. Cuenta A: crea un borrador cualquiera y elimínalo con confirmación desde Mis debates.
12. Revisión visual en pantalla estrecha y con texto ampliado del asistente y de Mis debates.

**Estado de 7B (política inicial):** implementado y verificado con pruebas automáticas y migración
real comprobada. La persona autora informó que el recorrido manual anterior fue **satisfactorio
para esa política** (archivo directo por el autor). Esa política se sustituyó a continuación.

### Ajuste de 7B: archivo con revisión administrativa y roles (2026-10-24)

Cambio solicitado por la persona autora antes de cerrar 7B: el autor ya no archiva directamente;
solicita el archivo y la administración lo revisa. Además, corrección de un desbordamiento del
dashboard. Sin subagentes, sin llamadas a Gemini, sin commit, push ni etiquetas. 7B.1 y 7C no se
han empezado.

#### Acciones realizadas (agente)

- **Dashboard**: `RejillaEstadisticas` maquetaba cada tarjeta con altura fija; al cambiar el texto
  tras una recarga la tarjeta se recalculaba sola y desbordaba. Ahora la altura común es un mínimo
  y cualquier cambio de contenido la recalcula. Prueba nueva que reproduce el cambio de texto tras
  archivar en ancho normal, pantalla estrecha y texto ×2 (fallaba con 44, 12 y 56 px antes de la
  corrección; pasa después).
- **Roles** (`usuarios.rol`): registro siempre `usuario` (422 si se envía `rol` u otro campo), sin
  edición de perfil, rol leído de la base en cada petición (un rol en el token o en la petición se
  ignora), comando local `python -m app.admin listar|promover|retirar` con confirmación por id. No se
  ha ejecutado `promover` ni se ha elegido ninguna cuenta.
- **Solicitudes de archivo**: tabla `solicitudes_archivo`, rutas de autor y de administración,
  archivo directo solo para administración con motivo; el antiguo `POST /debates/{id}/archivar`
  responde 403 a usuarios normales aunque sean autores.
- **App**: "Solicitar archivo"/"Cancelar solicitud" en el detalle, estado de la solicitud en el
  detalle y en Mis debates, explicación pública del archivo, sección Administración en Inicio
  (solo administradores) con lista, detalle, Aprobar y Rechazar.
- **Migración** `0003` (nueva; `0001` y `0002` no se modificaron).

#### Resultados verificados (agente)

| Comprobación | Resultado |
|---|---|
| `pytest -q` (Python 3.11 local) | 167 passed |
| `pytest -q` en contenedor desechable `python:3.12-slim` | 167 passed |
| `flutter analyze` | No issues found |
| `flutter test` | 181 passed |

Pruebas por API (`tests/test_solicitudes.py`, 17): registro con `rol` → 422; `PATCH`/`PUT
/auth/me` → 405; token con `rol` añadido o cabecera/parámetro de rol → 403; retirar el rol en la
base surte efecto con el mismo token; rutas de administración → 403 para autora y cuenta ajena;
solicitud duplicada (y 6 simultáneas) → una sola pendiente; solo la autora solicita; cancelación
propia/ajena; aprobación (archiva, conserva aportes, bloquea nuevos) y rechazo (sigue activo);
dobles resoluciones (y 6 simultáneas: una 200 y cinco 409, con resultado coherente); archivo
directo con motivo obligatorio que cierra la solicitud pendiente; detalles internos invisibles
para otras cuentas; comando de promoción con confirmación y sin correos. Migración: base 0002 con
un debate archivado por su autor → `anterior`, sin revisor ni motivo, mismo estado y fecha.

En Flutter (`solicitudes_controller_test.dart`, 9, y `crear_debate_flujo_test.dart`): envíos
duplicados ignorados, 409 que recarga el estado, 403 de permisos, respuesta tardía tras cambiar de
sesión descartada, flujo del autor (solicitar con validación del motivo, sigue abierto, cancelar),
Mis debates (pendiente y cancelación), cuenta normal sin Administración ni archivo directo,
aprobación desde Inicio (también a 360 px con texto ×2) y archivo directo con motivo.

#### Migración de la base real

1. **Copia de seguridad** consistente (API de copia de SQLite, origen en solo lectura), fuera de
   Git: `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b-roles-20261024-221206.db`.
   Verificada: `integrity_check` ok, revisión `0002`, 3 cuentas, 21 debates (20 editoriales
   publicados y 1 de usuario archivado durante las pruebas manuales), 5 aportes, 2 borradores.
2. Ensayo sobre una copia temporal: revisión `0003`, mismas huellas SHA-256 de cuentas, aportes,
   borradores y debates; 3 cuentas `usuario`; el debate archivado queda `anterior` sin revisor ni
   motivo; 0 solicitudes; `integrity_check` ok y `foreign_key_check` vacío. Copia temporal eliminada.
3. Migración real con `docker compose up --build -d api` (sin `down -v`): servicio sano, mismos
   resultados que el ensayo (huellas iguales a la copia). `/health` 200; `/admin/solicitudes-archivo`
   y `/solicitudes-archivo` → 401 sin token. Volumen conservado. Las comprobaciones solo mostraron
   recuentos, estados y huellas, sin datos personales.

#### Comprobación manual de la persona autora (2026-10-25)

Evidencia aportada por la persona autora, no por el agente (el agente no ejecutó la app en
emulador ni el comando de promoción).

- **Cuenta administradora:** "Admin" (id 4) promovida expresamente por la persona autora con
  `python -m app.admin promover`; la salida de `listar` confirma el rol `administrador`. Jleiva y
  patu siguen como usuarios normales.
- **Confirmación general previa:** la persona autora indicó que completó satisfactoriamente las
  pruebas manuales previstas (autor, participante y administración), sin detallar cada caso.

**Comprobado expresamente por la persona autora, con capturas:**

- Primera tanda: sección Administración visible en Inicio para la cuenta administradora; lista de
  solicitudes inicialmente vacía; publicación de un debate; solicitud de archivo y su estado
  pendiente; el debate guardado y un aporte de patu mientras el debate sigue abierto.
- **Aprobación administrativa** (registrada después, el 2026-10-25): solicitud pendiente de
  "Prueba movilidad" en la lista; su detalle con el motivo y un aporte existente; confirmación con
  justificación; resultado "Solicitud aprobada: el debate quedó archivado." y lista de pendientes
  vacía.

**Sin evidencia manual específica** (ni capturas ni confirmación expresa de cada caso; solo la
confirmación general anterior). Los cubren las **pruebas automáticas** del agente
(`backend/tests/test_solicitudes.py`, `app/test/solicitudes_controller_test.dart`,
`app/test/crear_debate_flujo_test.dart`, `app/test/tarjetas_estadistica_test.dart`):

- Cancelación de la solicitud por el autor.
- Rechazo con justificación (el debate sigue activo y el autor ve la respuesta).
- Archivo directo por la administración con motivo obligatorio.
- Revisión visual de "Debates activos" tras archivar, también con texto ampliado.

Las capturas de la aprobación no muestran el debate archivado desde la vista de otra cuenta ni
desde Guardados; ese comportamiento lo cubren las pruebas automáticas.

**Estado del ajuste de 7B:** comprobado con pruebas automáticas y con la confirmación manual
descrita (aprobación verificada expresamente). Pendiente: revisión de cambios, commit y push
(persona autora); opcionalmente, evidencia manual específica de los casos anteriores.

#### Siguiente bloque: 7B.1 (no implementado)

Historial de cambios y protección permanente del contexto de un debate. No se ha empezado.

## Decisiones registradas (2026-10-22)

- Se mantiene `flutter_lints ^6.0.0`.
- Debates y aportes requieren sesión; públicos solo `/health`, `/auth/registro`, `/auth/login`.
- IA: Gemini vía backend propio, clave solo en el servidor, sin modo de demostración.
- Bloque 5: Gemini por REST con `urllib` (sin SDK); modelo `gemini-3.5-flash-lite`; campo
  `accion` (antes `modo` en el contrato inicial); 429/502/503 diferenciados.
- Bloque 1: tablas con `create_all` (sin Alembic); orden del catálogo por `id`; correo duplicado
  → 400 explícito; arranque con `uvicorn app.main:create_app --factory`.

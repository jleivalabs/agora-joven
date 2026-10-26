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
- **v1.1.0 en cierre**: 7A (`c53367f`), 7B (`2e82559`), 7B.1 (`cb2de64`) y 7C (`afd2e9b`)
  publicados en `origin/main`; CI en verde para `cb2de64` según la persona autora (el estado del
  CI de `afd2e9b` no lo ha comprobado el agente). **Bloque 7C comprobado**
  para la declaración de edad y la gestión de referencias con Crossref real (recorrido manual de
  la persona autora en emulator-5554); la redacción con IA sigue desactivada y solo probada con
  proveedor simulado; resúmenes sin procesar. Base real migrada a `0005` con respaldo previo.
  **Versión 1.1.0 cerrada** (decisión del 25/10/2026; `1.1.0+2`), ver "Cierre de la v1.1.0".
  Etiqueta `v1.1.0` (commit `382e5f8`) y Release publicadas por la persona autora y GitHub Actions.
  Pendiente (persona autora): prueba del APK descargado y envío en Moodle. **El proyecto no está
  marcado como entregado.** La etiqueta
  `v1.0.0` y sus archivos publicados no se han tocado. 7D no ha empezado.

## Punto de continuación (actualizado el 25/10/2026)

- **Último commit publicado:** `afd2e9b` (Bloque 7C), en `origin/main`, publicado por la persona
  autora. El agente no pudo consultar el CI (`gh` no está instalado).
- **Público (decisión del 25/10/2026):** solo personas de 18 años o más. Declaración en el registro
  y confirmación de las cuentas existentes implementadas en 7C. Tras migrar, las 4 cuentas
  existentes (también "Admin") están pendientes de confirmar.
- **7B.1 comprobado y publicado en `cb2de64`.** Resultados del agente: backend 184 pruebas (Python 3.11
  local y 3.12 en contenedor; 167 anteriores + 17), Flutter 190 (181 + 9) y `flutter analyze` sin
  incidencias. Recorrido manual satisfactorio según la persona autora; el conflicto entre dos
  sesiones simultáneas no se comprobó a mano (ver "Bloque 7B.1 → Comprobación manual").
- **Base real migrada a la revisión `0005`** (7C), con respaldos verificados fuera de Git:
  - Previo a 7B (esquema 7A): `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b-20261024-211248.db`
  - Previo a roles y solicitudes (revisión `0002`): `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b-roles-20261024-221206.db`
  - Previo al historial (revisión `0003`): `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b1-20261025-205218.db`
  - Previo a 7C (revisión `0004`): `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7c-20261025-230538.db`
- **Release v1.0.0:** el APK `v1.0.0` usa el backend de la etiqueta `v1.0.0` en un entorno
  separado (proyecto, volumen, contenedor e imagen propios; puerto 8010); la app 1.1 usa el backend
  de `main`. Nunca ejecutar el backend antiguo contra la base migrada a `0004`. El requisito de
  versión de los aportes no se relaja. Instrucciones en `docs/INSTALACION.md` → "Qué código usar
  con cada app".
- **7C comprobado, sin commit ni push.** Resultados del agente: backend 220 pruebas (Python 3.11
  local y 3.12 en contenedor), Flutter 212 y `flutter analyze` sin incidencias. Recorrido manual
  satisfactorio de la persona autora en emulator-5554, con búsqueda real en Crossref
  (`CROSSREF_MAILTO` configurado por ella). **No validado con Gemini real:** la redacción sigue
  desactivada (`REDACCION_IA_ACTIVA=false`) y solo se probó con proveedor simulado. Resúmenes sin
  procesar. Ver "Bloque 7C → Comprobación manual".
- **Pendiente (persona autora):** decidir la política de licencias de los resúmenes y el
  tratamiento de datos de Gemini (incluido el asistente existente); revisar el archivo
  `respaldos-agora-joven$NOMBRE` (aparte); revisión, commit y push. Opcional: probar el APK
  `v1.0.0` (pasos A1–A7 de `docs/INSTALACION.md`).

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
| 7B (v1.1) | Creación de debates por usuarios: borradores, publicación, edición, Mis debates; archivo con solicitud y revisión administrativa; roles; migraciones 0002–0003 | ✅ Commit `2e82559`, publicado en `origin/main`; CI en verde según la persona autora |
| 7B.1 (v1.1) | Historial de versiones, bloqueo permanente tras participación, aportes por versión, aclaraciones; migración 0004 | ✅ Commit `cb2de64`, publicado en `origin/main`; CI en verde según la persona autora |
| 7C (v1.1) | Referencias de Crossref (metadatos), redacción con Gemini sin búsqueda (desactivada), mayoría de edad declarada; migración 0005 | ✅ Commit `afd2e9b`, publicado en `origin/main`. Comprobado: edad y referencias con Crossref real (recorrido manual); redacción solo con proveedor simulado (desactivada) |
| v1.1.0 | Cierre: versión `1.1.0+2`, notas de Release, documentación del alcance definitivo | 🔶 Commit `382e5f8` y etiqueta `v1.1.0` publicados por la persona autora; Release generada por GitHub Actions; pendiente la prueba del APK descargado y el envío en Moodle |

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

Restauración: ver `docs/INSTALACION.md` → "Copias de seguridad y restauración".

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

## Bloque 7B.1 — historial de versiones y protección del contexto (2026-10-25)

Punto de partida: `2e82559` (7B) en `origin/main`, árbol limpio; CI en verde comunicado por la
persona autora. Sin subagentes, sin llamadas a Gemini, sin commit, push, etiquetas ni Releases.
Diseño en `docs/ARQUITECTURA.md` → "Historial de versiones".

### Acciones realizadas (agente)

- Backend: tabla `versiones_debate` (inmutable), indicadores `con_participacion` (permanente) y
  `bloqueo_historico` (conservador), `aportes.version_id`, tabla `aclaraciones`; rutas
  `GET /debates/{id}/versiones[/{numero}]` y `POST /debates/{id}/aclaraciones`; `PUT
  /debates/{id}` con motivo obligatorio; aportes con `version` obligatoria y 409
  `version_desactualizada`; semilla editorial que no reescribe contenido protegido.
- Migración `0004` (nueva; `0001`–`0003` sin cambios).
- App: Historial, vista de versión con diferencias, enlace de cada aporte a su versión, conflicto
  de versión que conserva el texto y pide confirmar, motivo al editar, aclaraciones del autor.
- **Cambio incompatible documentado:** el APK `v1.0.0` ya no puede publicar aportes (422 por falta
  de `version`); el resto de funciones sigue respondiendo. No se relaja la comprobación: ese APK
  debe usar el backend de su etiqueta (ver "Reproducibilidad de la Release v1.0.0").

### Resultados verificados (agente)

| Comprobación | Resultado |
|---|---|
| `pytest -q` (Python 3.11 local) | 184 passed |
| `pytest -q` en contenedor desechable `python:3.12-slim` | 184 passed |
| `flutter analyze` | No issues found |
| `flutter test` | 190 passed |

Recuento del backend: 184 = 167 anteriores + 17. Las 17 son 15 funciones de prueba nuevas (13 en
`tests/test_historial.py` y 2 de la migración `0004` en `tests/test_migracion.py`) y 2 casos
nuevos añadidos a la parametrización de validación ya existente en `tests/test_aportes.py`
(aporte sin `version` y con `version` 0). En el informe anterior se habló de "15 nuevas", que
eran solo las funciones nuevas. En Flutter, 190 = 181 + 9 pruebas nuevas
(`test/historial_test.dart`).

Pruebas nuevas del backend (`tests/test_historial.py`, 13, y 2 de migración): publicación (versión
1) sin versiones por guardar borradores; edición válida con motivo y diferencias; motivo
obligatorio y guardado sin cambios; inmutabilidad (sin rutas de modificación) y permisos (otra
cuenta y administración → 403; lectura para cuentas autenticadas; 401 sin sesión); bloqueo tras el
primer aporte incluso después de eliminarlo; conflicto `version_desactualizada` y versión ajena
(422); editar un aporte no cambia su versión; carreras edición/aporte con hilos (8 rondas, se
observaron ambos órdenes) y los dos órdenes forzados; aclaraciones y restricciones (ajenas,
editoriales, longitudes, archivado); archivo sin alterar el historial; semilla que versiona cambios
y omite protegidos; migración sin pérdida de datos ni versiones, autores o fechas inventadas.

Pruebas nuevas en Flutter (`test/historial_test.dart`, 9): historial, versión vigente e histórica
con diferencias; pantalla estrecha y texto ×2; respuesta tardía tras cambiar de sesión; conflicto
de versión que conserva el texto, no reintenta y publica solo tras confirmar; aporte anterior al
historial con versión desconocida; aclaración del autor; cuenta ajena sin opciones; edición con
motivo, sin cambios y bloqueo tras participación. Las suites existentes (catálogo, dashboard,
guardados, administración, asistente) siguen en verde con los cambios de contrato.

### Migración de la base real

1. **Copia de seguridad** consistente (API de copia de SQLite, origen en solo lectura), fuera de
   Git: `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b1-20261025-205218.db`.
   Verificada: `integrity_check` ok, revisión `0003`, 4 cuentas (1 `administrador`), 22 debates (20
   editoriales publicados, 2 de usuario archivados), 6 aportes, 3 borradores, 1 solicitud.
2. Ensayo sobre una copia temporal: revisión `0004`, mismas huellas SHA-256 de cuentas (con roles),
   aportes, borradores, solicitudes y debates; 22 versiones `registro_inicial` (una por debate,
   sin autor ni motivo); la instantánea coincide con el contenido de cada debate;
   `con_participacion` coincide con los debates que tienen aportes (5); `bloqueo_historico` en los
   22; 0 aportes con versión asignada; `integrity_check` ok y `foreign_key_check` vacío. Copia
   temporal eliminada.
3. Migración real con `docker compose up --build -d api` (sin `down -v`): servicio sano, mismos
   resultados que el ensayo. `/health` 200; `/debates/1/versiones` → 401 sin token. Volumen
   conservado. Solo se mostraron recuentos, estados y huellas, sin datos personales.

### Reproducibilidad de la Release v1.0.0 (revisión del agente, 2026-10-25)

Comprobado en los archivos reales, sin detener el entorno actual, sin restaurar copias y sin
ejecutar el backend antiguo:

- El README de `main` indicaba clonar `main` y después instalar el APK `v1.0.0`: con 7B.1 ese APK
  no puede publicar aportes contra ese backend. **Corregido**: el README separa "Probar la Release
  v1.0.0" (código de la etiqueta) de "Desarrollo v1.1" (`main`) e incluye una tabla de qué usar.
- La etiqueta `v1.0.0` apunta a `1ce2f37` y contiene `backend/` completo (`Dockerfile`,
  `docker-compose.yml`, `.env.example` con `API_PORT`), así que `git clone --branch v1.0.0` permite
  ejecutar su backend. La etiqueta y la Release no se modificaron.
- El `docker-compose.yml` de la etiqueta y el de `main` usaban los mismos nombres fijos: proyecto
  `agora-joven`, volumen `agora-joven_agora_datos`, contenedor `agora-joven-api`, imagen
  `agora-joven-api:dev` y puerto 8010. Sin separar, el backend antiguo podía recrear el contenedor
  de desarrollo sobre el volumen migrado a `0004`, y compilar uno sustituía la imagen del otro.
- Solución documentada (README, pasos A1–A7): clon aparte de la etiqueta, `backend/.env` propio
  creado a mano, archivo de anulación local (`image: agora-joven-api:v1.0.0`, `container_name:
  agora-joven-api-v100`, volumen `agora-joven-v100_agora_datos`), `-p agora-joven-v100`, crear
  sin arrancar y comprobar el volumen con `docker inspect` antes de `start`.
- Verificado en seco: `docker compose config` sobre una extracción temporal de `backend/` de la
  etiqueta (con un `JWT_SECRET` ficticio por variable de entorno, sin `.env`) resolvió proyecto
  `agora-joven-v100`, contenedor `agora-joven-api-v100`, imagen `agora-joven-api:v1.0.0` y volumen
  `agora-joven-v100_agora_datos`. `docker compose create --build` existe en Compose v5.6.0. No se
  construyó ni arrancó nada; la carpeta temporal se eliminó.
- Puerto: el APK `v1.0.0` usa `http://10.0.2.2:8010` (fijado en `release.yml`). Los dos backends no
  pueden usar el 8010 a la vez: se detiene el de desarrollo (`stop`, nunca `down -v`) o se mueve
  a otro puerto con `API_PORT` y `--dart-define`.
- `main` construye ahora `agora-joven-api:1.1-dev` (cambio en `backend/docker-compose.yml`,
  validado con `docker compose config` sobre una copia con secreto ficticio). El contenedor actual
  no se recreó: sigue con la imagen que tenía; el cambio se aplicará en el próximo
  `docker compose up --build -d api`.
- Pendiente (persona autora, opcional): ejecutar los pasos A1–A7 y probar el APK `v1.0.0` contra su
  backend en el volumen separado.

### Recorrido manual previsto (dos cuentas)

No ejecutado por el agente en emulador. Requiere la app compilada con este bloque.

1. Cuenta A publica un debate nuevo. Abre "Historial": versión 1 (Publicación, su nombre).
2. A edita la pregunta: se pide el motivo; mensaje "Cambios guardados como versión 2". En el
   historial, la versión 2 muestra el motivo y "Antes/Después" de la pregunta; la versión 1 indica
   que es histórica. Editar sin cambiar nada: "no se creó una versión nueva".
3. Cuenta B abre el debate y empieza un aporte (el formulario indica "versión 2"). Sin enviarlo,
   A edita de nuevo (versión 3). B envía: aviso de que el debate cambió, el texto se conserva y no
   se publica. B abre "Ver la versión 3", vuelve, pulsa "Aportar sobre la versión 3" y publica. El
   aporte indica "Escrito sobre la versión 3".
4. A intenta editar: "Bloqueado: ya recibió aportes". B elimina su aporte; A sigue sin poder editar.
5. A añade una aclaración (prueba una muy corta: error). Aparece en "Aclaraciones del autor" con
   nombre y fecha; el contenido y el historial no cambian.
6. Un debate anterior (editorial o archivado) muestra en Historial la versión "Estado registrado al
   incorporar el historial"; un aporte antiguo indica "Versión original desconocida" y abre la
   instantánea como referencia.
7. Revisión visual de Historial y Versión con texto ampliado y pantalla estrecha.

### Comprobación manual de la persona autora (2026-10-25)

La persona autora confirma **satisfactorio** el recorrido manual de 7B.1. Es evidencia de la
persona autora, no del agente.

**Visible en las capturas aportadas:**

- Publicación de un debate.
- Edición con motivo.
- Versiones 1 y 2 en el historial, con identificación de la vigente.
- Diferencias por campo entre versiones.

**Por confirmación de la persona autora** (no se ven en las capturas): el resto de comprobaciones
del recorrido, es decir, editar sin cambios sin crear versión, bloqueo tras el primer aporte
también después de eliminarlo, aclaraciones (incluida la validación de longitud), instantánea
inicial y "Versión original desconocida" en datos anteriores, y revisión visual con texto
ampliado y pantalla estrecha.

**No comprobado manualmente:** el conflicto entre dos sesiones simultáneas (paso 3: un aporte
redactado sobre una versión que cambia antes de enviarlo). Su cobertura es solo automática:
`test_aportar_sobre_version_desactualizada_es_un_conflicto_controlado`,
`test_carreras_entre_edicion_y_aporte_dan_resultados_coherentes` y
`test_ordenes_deterministas_de_la_carrera` en `backend/tests/test_historial.py`, y la prueba de
conflicto que conserva el texto y no reintenta en `app/test/historial_test.dart`. No se le
atribuye ninguna prueba manual.

**Estado de 7B.1:** comprobado con esos límites. Pendiente: revisión de cambios, commit y push
(persona autora). 7C no ha empezado.

## Bloque 7C — fuentes con Crossref, redacción sin búsqueda y mayoría de edad (25/10/2026)

Punto de partida: `cb2de64` (7B.1) en `origin/main`, árbol limpio; CI en verde según la persona
autora. Sin subagentes, sin llamadas reales a Gemini ni a Crossref, sin commit, push, etiquetas
ni Releases. Diseño, enlaces oficiales consultados y límites en `docs/ARQUITECTURA.md` →
"Investigación asistida y mayoría de edad".

### Decisiones

- Descartado Grounding with Google Search: sus términos solo permiten mostrar resultados a quien
  consultó y prohíben modificarlos o mezclarlos, incompatible con fuentes públicas. La persona
  autora decidió no usarlo para campos públicos, catálogos de referencias ni otra base de datos.
- Referencias desde Crossref (metadatos reutilizables), separando "referencia localizada",
  "contenido consultado" y "afirmación respaldada". **Resúmenes desactivados** hasta aprobar una
  política de licencias: sin contenido consultado no hay afirmaciones respaldadas.
- Redacción con Gemini sin búsqueda, **desactivada por defecto** hasta revisar el tratamiento de
  datos (también del asistente existente).
- Público adulto (18+): declaración en el registro y confirmación obligatoria de las cuentas
  existentes (incluidas las administradoras), sin documentos ni fecha de nacimiento.
- `url_launcher` 6.3.3 autorizado por la persona autora (no está en el lock del curso; comprobado
  en pub.dev y con resolución en seco).

### Acciones realizadas (agente)

- Backend: `app/crossref.py` (cliente y normalización), `app/investigacion.py` (redacción y
  validación), `app/limites.py` (límites en memoria), `app/repositorios/investigacion.py`,
  `app/routers/investigacion.py`; declaración de edad en `security.py` y `routers/auth.py`;
  publicación de referencias y procedencia en debates y versiones; `CROSSREF_MAILTO` y
  `REDACCION_IA_ACTIVA` en `config.py`, `docker-compose.yml` y `.env.example` (el `.env` real no se
  leyó ni se modificó).
- Migración `0005` (nueva; `0001`–`0004` sin cambios).
- App: casilla de edad en el registro, `ConfirmarEdadScreen`, `InvestigacionScreen` desde el paso
  Contexto, fuentes en el detalle y en las versiones, apertura de enlaces con `url_launcher` y
  copia del enlace si falla.
- Error real encontrado y corregido durante las pruebas: las secciones de la pantalla de
  investigación no se actualizaban con los resultados (un `Obx` exterior no seguía lo leído al
  construir los widgets hijos); ahora cada sección tiene su propio `Obx`. También se aplazó la
  carga inicial para no modificar observables durante la construcción.

### Resultados verificados (agente, proveedores simulados)

| Comprobación | Resultado |
|---|---|
| `pytest -q` (Python 3.11 local) | 220 passed (184 + 36) |
| `pytest -q` en contenedor desechable `python:3.12-slim` | 220 passed |
| `flutter analyze` | No issues found |
| `flutter test` | 212 passed (190 + 22) |

Backend, 36 pruebas nuevas: 10 de edad (`test_edad.py`: `true` estricto con 6 valores inválidos,
registro sin declaración, cuentas pendientes —también administradora— con 403 salvo `/auth/me` y
confirmación, confirmación idempotente), 25 de investigación (`test_investigacion.py`:
configuración ausente, autenticación y aislamiento entre borradores, solo pregunta y ámbito hacia
Crossref, metadatos válidos, incompletos y hostiles, DOI inválidos o inexistentes, licencias con
esquemas inseguros, preprints como misma obra, errores de cuota, red y respuesta mal formada,
selección con metadatos del servidor, máximo de 8 referencias, límites por cuenta incluidas las
consultas por DOI, concurrencia, redacción sin resúmenes que descarta afirmaciones, contenido
hostil, aceptar, descartar y editar sin sobrescritura silenciosa, borrador desactualizado,
afirmación editada por revisar, publicación con fuentes en la versión, inmutabilidad, debates
anteriores sin fuentes) y 1 de migración `0005`.

Flutter, 22 pruebas nuevas (`test/investigacion_test.dart`): acceso opcional, diálogo con el
texto enviado, metadatos y avisos, añadir, abrir HTTPS a doi.org y copiar si falla, sin
resultados y error con reintento, búsqueda no configurada, redacción desactivada, aceptar con
vista previa y descartar conservando las demás, aviso al sustituir, fuentes y procedencia en el
detalle, debate anterior sin fuentes, publicación en el servidor simulado, pantalla estrecha y
texto ×2, duplicados, respuesta tardía tras cambiar de sesión, borrador cambiado durante la
redacción, 409 sin sobrescribir, y edad (registro, confirmación obligatoria, cerrar sesión, 403
con la app abierta).

Las respuestas de Crossref y Gemini de las pruebas son **simuladas** (marcadas "SIMULADA" o
sintéticas): no prueban la integración real.

### Ensayo de la migración 0005 (sin tocar el volumen real)

Sobre una copia temporal del respaldo `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7b1-20261025-205218.db`
(revisión `0003`): migración a `0005`, mismos recuentos (4 cuentas, 22 debates, 6 aportes, 3
borradores, 1 solicitud) y mismas huellas SHA-256 de cuentas, debates, aportes, borradores y
solicitudes; 22 versiones; ninguna cuenta con edad declarada (1 administradora y 3 usuarias
pendientes); ninguna referencia en debates, versiones ni borradores; `integrity_check` ok y
`foreign_key_check` vacío. Copia temporal eliminada. La base real (en `0004`) **no se migró**.

### Migración de la base real a 0005 (25/10/2026, autorizada por la persona autora)

1. **Pausa de uso:** se detuvo solo el servicio `api` (`docker compose stop api`; sin `down`, sin
   tocar otros servicios ni el volumen), de modo que nada pudo cambiar entre la copia y la
   migración. Diario de SQLite en modo `delete` (un único archivo, sin WAL).
2. **Respaldo nuevo** (no se sobrescribió ninguno anterior): copia del archivo con el servicio
   detenido y copia consistente con la API de copia de SQLite, fuera de Git:
   `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7c-20261025-230538.db`.
   Verificado: revisión `0004`, `integrity_check` ok, `foreign_key_check` vacío; 4 cuentas (1
   administradora, 3 usuarias), 23 debates, 24 versiones, 6 aportes (sin versión asignada: anteriores
   al historial), 0 aclaraciones, 4 borradores, 1 solicitud. La copia intermedia se eliminó.
3. **Ensayo 0004 → 0005** sobre una copia temporal de ese respaldo: revisión `0005`, integridad y
   claves foráneas sin errores, mismos recuentos y mismas huellas SHA-256 de cuentas (con roles),
   debates (con versión vigente, participación, bloqueos y archivo), versiones, aportes (con su
   vínculo de versión), aclaraciones, borradores y solicitudes; 0 cuentas con edad declarada; 0
   debates, versiones o borradores con datos de investigación. Copia temporal eliminada.
   Nota: la primera comparación dio "no conservados" porque la consulta de versiones usaba
   `SELECT *` y la revisión `0005` añade columnas (vacías); con columnas explícitas, todas las
   tablas coinciden. No se cambió ningún dato.
4. **Migración real:** `docker compose up --build -d api` (imagen `agora-joven-api:1.1-dev`).
   Servicio sano; revisión `0005`; mismas huellas que el respaldo en todas las tablas; 0 cuentas
   con edad declarada; ninguna referencia añadida; `integrity_check` ok y `foreign_key_check` vacío.
   `/health` 200; `/auth/me`, `/investigacion/estado` y `/debates` → 401 sin token. En el
   contenedor: `REDACCION_IA_ACTIVA=false` y `CROSSREF_MAILTO` vacío (se comprobó solo si está
   definido, sin mostrar su valor). Volumen `agora-joven_agora_datos` conservado. Las
   comprobaciones solo mostraron recuentos, estados y huellas.

**Restauración compatible** (si hiciera falta volver al estado previo a 7C):

```bash
cd backend
docker compose stop api
docker compose cp <ruta-del-respaldo-agora-pre-7c>.db api:/srv/data/agora.db
docker compose start api      # con el código actual, vuelve a migrar a 0005 conservando datos
```

Para quedarse en `0004` hay que usar también el código de esa revisión (`cb2de64`) antes de
arrancar; con el código actual, el arranque aplica `0005` de nuevo y todas las cuentas vuelven a
quedar pendientes de confirmar la edad. Copiar antes la base actual y no usar `down -v`.

### Procedimiento seguido (para futuras migraciones)

1. Copia consistente fuera de Git con la API de copia de SQLite (origen en solo lectura), desde
   el contenedor actual, como en los bloques anteriores, a
   `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7c-<fecha>.db`.
2. Verificarla: `integrity_check`, revisión `0004`, recuentos y huellas.
3. Ensayo sobre una copia temporal de ese respaldo con el código de 7C (debe dar `0005`, mismos
   datos, cuentas pendientes de edad, sin referencias) y eliminar la copia.
4. Solo entonces `docker compose up --build -d api` (sin `down -v`) y repetir las comprobaciones
   sobre el volumen. Tras migrar, **todas las cuentas** (también "Admin") deberán confirmar la
   edad al entrar.
5. Restauración, si hiciera falta: `docs/INSTALACION.md` → "Copias de seguridad y restauración".

### Pendiente: recorrido manual (persona autora)

No ejecutado por el agente en emulador. La base ya está migrada; requiere la app compilada con 7C.

1. Al entrar con una cuenta existente aparece "Antes de continuar": el botón está desactivado
   hasta marcar la casilla; "Cerrar sesión" funciona; al confirmar se llega a Inicio.
2. Registro de una cuenta nueva sin marcar la casilla: error junto a la casilla; con ella, se crea.
3. Sin `CROSSREF_MAILTO`: en el paso Contexto, "Fuentes e IA (opcional)" muestra que la búsqueda
   no está configurada y que la redacción está desactivada; el asistente funciona igual.
4. Con `CROSSREF_MAILTO` (prueba real pequeña, abajo): buscar, revisar el texto que se envía,
   añadir 1–2 referencias, abrir una en el navegador, quitar otra.
5. Cerrar la app por completo y retomar el borrador: las referencias siguen.
6. Publicar y abrir el debate con otra cuenta: "Fuentes indicadas por la persona autora" con el
   aviso de que no certifican nada; un debate anterior no muestra fuentes.
7. Revisión visual con texto ampliado y pantalla estrecha.

### Prueba real pequeña y controlada (persona autora, después de migrar)

1. Configurar en `backend/.env` (sin compartirlo) `CROSSREF_MAILTO=<correo de contacto>` y dejar
   `REDACCION_IA_ACTIVA=false`; recrear la API (`docker compose up -d api`).
2. Comprobar `GET /investigacion/estado` con una sesión: `busqueda_disponible: true`,
   `redaccion_disponible: false`.
3. Un único borrador de prueba con una pregunta neutra; **una** búsqueda y **una** selección por
   DOI (cuentan para el límite: 10 búsquedas y 20 consultas por hora).
4. Comprobar en la app que los metadatos coinciden con la página de `https://doi.org/<DOI>` (título,
   autores, año) y que no aparecen resúmenes.
5. Registrar el resultado aquí distinguiéndolo de las pruebas simuladas. La redacción con Gemini
   no se prueba hasta decidir el tratamiento de datos.

### Comprobación manual de la persona autora (emulator-5554, 25/10/2026)

La persona autora confirma **satisfactorio** el recorrido manual de 7C. Es evidencia de la persona
autora, no del agente (el agente no ejecutó la app ni consultó Crossref). La búsqueda usó Crossref
real con `CROSSREF_MAILTO` configurado por ella en el servidor.

**Visible en las capturas aportadas:**

- Confirmación de edad de una cuenta existente, con el botón desactivado antes de marcar la
  casilla y activado después.
- Funciones sin configurar (búsqueda no configurada y redacción desactivada).
- Publicación de un debate sin fuentes.
- Búsqueda real en Crossref con el diálogo previo que muestra el texto enviado.
- Resultados de la búsqueda.
- Selección de dos referencias y retirada de una.
- Debate publicado con la referencia restante.

**Por confirmación de la persona autora** (no se ven en las capturas): el resto de
comprobaciones previstas, incluidas la apertura de una referencia en el navegador y la
comparación de sus metadatos, la persistencia del borrador tras cerrar la app, la consulta desde
otra cuenta, el historial y la revisión visual (texto ampliado y pantalla estrecha).

**Estado:**

- Declaración de mayoría de edad: **comprobada** (pruebas automáticas y recorrido manual).
- Gestión de referencias con Crossref real (buscar, seleccionar, quitar, publicar y mostrar):
  **comprobada** (pruebas automáticas y recorrido manual con Crossref real).
- Redacción con Gemini sin búsqueda: **no validada con Gemini real**. Sigue desactivada
  (`REDACCION_IA_ACTIVA=false`) y solo se probó con proveedor simulado.
- Resúmenes: no se procesan ni se publican.

### Pendiente de decisión (persona autora)

- Política de licencias para procesar y publicar resúmenes.
- Tratamiento de datos según la configuración de Gemini (nivel gratuito o de pago), también para
  el asistente existente, antes de activar `REDACCION_IA_ACTIVA`.

## Cierre de la v1.1.0 (25/10/2026)

Decisión de la persona autora: la v1.1 se cierra con las funciones actuales; no se implementan 7D
ni funciones nuevas. Versión de la app: `1.1.0+2`; versión de la API: `1.1.0`.

**Alcance definitivo:** dashboard de comunidad y participación; creación guiada, borradores y
publicación; roles y archivo mediante revisión administrativa; historial y protección del
contexto de los aportes; declaración de 18 años o más; referencias bibliográficas de Crossref
(metadatos); asistente educativo existente.

**No entregado:** redacción con IA del asistente de creación (desactivada,
`REDACCION_IA_ACTIVA=false`, probada solo con proveedor simulado); procesamiento de resúmenes;
investigación científica automatizada; métricas de consenso. **Pendiente de revisión:** el
tratamiento de datos de Gemini (también del asistente educativo) y la política de licencias.

**Evidencias de 7C** (detalle en "Bloque 7C"):

- Pruebas automáticas del agente: backend 220, Flutter 212 (proveedores simulados).
- Capturas de la persona autora (emulator-5554): confirmación de edad con botón desactivado y
  activado; funciones sin configurar; publicación sin fuentes; búsqueda real en Crossref con
  diálogo previo; resultados; selección de dos referencias; retirada de una; debate publicado con
  la referencia restante.
- Confirmación de la persona autora: apertura y comparación de metadatos, persistencia del
  borrador, consulta desde otra cuenta, historial y revisión visual.
- Migración real a `0005` con respaldo previo
  `C:/Users/juanl/Documents/UTE/FORMACION/CEDIA-CURSO-FLOTTER-DART/respaldos-agora-joven/agora-pre-7c-20261025-230538.db`.

**Cambios de cierre (agente):** versión `1.1.0+2`; API `1.1.0`; notas de la Release en
`release.yml` (backend de la misma etiqueta, configuración de Crossref, firma de depuración,
pérdida de datos locales al desinstalar, 18+); README (alcance definitivo, instrucciones de la
v1.1.0 separadas de las de v1.0.0, limitaciones) y ALCANCE. Corregido en el README un carácter de
control introducido en una edición anterior (`agora-joven-v1.0.0\backend`).

**Validación final del agente (25/10/2026, sobre `afd2e9b` + cambios de cierre):**
`flutter pub get --enforce-lockfile` sin cambios; `flutter analyze` sin incidencias; `flutter test`
212 passed; backend en contenedor `python:3.12-slim` (Python 3.12.15) 220 passed; APK release
local para el emulador (`flutter build apk --release
--dart-define=API_BASE_URL=http://10.0.2.2:8010`) compilado, 53,9 MB, en `app/build/` (ignorado
por Git; no se versiona ni se publica). Sin dependencias actualizadas ni llamadas reales a
proveedores. Revisión del diff: sin secretos, bases, respaldos ni APK.

**Reorganización de la documentación (25/10/2026, agente; solo documentación):** el README se
sintetizó para quien descubre o evalúa el proyecto. La instalación por versión, la compatibilidad,
los volúmenes, la restauración y el procedimiento de v1.0.0 (pasos A1–A7) pasaron a
`docs/INSTALACION.md`; el desarrollo local, los comandos, los ejemplos de API (corregidos con la
declaración de edad y la versión del aporte), las pruebas, la seguridad y las tecnologías, a
`docs/DESARROLLO.md`; la galería de capturas, a `docs/CAPTURAS.md`; la lista completa de
limitaciones, a `docs/ALCANCE.md`; las decisiones técnicas, a `docs/ARQUITECTURA.md`. Las
referencias anteriores de este documento a secciones del README (pasos A1–A7, "Limitaciones
conocidas") corresponden ahora a esas guías.

**Publicación (observada por el agente el 25–26/10/2026, sin validarla):** la persona autora
publicó el commit `382e5f8` ("chore: cierre de la versión 1.1.0") y la etiqueta `v1.1.0`, que en el
remoto apunta a `382e5f8`. La página pública de la Release `v1.1.0` existe, publicada por
`github-actions`, con 4 archivos adjuntos (sus nombres no se pudieron leer). El agente no comprobó
el resultado del CI ni descargó o probó el APK.

**Pendiente (persona autora):** descargar y probar el APK publicado con el backend de la etiqueta;
publicar la reorganización de la documentación; envío en Moodle. El proyecto **no está marcado
como entregado**.

## Decisiones registradas (2026-10-22)

- Se mantiene `flutter_lints ^6.0.0`.
- Debates y aportes requieren sesión; públicos solo `/health`, `/auth/registro`, `/auth/login`.
- IA: Gemini vía backend propio, clave solo en el servidor, sin modo de demostración.
- Bloque 5: Gemini por REST con `urllib` (sin SDK); modelo `gemini-3.5-flash-lite`; campo
  `accion` (antes `modo` en el contrato inicial); 429/502/503 diferenciados.
- Bloque 1: tablas con `create_all` (sin Alembic); orden del catálogo por `id`; correo duplicado
  → 400 explícito; arranque con `uvicorn app.main:create_app --factory`.

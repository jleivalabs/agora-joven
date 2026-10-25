# Arquitectura — Ágora Joven

> Estado: el backend implementa `/health`, autenticación y catálogo (Bloque 1). La app implementa
> sesión (registro, acceso, restauración, cierre) y catálogo con detalle (Bloque 2). Aportes
> compartidos en backend y app (Bloque 3). Debates guardados con Hive (Bloque 4). Asistente
> educativo con Gemini vía backend (Bloque 5; validado con proveedor simulado, integración real
> pendiente).

## Vista general

```
┌──────────────── App Flutter (app/) ────────────────┐        ┌──────── Backend (backend/) ────────┐
│ screens/      Pantallas y widgets (sin HTTP)       │        │ FastAPI                             │
│     │ Obx / Get.find                               │        │  routers/ → repositorios/ → models  │
│ controllers/  GetxController (estado compartido)   │        │             │                       │
│     │                                              │  HTTP  │  SQLite persistente (volumen)       │
│ repositories/ Reglas de acceso y mapeo a modelos   │ ─────► │  JWT (firma con secreto en .env)    │
│     │                                              │  JSON  │  Asistente → Gemini (REST)          │
│ data/         ApiClient (Dio) · TokenStorage       │        │  (clave solo en el servidor)        │
│               (flutter_secure_storage) · Hive      │        └─────────────────────────────────────┘
└────────────────────────────────────────────────────┘
```

Regla: una pantalla solo habla con controladores; un controlador solo con repositorios; solo
`data/` conoce Dio o `flutter_secure_storage`. Comprobado con búsqueda en `lib/screens` y
`lib/controllers`: no importan Dio ni el almacenamiento seguro.

## Capas de la app

| Pantalla (`screens/`) | Controlador GetX | Repositorio | Fuente de datos | Estado |
|---|---|---|---|---|
| `RaizScreen` (elige según la sesión) | `SesionController` | `AuthRepository` | `ApiClient`, `TokenStorage` | ✅ |
| `LoginScreen`, `RegistroScreen` | `SesionController` | `AuthRepository` | `ApiClient`, `TokenStorage` | ✅ |
| `DebatesScreen` (lista + filtro) | `DebatesController` | `DebatesRepository` | `ApiClient` | ✅ |
| `DetalleDebateScreen` | `DetalleDebateController` (uno por debate) | `DebatesRepository` | `ApiClient` | ✅ |
| Sección de aportes (en el detalle) + `AporteFormScreen` | `AportesController` (uno por debate) | `AportesRepository` | `ApiClient` | ✅ |
| `GuardadosScreen` + marcador en el detalle | `GuardadosController` (global) | `GuardadosRepository` | `HiveAlmacenGuardados` (caja por usuario) | ✅ |
| `SeccionAsistente` (en el detalle) | `AsistenteController` (uno por debate) | `AsistenteRepository` | `ApiClient` | ✅ |

Widgets comunes: `EstadoCargando`, `EstadoVacio`, `EstadoError` (con reintentar y acción
secundaria), `Marca` y `Aviso`. `setState` solo se usa para estado local de un formulario
(mostrar u ocultar la contraseña); el estado compartido vive en controladores.

`DebatesScreen` y `DetalleDebateScreen` crean su controlador al aparecer y lo eliminan al
desaparecer: al cerrar sesión no quedan datos del usuario anterior en memoria.

### Sesión

- Arranque: `SesionController.restaurar()` lee el token y lo valida con `GET /auth/me`.
  Sin token → acceso. 401 → borra el token y avisa "Tu sesión caducó". Red, tiempo agotado o 5xx →
  conserva el token y muestra "Reintentar" o "Iniciar sesión con otra cuenta".
- Login: `POST /auth/login` → `GET /auth/me` → guardar token. Si guardar falla, no se inicia la
  sesión y se informa. Solo se guarda el token; nunca la contraseña.
- Registro: no inicia sesión; vuelve al acceso con aviso y el correo ya escrito.
- Cierre: borra el token, limpia el usuario, elimina los controladores del catálogo y cierra todas
  las pantallas apiladas (`popUntil(isFirst)`). La raíz pasa a mostrar el acceso, así que Atrás
  no puede volver a pantallas protegidas.

### Protección ante respuestas tardías

- `SesionController` mantiene un **contador de sesión** que aumenta al empezar una restauración o
  un login, y al cerrar o caducar la sesión.
- Cada operación captura el contador al empezar y, tras cada espera (incluidos errores y
  `finally`), solo aplica resultados si no cambió. Un login o una restauración pendientes no
  pueden reactivar una sesión invalidada; si el token ya se escribió, se borra solo si sigue
  siendo el suyo (`borrarTokenSiEs`).
- Las operaciones autenticadas pasan por `SesionController.ejecutar`: un 401 cierra la sesión solo
  si pertenece a la sesión vigente, y como el contador cambia al primer 401, los siguientes 401
  simultáneos se ignoran (un único aviso y una única redirección).
- El 401 de `POST /auth/login` no pasa por `ejecutar`: significa credenciales incorrectas, no
  sesión caducada.
- `DebatesController` y `DetalleDebateController` numeran sus peticiones: si se cambia rápido de
  categoría, solo se aplica la respuesta de la última.

### Aportes en la app

- La sección de aportes vive en el detalle. Si falla su carga, el contexto del debate sigue visible
  y la sección ofrece "Reintentar". Se actualiza con el botón "Actualizar aportes" o deslizando.
- `AportesController` (etiqueta = id del debate) pasa todas las operaciones por
  `SesionController.ejecutar` y numera las cargas; además, al cerrarse la pantalla deja de aplicar
  respuestas (`_activo`). El formulario solo se cierra si la operación tuvo éxito en la sesión
  vigente y sigue abierto.
- Crear o editar coloca el aporte por id (reemplaza o inserta al principio): nunca duplica. Editar
  envía solo los campos cambiados; sin cambios no llama al servidor.
- Eliminar pide confirmación y solo retira el aporte cuando el servidor responde 204 (o 404: ya no
  existía). Mientras tanto muestra progreso en esa tarjeta.
- Editar y Eliminar solo se muestran si `es_propio`; es cortesía de interfaz, la autorización la
  aplica el servidor (403).
- Publicar **no se reintenta solo**: ante desconexión o tiempo agotado se avisa de que pudo
  guardarse y se pide actualizar la lista antes de repetir. El texto del formulario se conserva.

### Debates guardados (Hive)

- Fuente de datos: `lib/data/guardados_local.dart` (`AlmacenGuardados` / `HiveAlmacenGuardados`).
  Una caja por cuenta, `guardados_<id_usuario>`, con clave = id del debate (sin duplicados). Hive
  se inicializa en `main.dart` con `Hive.initFlutter()`; solo `data/` y `main.dart` importan Hive.
- Se guarda solo `id`, `titulo`, `categoria`, `etiqueta_categoria` y `guardado_en`. Nada de
  tokens, credenciales ni aportes. El detalle se pide siempre al backend (flujo remoto existente).
- Cerrar sesión no borra las cajas: los guardados se conservan para esa cuenta. Al cambiar de
  usuario, `GuardadosController` limpia la lista visible y carga solo la caja de la nueva cuenta.
- Cada operación captura un contador de cuenta: si la cuenta cambia mientras espera, su
  resultado no se muestra (la escritura termina en la caja de la cuenta que la pidió). Las
  lecturas se numeran; si un guardado termina durante una lectura, se relee.
- Un fallo de escritura no marca el debate como guardado (o no lo quita) y se avisa. Un fallo de
  lectura muestra error con Reintentar sin borrar datos. Los registros dañados se omiten al leer,
  sin borrarlos.
- La lista de guardados se lee localmente aunque el backend falle (sesión ya activa). No hay
  modo sin conexión ni sincronización.

### Errores

`ApiClient` convierte errores de Dio en `ApiException` tipado. `mensajeDeError` da un texto en
español distinto para: sin conexión, tiempo agotado, 400, 401, 403, 404, 422, 5xx y respuesta
inesperada. Nunca se muestra el `detail` del servidor; en 422 solo se usan los nombres de los
campos (`Revisa el correo.`). Algunos casos tienen texto propio según el contexto: 401 en login,
400 en registro (correo duplicado) y 404 en el detalle.

### Red y Android

- `API_BASE_URL` por `--dart-define` (por defecto `http://10.0.2.2:8010`, emulador → equipo).
- Límites: conexión 8 s, envío 10 s, recepción 15 s (`lib/config/app_config.dart`).
- Sin interceptores de registro: no se registran cuerpos, contraseñas, tokens ni `Authorization`.
- `AndroidManifest.xml` (main): permiso `INTERNET` (también en release); `networkSecurityConfig`
  permite HTTP en claro **solo** hacia `10.0.2.2`, `localhost` y `127.0.0.1` (configuración de
  práctica; para un dispositivo físico hay que añadir la IP del equipo o usar HTTPS);
  `allowBackup="false"`, `fullBackupContent="false"` y `dataExtractionRules` excluyen los datos de
  la app de la copia en la nube y de la transferencia entre dispositivos (el token cifrado depende
  de una clave del Keystore que no viaja con la copia).

## Modelos

`Usuario`, `Debate` y `Aporte` están implementados (`backend/app/models.py`).

**Usuario**
| Campo | Tipo | Notas |
|---|---|---|
| id | int | |
| nombre | str (2–60) | Nombre visible en los aportes |
| email | str | Normalizado (sin espacios, minúsculas) y único en la base; solo lo ve su dueño |
| password_hash | str | Solo en el servidor (Argon2); nunca se devuelve |
| creado_en | datetime (UTC) | |

**Debate**
| Campo | Tipo | Notas |
|---|---|---|
| id | int | |
| slug | str único | Clave estable del archivo editorial; permite recargar sin duplicar. No se expone en la API |
| titulo | str | |
| categoria | enum | p. ej. educacion, ambiente, movilidad, empleo, salud, tecnologia, cultura, participacion |
| resumen | str | Para la lista |
| contexto | str | Texto explicativo para el detalle |
| perspectivas | lista de {titulo, descripcion} | Al menos dos enfoques distintos |
| origen | str | Siempre "Material editorial de demostración" en la semilla |
| actualizado_en | datetime | |

**Aporte**
| Campo | Tipo | Notas |
|---|---|---|
| id | int | |
| debate_id | int | FK a Debate |
| autor_id | int | FK a Usuario; lo asigna el servidor desde el token, nunca el cliente. **No se devuelve** |
| autor_nombre | str | Solo en respuestas (nombre visible; nunca el correo) |
| tipo | enum | pregunta, argumento, propuesta |
| texto | str (10–1000) | Longitud comprobada tras quitar espacios exteriores |
| creado_en / editado_en | datetime | `editado_en` nulo si no se editó; solo cambia si un PATCH modifica algo |
| es_propio | bool | Calculado en el servidor en cada respuesta para quien consulta |

Índice `(debate_id, creado_en, id)` para el orden de la lista. La tabla se añadió con
`create_all`, que crea solo las tablas que faltan: usuarios y debates existentes no se tocan.

## Contrato de endpoints

Base: `http://<host>:8010` (Docker Compose). Errores con el formato estándar de FastAPI
(`{"detail": "mensaje"}`; en 422, `detail` es la lista de errores de validación).

Solo son públicos `GET /health`, `POST /auth/registro` y `POST /auth/login`. **Todo lo demás,
incluido `GET /auth/me`, exige un token válido** (`Authorization: Bearer <token>`). Sin token, con
otro esquema, mal formado, con firma alterada, sin algoritmo, caducado o de un usuario que ya no
existe, la respuesta es 401 `Sesión no válida o caducada. Inicia sesión de nuevo.` con la cabecera
`WWW-Authenticate: Bearer`.

| Método y ruta | Estado | Uso | Respuestas |
|---|---|---|---|
| `GET /health` | ✅ | Salud del servicio | 200 `{status, servicio}` |
| `POST /auth/registro` | ✅ | `{nombre (2–60), email, password (8–128)}` | 201 `{id, nombre, email, creado_en}` · 400 `Ya existe una cuenta con ese correo.` · 422 |
| `POST /auth/login` | ✅ | `{email, password}` | 200 `{access_token, token_type: "bearer", expira_en}` · 401 `Correo o contraseña incorrectos.` · 422 campos vacíos |
| `GET /auth/me` | ✅ | Usuario del token | 200 `{id, nombre, email, creado_en}` · 401 |
| `GET /debates/categorias` | ✅ | Las 8 categorías en orden fijo, con `etiqueta` y `total` (puede ser 0) | 200 · 401 |
| `GET /debates?categoria=` | ✅ | Lista resumida `{id, titulo, categoria, resumen, origen}`, orden por `id` ascendente | 200 (lista vacía si la categoría no tiene debates) · 401 · 422 categoría desconocida |
| `GET /debates/{id}` | ✅ | Detalle: resumen + `contexto`, `perspectivas[{titulo, descripcion}]`, `actualizado_en` | 200 · 401 · 404 `Debate no encontrado.` · 422 id no numérico |
| `GET /debates/{id}/aportes` | ✅ | Aportes del debate, `creado_en` descendente con desempate por `id` descendente; sin paginación | 200 · 401 · 404 debate |
| `POST /debates/{id}/aportes` | ✅ | Crear `{tipo, texto}`; cualquier otro campo (`autor_id`, `debate_id`…) → 422 | 201 aporte · 401 · 404 debate · 422 |
| `PATCH /aportes/{id}` | ✅ | Editar el propio `{tipo?, texto?}`: al menos uno, sin `null`, sin campos extra | 200 · 401 · **403 si no es el autor** · 404 · 422 |
| `DELETE /aportes/{id}` | ✅ | Eliminar el propio | 204 sin cuerpo · 401 · **403** · 404 |
| `POST /asistente/debates/{id}` | ✅ | `{accion: "contexto" \| "perspectivas"}` → `{debate_id, accion, estado, texto, aviso, aportes_usados, aportes_totales, parcial, truncado}`; `estado` = `generado` o `sin_aportes` | 200 · 401 · 404 · 422 · 429 límite del proveedor · 502 respuesta vacía o bloqueada · 503 no configurado o no disponible |

Valores de `categoria`: `educacion`, `ambiente`, `movilidad`, `empleo`, `salud`, `tecnologia`,
`cultura`, `participacion`.

El cierre de sesión es local (se borra el token); el JWT expira por tiempo. Un correo duplicado
responde 400 con un mensaje explícito: se acepta que esto revela si un correo está registrado, a
cambio de un mensaje claro en el registro.

### Autenticación (implementación)

- Contraseñas con Argon2id (`pwdlib`). Nunca se devuelven ni se registran la contraseña o su hash.
  Si el correo no existe, se verifica contra un hash señuelo para no responder más rápido.
- JWT HS256 con `sub`, `iat` y `exp` obligatorios; el algoritmo se fija al verificar (se rechaza
  `alg: none` y cualquier otro). Caducidad: `JWT_EXPIRA_MINUTOS` (60 por defecto).
- `JWT_SECRET` se lee del entorno del servidor; es obligatorio, de al menos 32 caracteres y no tiene
  valor por defecto: sin él la app no arranca y Docker Compose no se ejecuta.
- Uvicorn solo registra método, ruta y código; no se registran cabeceras ni cuerpos. Ningún
  endpoint recibe el token por la URL.

### Código del backend

```
backend/app/
├── main.py             create_app(): ciclo de vida (tablas + carga del catálogo) y routers
├── config.py           Settings (variables de entorno)
├── db.py               motor SQLite (PRAGMA foreign_keys=ON), sesiones, get_db
├── models.py           Usuario, Debate, Categoria
├── schemas.py          validación de entrada y forma de las respuestas
├── security.py         Argon2, JWT y dependencia usuario_actual
├── repositorios/       consultas a la base (usuarios, debates, aportes)
├── routers/            auth.py, debates.py, aportes.py (propiedad comprobada → 403), asistente.py
├── asistente.py        acciones, instrucciones, selección de aportes y límites del asistente
├── ia.py               cliente REST de Gemini (urllib) y clasificación de fallos
├── catalogo.py         carga idempotente del catálogo (también: python -m app.catalogo)
└── datos/debates.json  20 debates editoriales
```

## Asistente (Bloque 5)

Implementado y validado **solo con un proveedor simulado**; la llamada real a Gemini está pendiente
de comprobar (ver `docs/SEGUIMIENTO.md`).

**Proveedor y modelo.** Gemini API por REST: `POST {base}/v1beta/models/{modelo}:generateContent`
con la cabecera `x-goog-api-key` (documentación oficial de ai.google.dev consultada el 24/10/2026).
Modelo por defecto `gemini-3.5-flash-lite`: estable, recomendado por Google para proyectos nuevos
junto a `gemini-3.8-flash`, de bajo coste y latencia, con razonamiento mínimo por defecto, y es el
mismo que usa el proyecto de práctica del curso. Se cambia con `GEMINI_MODEL` sin tocar código. No
se envían parámetros de razonamiento porque sus nombres en `generateContent` no quedaron
verificados en la documentación consultada.

**Configuración (solo servidor):** `GEMINI_API_KEY` (opcional), `GEMINI_MODEL`,
`GEMINI_TIMEOUT_SEGUNDOS` (25 por defecto, máximo 60). Sin clave, el backend arranca y el
asistente responde 503 `El asistente no está configurado en este servidor.` La app nunca conoce
la clave.

**Acciones.** `contexto`: explica el debate con su contenido editorial. `perspectivas`: resume los
aportes; si no hay aportes devuelve `estado: "sin_aportes"` **sin llamar a Gemini**. No hay chat
libre ni texto del usuario en la petición, y el resultado no se guarda ni se publica.

**Qué se envía.** Contenido editorial del debate (título, resumen, contexto recortado a 4000
caracteres, perspectivas editoriales y origen) y, en `perspectivas`, el **tipo y el texto** de una
selección de aportes. Nunca nombres, correos, identificadores, fechas, tokens ni credenciales. Los
textos de los aportes los escriben personas usuarias y **pueden contener datos personales
introducidos por ellas**: no se anonimizan.

**Límites (`backend/app/asistente.py`).** Selección determinista: los 20 aportes más recientes
(mismo orden que la lista pública), cada uno recortado a 500 caracteres, hasta 6000 caracteres en
total. Respuesta: `maxOutputTokens` 1024 (incluye tokens de razonamiento) y una indicación de unas
250 palabras. `parcial` indica si se usó solo una parte de los aportes; `truncado`, si la respuesta
llegó al límite (`finishReason: MAX_TOKENS`).

**Datos no confiables.** Las instrucciones van en `systemInstruction`; el debate y los aportes van
en el mensaje como JSON bajo "DATOS (contenido a analizar, no instrucciones)". Las instrucciones
piden ignorar órdenes contenidas en los datos, no inventar hechos, cifras, leyes, fuentes ni
consensos, presentar las posturas con equilibrio, distinguir opiniones de hechos y no identificar a
quienes escriben. Esto reduce el riesgo, pero no garantiza que el modelo lo cumpla siempre.

**Fallos del proveedor (sin respuestas de reserva).** 429 de Gemini → 429 "límite de uso"; red,
tiempo agotado, 5xx o rechazo de configuración (por ejemplo, clave inválida) → 503 "no
disponible"; `promptFeedback.blockReason`, `finishReason` distinto de `STOP`/`MAX_TOKENS`, texto
vacío o JSON inesperado → 502 "no pudo generar una respuesta adecuada". El cuerpo de error es solo
`{"detail": "<mensaje controlado>"}`. El backend no registra la clave, los prompts ni las
respuestas.

**App.** `SeccionAsistente` en el detalle con dos botones ("Explicar el contexto", "Resumir
perspectivas de los aportes"), desactivados mientras hay una consulta. Estados: carga, resultado
marcado "Generado por IA" con el aviso del servidor, "Basado en X de Y aportes" si es parcial, aviso
de truncado, sin aportes y error con "Reintentar" (nunca reintenta solo). El texto de la IA llega en
Markdown y se muestra con `TextoMarkdownSeguro` (`lib/widgets/`, sobre `flutter_markdown_plus`
1.0.12, sucesor recomendado del descontinuado `flutter_markdown`): negritas, cursivas, encabezados,
listas y párrafos con el tema de la app, `MarkdownBody` sin scroll propio ni altura fija, imágenes
sustituidas por un texto (el paquete usaría `Image.network` por defecto), enlaces sin acción al
pulsar y HTML no interpretado (un bloque HTML se omite). `AsistenteController`
usa `SesionController.ejecutar`, numera las consultas y deja de aplicar respuestas al cerrarse la
pantalla. La espera de la app para esta petición es de 40 s (el backend espera hasta 25 s a Gemini).

## Persistencia

| Dónde | Tecnología | Motivo |
|---|---|---|
| Backend (implementado) | SQLite en el volumen Docker `agora_datos` (`/srv/data/agora.db`), con claves foráneas activadas | Sin servicio extra que levantar; suficiente para la escala del proyecto. Se descartó Postgres (más pasos para quien evalúa). Las tablas se crean con `create_all` al arrancar; no hay migraciones (Alembic) porque los bloques siguientes solo añaden tablas nuevas. |
| App, guardados | Hive (caja por usuario) | Mismo patrón practicado en el curso; sobrevive al cierre completo. |
| App, token | `flutter_secure_storage` | Requisito del curso: el token no va en Hive ni en preferencias. |

## Catálogo editorial

- Fuente: `backend/app/datos/debates.json`, 20 debates en 8 categorías, todos con
  `origen: "Material editorial de demostración"`, contexto y al menos dos perspectivas con títulos
  distintos. Redacción propia, sin cifras ni afirmaciones legales.
- Carga: al arrancar la API y con `python -m app.catalogo`. Valida el archivo antes de escribir.
  Identifica cada debate por `slug`: inserta los nuevos y actualiza los cambiados; nunca borra
  debates ni toca usuarios. Ejecutarla de nuevo no duplica nada.

## Dependencias

- Backend (Bloque 1, versiones del lock del curso): `sqlalchemy` 2.1.1 (acceso a SQLite), `pyjwt`
  2.15.1 (tokens), `pwdlib[argon2]` 0.3.1 (hash Argon2id), `pydantic-settings` 2.15.0 (configuración
  desde el entorno), `email-validator` 2.3.0 (validación de correo en el registro).
- App (Bloque 2, mismas versiones que ExploraEC, fijadas exactas en `pubspec.yaml`): `dio` 5.11.1
  (HTTP con límites de tiempo y adaptador sustituible en pruebas), `flutter_secure_storage` 11.2.0
  (token cifrado con Keystore; exige minSdk 24, igual al mínimo de Flutter 3.47.5).
- App (Bloque 4, versiones de ExploraEC, fijadas exactas): `hive` 2.2.3 y `hive_flutter` 1.1.0
  (este último trae `path_provider` 2.1.6, la misma versión que en ExploraEC). No se actualizó
  ninguna otra dependencia.
- Asistente (Bloque 5): **sin dependencias nuevas**. Gemini se llama por REST con `urllib` de la
  biblioteca estándar; no se instaló el SDK de Google.

## Python: local frente a contenedor

- Contenedor (referencia de ejecución): `python:3.12-slim`, comprobado Python 3.12.15.
- Entorno local de desarrollo y pruebas: Python 3.11.9 en `backend/.venv` (no hay 3.12 instalado).
- Una prueba que pasa en local no demuestra que el contenedor funcione; el contenedor se valida
  aparte (ver `docs/SEGUIMIENTO.md`).

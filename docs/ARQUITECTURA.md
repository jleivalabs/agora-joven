# Arquitectura — Ágora Joven

> Estado: el backend implementa `/health`, autenticación y catálogo (Bloque 1). La app implementa
> sesión (registro, acceso, restauración, cierre) y catálogo con detalle (Bloque 2). Aportes
> compartidos en backend y app (Bloque 3). Debates guardados con Hive (Bloque 4). Asistente
> educativo con Gemini vía backend (Bloque 5). CI y Release v1.0.0 (Bloque 6). **v1.1 en
> desarrollo:** dashboard de inicio (Bloque 7A).

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
| `PrincipalScreen` (navegación Inicio · Debates · Guardados) | `PrincipalController` | — | — | ✅ 7A |
| `InicioScreen` (dashboard) | `InicioController` | `EstadisticasRepository` | `ApiClient` | ✅ 7A |
| `LoginScreen`, `RegistroScreen` | `SesionController` | `AuthRepository` | `ApiClient`, `TokenStorage` | ✅ |
| `DebatesScreen` (lista + filtro) | `DebatesController` | `DebatesRepository` | `ApiClient` | ✅ |
| `DetalleDebateScreen` | `DetalleDebateController` (uno por debate) | `DebatesRepository` | `ApiClient` | ✅ |
| Sección de aportes (en el detalle) + `AporteFormScreen` | `AportesController` (uno por debate) | `AportesRepository` | `ApiClient` | ✅ |
| `GuardadosScreen` + marcador en el detalle | `GuardadosController` (global) | `GuardadosRepository` | `HiveAlmacenGuardados` (caja por usuario) | ✅ |
| `SeccionAsistente` (en el detalle) | `AsistenteController` (uno por debate) | `AsistenteRepository` | `ApiClient` | ✅ |
| `CrearDebateScreen` (asistente de 6 pasos; también edición) | `CrearDebateController` | `BorradoresRepository`, `DebatesRepository` | `ApiClient` | ✅ 7B |
| `MisDebatesScreen` (borradores, publicados, archivados) | `MisDebatesController` | `DebatesRepository`, `BorradoresRepository`, `SolicitudesRepository` | `ApiClient` | ✅ 7B |
| `AdminSolicitudesScreen`, `AdminSolicitudScreen` (solo administración) | `AdminSolicitudesController` | `SolicitudesRepository` | `ApiClient` | ✅ 7B (ajuste) |
| `HistorialScreen`, `VersionScreen` | `HistorialController`, `VersionController` | `DebatesRepository` | `ApiClient` | ✅ 7B.1 |

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

`Usuario`, `Debate` y `Aporte` están implementados (`backend/app/models.py`). Las columnas y tablas
añadidas en 7B (`borradores`, `solicitudes_archivo`, estado y origen del archivo) se describen en
"Debates de usuarios".

**Usuario**
| Campo | Tipo | Notas |
|---|---|---|
| id | int | |
| nombre | str (2–60) | Nombre visible en los aportes |
| email | str | Normalizado (sin espacios, minúsculas) y único en la base; solo lo ve su dueño |
| password_hash | str | Solo en el servidor (Argon2); nunca se devuelve |
| creado_en | datetime (UTC) | |
| rol | `usuario` \| `administrador` | Migración 0003. Nunca se asigna desde la API; ver "Roles" en "Debates de usuarios" |

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
| `POST /auth/registro` | ✅ | `{nombre (2–60), email, password (8–128)}`; cualquier otro campo (`rol`…) → 422. Siempre crea rol `usuario` | 201 `{id, nombre, email, creado_en, rol}` · 400 `Ya existe una cuenta con ese correo.` · 422 |
| `POST /auth/login` | ✅ | `{email, password}` | 200 `{access_token, token_type: "bearer", expira_en}` · 401 `Correo o contraseña incorrectos.` · 422 campos vacíos |
| `GET /auth/me` | ✅ | Usuario del token (rol leído de la base) | 200 `{id, nombre, email, creado_en, rol}` · 401 · 405 a `PATCH`/`PUT` (no hay edición de perfil) |
| `GET /debates/categorias` | ✅ | Las 8 categorías en orden fijo, con `etiqueta` y `total` de debates **activos** (puede ser 0) | 200 · 401 |
| `GET /debates?categoria=` | ✅ | Debates **publicados** (no archivados): `{id, titulo, categoria, resumen, origen, procedencia, estado, autor_nombre}`, orden por `id` ascendente | 200 (lista vacía si la categoría no tiene debates) · 401 · 422 categoría desconocida |
| `GET /debates/{id}` | ✅ | Detalle (también archivados): resumen + `contexto`, `perspectivas[{titulo, descripcion}]`, `actualizado_en`, `ambito`, `objetivo`, `publicado_en`, `archivado_en`, `archivo_origen`, `aportes`, `es_propio`, `editable` y, solo para la cuenta autora, `solicitud_archivo` | 200 · 401 · 404 `Debate no encontrado.` · 422 id no numérico |
| `PUT /debates/{id}` | ✅ 7B / 7B.1 | Editar el propio: contenido completo + `motivo` (10–500). Crea versión si cambia algo; solo si nunca recibió aportes y sin bloqueo histórico | 200 (también sin cambios, sin versión nueva) · 401 · 403 no es autor, editorial o administración · 404 · 409 archivado, con participación o protegido · 422 |
| `GET /debates/{id}/versiones` | ✅ 7B.1 | Versiones publicadas (más reciente primero): `{numero, tipo, creada_en, autor_nombre, motivo, campos_cambiados, es_actual}` | 200 · 401 · 404 |
| `GET /debates/{id}/versiones/{numero}` | ✅ 7B.1 | Contenido de la versión + `cambios[{campo, antes, despues}]` respecto a la anterior | 200 · 401 · 404 |
| `POST /debates/{id}/aclaraciones` | ✅ 7B.1 | Aclaración del autor `{texto (10–1000)}`; inmutable, no crea versión | 201 · 401 · 403 · 404 · 409 archivado · 422 |
| `POST /debates/{id}/archivar` | ✅ 7B (ajuste) | **Solo administración**: archivo directo `{motivo (10–500)}` | 200 · 401 · **403 cualquier otra cuenta, también la autora** · 404 · 409 ya archivado · 422 |
| `POST /debates/{id}/solicitud-archivo` | ✅ 7B (ajuste) | El autor solicita archivar `{motivo}`; no archiva | **201** nueva · **200** ya había una pendiente (la misma) · 401 · 403 no es autor · 404 · 409 archivado · 422 |
| `GET /solicitudes-archivo` · `GET /solicitudes-archivo/{id}` | ✅ 7B (ajuste) | Solicitudes propias con estado y `respuesta` | 200 · 401 · 404 si es ajena |
| `POST /solicitudes-archivo/{id}/cancelar` | ✅ 7B (ajuste) | Cancelar la propia pendiente | 200 (también si ya estaba cancelada) · 401 · 404 · 409 ya resuelta |
| `GET /admin/solicitudes-archivo?estado=` | ✅ 7B (ajuste) | Administración: por defecto pendientes (más antiguas primero); nombres, nunca correos | 200 · 401 · 403 |
| `GET /admin/solicitudes-archivo/{id}` | ✅ 7B (ajuste) | Registro completo de una solicitud | 200 · 401 · 403 · 404 |
| `POST /admin/solicitudes-archivo/{id}/aprobar` · `…/rechazar` | ✅ 7B (ajuste) | `{justificacion (10–500)}`; aprobar archiva en la misma transacción | 200 · 401 · 403 · 404 · 409 ya resuelta o cancelada · 422 |
| `GET /borradores` · `POST /borradores` | ✅ 7B | Borradores pendientes de la cuenta del token · crear (campos opcionales) | 200 · 201 · 401 · 422 |
| `GET` · `PATCH` · `DELETE /borradores/{id}` | ✅ 7B | Leer, guardar cambios parciales, eliminar el propio | 200 · 204 · 401 · **404 si es ajeno** · 409 ya publicado · 422 |
| `POST /borradores/{id}/publicar` | ✅ 7B | Valida y convierte el borrador en debate | **201** primera vez · **200** repetición (mismo debate) · 401 · 404 · 422 incompleto |
| `GET /mis-debates` | ✅ 7B | `{borradores, publicados, archivados}` de la cuenta del token | 200 · 401 |
| `GET /debates/{id}/aportes` | ✅ | Aportes del debate, `creado_en` descendente con desempate por `id` descendente; sin paginación. Incluye `version` (nula si es anterior al historial) | 200 · 401 · 404 debate |
| `POST /debates/{id}/aportes` | ✅ | Crear `{tipo, texto, version}` (7B.1: `version` obligatoria); cualquier otro campo (`autor_id`, `debate_id`…) → 422 | 201 aporte · 401 · 404 debate · 409 debate archivado (7B) · **409 `version_desactualizada`** (7B.1) · 422 (también versión de otro debate) |
| `PATCH /aportes/{id}` | ✅ | Editar el propio `{tipo?, texto?}`: al menos uno, sin `null`, sin campos extra | 200 · 401 · **403 si no es el autor** · 404 · 422 |
| `DELETE /aportes/{id}` | ✅ | Eliminar el propio | 204 sin cuerpo · 401 · **403** · 404 |
| `GET /estadisticas/comunidad` | ✅ 7A | Cifras públicas agregadas (ver "Dashboard") | 200 · 401 |
| `GET /estadisticas/mias` | ✅ 7A | Participación de la cuenta **del token**; no admite identificadores | 200 · 401 |
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

## Dashboard (Bloque 7A, v1.1)

**Navegación.** Tras iniciar sesión, `PrincipalScreen` muestra una barra inferior con Inicio,
Debates y Guardados (`IndexedStack`: cada pestaña conserva su estado). El menú de cuenta y el
cierre de sesión están en la barra superior de las tres pestañas. Cerrar sesión elimina
`PrincipalController`, `InicioController` y los controladores de las pestañas.

**Qué cuenta cada indicador** (calculado en SQL por `backend/app/repositorios/estadisticas.py`;
la app no descarga aportes para contar):

| Indicador | Definición |
|---|---|
| Debates activos | Debates con `estado = publicado` (editoriales y de usuarios). Los borradores nunca cuentan; los archivados se informan aparte (`debates_archivados`). Hasta 7A la etiqueta era "Debates publicados". |
| Por categoría | Debates **activos** de cada una de las 8 categorías, incluidas las que tienen 0 (sin archivados ni borradores). El servidor las envía en orden fijo; el dashboard las muestra de más a menos debates y, en empate, por nombre visible en orden alfabético español (sin tildes ni mayúsculas, ñ tras n). |
| Aportes | Filas de `aportes` existentes (los eliminados no cuentan), **incluidos los de debates archivados**, que se conservan. |
| Participantes | Cuentas **distintas** con al menos un aporte existente. No es el número de cuentas registradas. |
| Debates sin aportes | Total de debates activos sin aportes, y los 5 primeros en el orden del catálogo (id ascendente). |
| Actividad reciente | Hasta 5 debates con aportes, ordenados por la fecha de **creación** de su aporte más reciente (desc) y, a igualdad, por id de debate (desc). Las ediciones no cuentan como actividad. Solo debates activos. |
| Mis aportes | Aportes existentes de la cuenta del token, por tipo (pregunta, argumento, propuesta). |
| Debates en los que participé | Debates **distintos** con al menos un aporte de la cuenta. |
| Mis aportes recientes | Hasta 5, por fecha de creación (desc) e id (desc), con el debate al que pertenecen. |
| Mis debates (7B) | Borradores pendientes, debates publicados y archivados creados por la cuenta del token. |
| Mis guardados | Número de debates guardados en el dispositivo (repositorio Hive existente; no viene del servidor). |

**Privacidad.** `/estadisticas/comunidad` solo devuelve cifras y títulos de debates: ni nombres,
ni correos, ni identificadores de cuentas. `/estadisticas/mias` usa exclusivamente el usuario del
JWT y no acepta parámetros de usuario.

**Estado.** `InicioController` carga las dos secciones por separado, cada una con carga, error con
"Reintentar" y datos; un fallo nunca se muestra como cero. Usa `SesionController.ejecutar`,
numera sus cargas y deja de aplicar respuestas al cerrarse. Se actualiza con el botón "Actualizar
cifras", deslizando hacia abajo o automáticamente cuando `ActividadComunidad` (antes `ActividadAportes`) avisa que el servidor
confirmó publicar, editar o eliminar un aporte, o publicar, editar o archivar un debate (7B).

**Interfaz.** Las cifras usan un componente compartido (`lib/widgets/tarjetas_estadistica.dart`).
La rejilla mide la altura natural de cada tarjeta y luego las maqueta con esa altura como **mínimo**
(no como altura fija): con una altura fija cada tarjeta era un límite de maquetación y, si su texto
cambiaba en una recarga (por ejemplo, "(1 archivado aparte)" tras archivar), se volvía a maquetar
sola con la altura anterior y desbordaba ("BOTTOM OVERFLOWED BY 16 PIXELS"). Ahora cualquier cambio
de contenido vuelve a calcular la altura común:
`TarjetaEstadistica` (icono, cifra, título y explicación alineados arriba, sin recortes ni
tipografía reducida) dentro de `RejillaEstadisticas`, que da a todas las tarjetas de un grupo el
mismo ancho y la altura de la más alta: "La comunidad" forma una cuadrícula 2×2 y "Mi
participación" dos tarjetas iguales. Pasa a una columna si cada columna quedaría por debajo de
140 px escalados con el tamaño de texto (hasta ×1,6), y la altura crece con el texto ampliado;
distribución por categoría con texto, cantidad y una barra proporcional; cada categoría
abre el catálogo filtrado, cada debate abre su detalle, "Debates publicados" y "Explorar debates"
abren el catálogo y "Mis guardados" la pestaña Guardados. Las cifras tienen etiquetas semánticas
("Aportes: 5. Preguntas, argumentos y propuestas"); la información nunca depende solo del color.

## Debates de usuarios (Bloque 7B, v1.1)

**Modelo.** `debates` gana `procedencia` (`editorial` | `usuario`), `estado` (`publicado` |
`archivado`), `autor_id` (FK a `usuarios`, nulo en los editoriales), `ambito`, `objetivo`,
`publicado_en` y `archivado_en`. Los borradores viven en una tabla aparte, `borradores` (autor,
campos opcionales, `paso` 1–6, `debate_id` único y nulo hasta publicar): un borrador nunca aparece
en el catálogo, en búsquedas ni en estadísticas.

**Asistente de creación** (`CrearDebateScreen` + `CrearDebateController`), 6 pasos: tema
(categoría y ámbito), pregunta, contexto (resumen y descripción), perspectivas (2–5, títulos
distintos), objetivo y revisión con el botón "Publicar debate". Cada dato se pide una sola vez;
avanzar valida el paso y **guarda el borrador** (solo avanza si el guardado se confirma);
retroceder conserva los datos. Errores junto al campo; si guardar falla, aviso con "Reintentar
guardado" y los datos se mantienen. Salir con cambios sin guardar pregunta: seguir editando,
descartar o "Guardar y salir" (también disponible como icono en la barra). Límites (mismos en app y
backend): ámbito 3–120, pregunta 10–160, resumen 30–300, contexto 80–3000, objetivo 20–500, título
de perspectiva 3–80 y descripción 20–600.

**Borradores.** Se guardan incompletos; la validación completa ocurre al publicar (422 con los
campos que faltan). Son privados: todas las consultas filtran por el usuario del JWT y un borrador
ajeno responde **404** (igual que uno inexistente, para no revelar que existe). Se recuperan desde
"Mis debates" tras cerrar la app por completo. Eliminar pide confirmación; un borrador ya publicado
no se edita ni se elimina (409).

**Publicar** (`POST /borradores/{id}/publicar`). El autor sale solo del token. En una transacción
se inserta el debate (`procedencia=usuario`, `estado=publicado`, `origen` "Debate creado por una
persona usuaria") y se vincula el borrador con un `UPDATE … WHERE debate_id IS NULL`; si otra
petición ya lo vinculó, se revierte y se devuelve el debate existente. Primera vez **201**,
repeticiones **200** con el mismo debate: no hay duplicados. En la app, si la respuesta se pierde,
reintentar publica sin volver a guardar (un 409 al guardar se interpreta como "ya publicado").

**Roles (ajuste de 7B).** `usuarios.rol` vale `usuario` o `administrador`. El registro público
siempre crea `usuario` y rechaza cualquier campo extra (`rol`, `id`…) con 422; no existe edición de
perfil (`PATCH`/`PUT /auth/me` → 405). El rol **no viaja en el JWT** ni se acepta de la app: la
dependencia `administrador_actual` lo lee de la base en cada petición, así que retirar el rol tiene
efecto inmediato con la sesión abierta. `/auth/me` devuelve `rol` solo para que la interfaz decida
qué mostrar. No hay administradores ni contraseñas predeterminados: la persona autora promueve una
cuenta existente con el comando local (pide escribir de nuevo el id; solo muestra id, nombre y rol):

```bash
cd backend
docker compose exec api python -m app.admin listar
docker compose exec api python -m app.admin promover <id>
docker compose exec api python -m app.admin retirar <id>     # deshacer
```

**Editar.** Solo quien creó el debate; los editoriales no se editan (403). Editar
(`PUT /debates/{id}`, contenido completo) es un único `UPDATE` condicionado a autor, estado
publicado y `NOT EXISTS` aportes: si entra un aporte a la vez, la edición falla con 409
"bloqueado". Una solicitud de archivo pendiente no impide editar.

**Archivo con revisión administrativa.** El autor ya **no** archiva directamente:

- *Solicitud* (`POST /debates/{id}/solicitud-archivo`, motivo 10–500): solo la cuenta autora de un
  debate de usuario activo (403 a cuentas ajenas, también a administradores; 409 si ya está
  archivado). No archiva ni bloquea nada. Un índice único parcial (`estado = 'pendiente'`) impide
  dos pendientes por debate incluso con peticiones simultáneas: repetir devuelve la misma (200).
- *Consulta y cancelación* (`GET /solicitudes-archivo`, `GET`/`POST …/{id}/cancelar`): solo las
  propias (ajena → 404); cancelar solo mientras está pendiente (resuelta → 409; repetir una
  cancelación → 200). Se puede volver a solicitar después.
- *Revisión* (`/admin/solicitudes-archivo`, rol leído de la base): lista de pendientes por orden de
  llegada, detalle, `aprobar` o `rechazar` con justificación obligatoria. Aprobar archiva el debate
  en la misma transacción; rechazar lo deja activo. Cada decisión es un `UPDATE … WHERE estado =
  'pendiente'` seguido, al aprobar, de `UPDATE debates … WHERE estado = 'publicado'`: el primer
  `UPDATE` toma el bloqueo de escritura de SQLite, así que de varias resoluciones simultáneas solo
  una se aplica y el resto recibe 409; si el debate ya no estuviera publicado, se revierte todo.
- *Archivo directo* (`POST /debates/{id}/archivar`, motivo obligatorio): solo administración, sobre
  cualquier debate activo (también editorial). Cualquier otra cuenta recibe **403, aunque sea la
  autora**, antes de validar el cuerpo. Si había una solicitud pendiente, se cierra como aprobada con
  la respuesta "La administración archivó el debate directamente.".
- *Registro*: `solicitudes_archivo` guarda solicitante, motivo, fechas, revisor, justificación y
  decisión; el debate guarda `archivo_origen`, `archivado_por_id` y `motivo_archivo`. Nada se borra.
- *Privacidad*: el detalle público solo expone `estado`, `archivado_en` y `archivo_origen`
  (`solicitud`, `administracion` o `anterior`), con el que la app muestra una explicación fija. El
  motivo, la justificación y el revisor no se envían a otras cuentas. El solicitante ve su solicitud
  (`solicitud_archivo` en el detalle y en Mis debates) con estado y respuesta, sin datos del revisor.
- *Archivos anteriores*: los debates que su autor archivó con la política anterior se marcan
  `archivo_origen = 'anterior'`, sin revisor ni motivo; no se reabren ni se atribuyen a nadie.

El archivado conserva contenido y aportes, se puede consultar por id y sale del catálogo. Crear,
editar o eliminar aportes en un archivado responde **409**: la comprobación se hace tras escribir y
dentro de la misma transacción, con el bloqueo de escritura de SQLite tomado, así que un archivado
simultáneo no deja pasar aportes. Quien crea un debate no obtiene permisos sobre aportes ajenos.

**App.** Menú del detalle: el autor ve "Editar debate" y "Solicitar archivo" (o "Cancelar solicitud
de archivo" si hay una pendiente) y un aviso con el estado de su solicitud; la administración ve
"Archivar (administración)". Ambos piden el texto en `pedirMotivo` (`lib/widgets/dialogo_motivo.dart`,
error junto al campo). Mis debates muestra la solicitud pendiente con un botón para cancelarla y el
origen de cada archivado. La sección **Administración** de Inicio (solo si `/auth/me` dice
`administrador`) abre `AdminSolicitudesScreen` → `AdminSolicitudScreen` con Aprobar y Rechazar
(`AdminSolicitudesController`). Los controladores ignoran un segundo envío mientras hay uno en
curso, descartan respuestas de sesiones anteriores (`SesionController.ejecutar`) y, ante un 409,
recargan el estado real del servidor.

**Desde Guardados.** Un debate guardado que luego se archiva se sigue abriendo: el detalle muestra
el aviso "Debate archivado el … " con la explicación pública de su origen y "ya no admite nuevos
aportes ni cambios", oculta "Publicar un aporte" y las acciones de editar o eliminar aportes, y sigue
pudiendo quitarse de guardados.

**Presentación.** Los debates de usuarios muestran "CREADO POR NOMBRE" en el catálogo y, en el
detalle, "Debate creado por NOMBRE. Es contenido de la comunidad: Ágora Joven no lo ha verificado
ni lo respalda". Se usa el nombre visible; el correo nunca se envía. Los campos internos
(`procedencia`, `estado`, `autor_id`, fechas) no se aceptan del cliente (`extra=forbid` → 422).

**Mis debates** (`MisDebatesScreen`, acceso desde la tarjeta de Inicio → Mi participación):
pestañas Borradores, Publicados y Archivados, con carga, vacío y error. Publicar, archivar o editar
avisa por `ActividadComunidad` (antes `ActividadAportes`) y se recargan el dashboard, el catálogo y
Mis debates. Todas las operaciones usan `SesionController.ejecutar`: una respuesta tardía de otra
sesión se descarta.

**Migraciones (Alembic).** Al arrancar, `app/migrar.py` aplica las migraciones de
`app/migraciones/` (`0001` esquema v1/7A, `0002` columnas 7B y tabla `borradores`, `0003` roles,
origen del archivo y `solicitudes_archivo`, `0004` historial de versiones, indicadores de
protección, `aportes.version_id` y `aclaraciones`). Las migraciones aplicadas no se modifican; cada cambio
de esquema es una revisión nueva. Una base
anterior sin `alembic_version` pero con las tablas v1 se marca como `0001` y se actualiza. La FK
`autor_id` se añade con `ALTER TABLE … ADD COLUMN … REFERENCES` (SQLite no admite añadir
restricciones por otra vía sin recrear la tabla). Los 20 debates existentes quedan
`editorial`/`publicado`; la semilla del catálogo nunca sobrescribe un debate que no sea editorial.
Manual: `python -m app.migrar`.

**Restaurar una copia de seguridad.** Las copias están fuera de Git (rutas en
`docs/SEGUIMIENTO.md`): la previa a 7B (esquema 7A, revisión `0001`), la previa a los roles
(revisión `0002`) y la previa al historial (revisión `0003`). Al arrancar, la API aplica las migraciones pendientes: restaurar una copia con
el código actual la vuelve a migrar a la última revisión conservando sus datos; para volver de
verdad a un esquema anterior hay que usar también el código de esa versión. Con la API detenida:

```bash
cd backend
docker compose stop api
docker compose cp <ruta-de-la-copia>.db api:/srv/data/agora.db   # el contenedor detenido admite cp
docker compose start api
```

No usar `down -v` (borra el volumen). Antes de restaurar, conviene copiar también la base actual.

## Historial de versiones (Bloque 7B.1, v1.1)

Objetivo: conservar qué contenido estaba publicado cuando alguien participó y evitar que cambios
posteriores desvirtúen su aporte.

**Versiones** (`versiones_debate`, migración `0004`). Cada fila guarda los 7 campos de contenido
(categoría, ámbito, pregunta, resumen, contexto, perspectivas, objetivo), `numero` consecutivo por
debate (único), `tipo`, fecha, autor del cambio y motivo. Solo se insertan: no hay ninguna ruta ni
función que las modifique o borre.

| Tipo | Cuándo | Autor y motivo |
|---|---|---|
| `publicacion` | Al publicar un borrador (versión 1). Los guardados del borrador nunca son versiones | Autor; sin motivo |
| `edicion` | Cada edición efectiva permitida (`PUT /debates/{id}` con `motivo` obligatorio, 10–500) | Autor y motivo |
| `catalogo` | Alta o cambio de un debate editorial por la semilla | Sin autor ni motivo (material editorial) |
| `registro_inicial` | Migración `0004`: "Estado registrado al incorporar el historial" de cada debate existente | Sin autor ni motivo: no se conservaron |

Guardar sin cambios (contenido idéntico tras normalizar espacios) responde 200 y no crea versión.
Archivo y solicitudes de archivo tienen su registro propio y no tocan las versiones.

**Bloqueo permanente.** `debates.con_participacion` se marca al aceptar el primer aporte y nunca se
desmarca: aunque luego se eliminen todos los aportes, el contenido no se puede reescribir (409).
`debates.bloqueo_historico` protege de forma conservadora todos los debates publicados antes de
`0004`: no se puede demostrar que los que hoy no tienen aportes nunca los tuvieron. Solo es
editable un debate de usuario publicado, de la cuenta autora, sin participación, sin bloqueo
histórico y sin aportes. Nadie más puede reescribirlo, tampoco la administración (403). Los
borradores siguen editables y los debates publicados después de `0004` usan solo el indicador
permanente.

**Concurrencia.** Publicar un aporte empieza con
`UPDATE debates SET con_participacion = 1 WHERE id = ? AND estado = 'publicado' AND
version_actual = ?`; editar empieza con un `UPDATE` condicionado a autor, publicado, sin
participación, sin bloqueo y sin aportes. Ambos escriben primero en la fila del debate, así que el
primero que llega toma el bloqueo de escritura de SQLite y el otro ve el estado ya confirmado:
o se edita y el aporte redactado sobre la versión anterior recibe 409, o se publica el aporte y la
edición queda rechazada. Nunca ambos (prueba con hilos y prueba determinista de los dos órdenes).

**Aportes vinculados a una versión.** `POST /debates/{id}/aportes` exige `version` (la que la
persona estaba viendo). Si no es del debate → 422; si ya no es la vigente → **409** con
`detail = {codigo: "version_desactualizada", mensaje, version_actual}` y no se publica. La app
conserva el texto, explica que el debate cambió, permite abrir la versión vigente y solo publica
si la persona confirma "Aportar sobre la versión N" y vuelve a pulsar Publicar (sin reintentos
automáticos). `aportes.version_id` no cambia al editar el texto. Los aportes anteriores al
historial tienen `version_id` nulo: la app muestra "Versión original desconocida" y ofrece la
instantánea inicial solo como referencia.

**Aclaraciones** (`aclaraciones`): añadidos fechados del autor a su debate de usuario activo
(`POST /debates/{id}/aclaraciones`, texto 10–1000, también con el contenido bloqueado). Se
muestran en una sección aparte con autor y fecha, son inmutables (una rectificación es otra
aclaración) y no crean versión. En un debate archivado → 409 (solo lectura). Un cambio sustancial
de tema se publica como otro debate (no hay bifurcaciones automáticas).

**Semilla editorial.** Inserta los debates nuevos con su versión 1 (`catalogo`). Un cambio en el
archivo solo se aplica si el debate no está protegido (sin participación, sin bloqueo histórico y
publicado) y crea la versión siguiente; si está protegido se cuenta como `protegidos` y no se toca.

**App.** "Historial" (icono en la barra del detalle, para cualquier cuenta autenticada) →
`HistorialScreen` (versiones con tipo, fecha, autor, campos cambiados y motivo) →
`VersionScreen` (aviso de versión vigente o "Versión histórica N … No es el contenido vigente",
diferencias por campo "Antes"/"Después" respecto a la anterior y el contenido completo). Cada
aporte enlaza con su versión. El autor edita pidiendo el motivo y ve si se creó versión; añade
aclaraciones desde el menú. `HistorialController` y `VersionController` usan
`SesionController.ejecutar` y descartan respuestas tardías.

**Compatibilidad.** El APK `v1.0.0` publica aportes sin `version`: contra este backend recibe 422.
No se relaja la comprobación ni se asigna una versión supuesta a esas peticiones. Cada app usa su
backend: APK `v1.0.0` → backend de la etiqueta `v1.0.0`; app 1.1 → backend de `main`. El backend
antiguo no debe abrir un volumen migrado a `0004` (escribiría aportes sin versión y sin marcar
la participación). Los dos entornos necesitan proyecto, volumen, contenedor e imagen distintos;
el `docker-compose.yml` de la etiqueta tiene nombres fijos iguales a los de `main`, así que se
separan con `-p agora-joven-v100` y un archivo de anulación local. Desde este bloque, `main`
construye la imagen `agora-joven-api:1.1-dev` (antes `:dev`, el mismo nombre que la etiqueta).
Instrucciones en README → "Qué código usar con cada app".

## Persistencia

| Dónde | Tecnología | Motivo |
|---|---|---|
| Backend (implementado) | SQLite en el volumen Docker `agora_datos` (`/srv/data/agora.db`), con claves foráneas activadas | Sin servicio extra que levantar; suficiente para la escala del proyecto. Se descartó Postgres (más pasos para quien evalúa). Hasta 7A las tablas se creaban con `create_all`; desde 7B el esquema se versiona con migraciones Alembic aplicadas al arrancar (ver "Debates de usuarios"). |
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
- Backend (Bloque 7B, versiones del lock del curso): `alembic` 1.20.0 (migraciones versionadas),
  con sus dependencias `mako` 1.4.1 y `markupsafe` 3.0.3. La app no añadió paquetes en 7B.
- Asistente (Bloque 5): **sin dependencias nuevas**. Gemini se llama por REST con `urllib` de la
  biblioteca estándar; no se instaló el SDK de Google.

## CI y Release (Bloque 6)

- `.github/workflows/ci.yml` (push y pull request; `contents: read`): trabajo Flutter
  (`subosito/flutter-action@v2` con Flutter 3.47.5, `pub get --enforce-lockfile`, `analyze`,
  `test --timeout 30s`) y trabajo backend (`actions/setup-python@v7` con Python 3.12,
  `pip install -r requirements-dev.txt`, `pytest`). Sin `.env`, sin secretos y con IA simulada.
- `.github/workflows/release.yml` (etiquetas `v*`): trabajo `backend` (pytest, solo lectura) y
  trabajo `apk` (`needs: backend`, único con `contents: write`): comprueba que la etiqueta coincida
  con `version` de `pubspec.yaml`, Java 17 (`actions/setup-java@v6`), `analyze`, `test`,
  `flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:8010`, renombra a
  `agora-joven-<etiqueta>-emulador.apk`, calcula su SHA-256 y publica ambos con
  `softprops/action-gh-release@v3`.
- Acciones fijadas por versión mayor (`@v7`, `@v6`, `@v2`, `@v3`), comprobadas en sus páginas
  oficiales el 24/10/2026. No se fijan por commit SHA (decisión de sencillez para el curso).
- **Firma:** el `buildType release` de la plantilla de Flutter usa `signingConfigs.debug`
  (comprobado en el APK local: `CN=Android Debug`). En el runner la clave de depuración se genera
  en cada ejecución. No hay firma de producción.

## Python: local frente a contenedor

- Contenedor (referencia de ejecución): `python:3.12-slim`, comprobado Python 3.12.15.
- Entorno local de desarrollo y pruebas: Python 3.11.9 en `backend/.venv` (no hay 3.12 instalado).
- Una prueba que pasa en local no demuestra que el contenedor funcione; el contenedor se valida
  aparte (ver `docs/SEGUIMIENTO.md`).

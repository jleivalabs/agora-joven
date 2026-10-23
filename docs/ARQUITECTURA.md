# Arquitectura — Ágora Joven

> Estado: el backend implementa `/health`, autenticación y catálogo (Bloque 1). La app implementa
> sesión (registro, acceso, restauración, cierre) y catálogo con detalle (Bloque 2). Aportes,
> guardados y asistente siguen **previstos**.

## Vista general

```
┌──────────────── App Flutter (app/) ────────────────┐        ┌──────── Backend (backend/) ────────┐
│ screens/      Pantallas y widgets (sin HTTP)       │        │ FastAPI                             │
│     │ Obx / Get.find                               │        │  routers/ → repositorios/ → models  │
│ controllers/  GetxController (estado compartido)   │        │             │                       │
│     │                                              │  HTTP  │  SQLite persistente (volumen)       │
│ repositories/ Reglas de acceso y mapeo a modelos   │ ─────► │  JWT (firma con secreto en .env)    │
│     │                                              │  JSON  │  Asistente → Gemini (previsto)      │
│ data/         ApiClient (Dio) · TokenStorage       │        │  (clave solo en el servidor)        │
│               (flutter_secure_storage) · Hive*     │        └─────────────────────────────────────┘
└────────────────────────────────────────────────────┘        * previsto
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
| Sección de aportes + formulario | `AportesController` | `AportesRepository` | `ApiClient` | ⏳ |
| `GuardadosScreen` | `GuardadosController` | `GuardadosRepository` | Hive (caja por usuario) | ⏳ |
| Asistente (en el detalle) | `AsistenteController` | `AsistenteRepository` | `ApiClient` | ⏳ |

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

`Usuario` y `Debate` están implementados (`backend/app/models.py`); `Aporte` es propuesta.

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
| autor_id | int | FK a Usuario; lo asigna el servidor desde el token, nunca el cliente |
| autor_nombre | str | Solo en respuestas |
| tipo | enum | pregunta, argumento, propuesta |
| texto | str (10–1000) | |
| creado_en / editado_en | datetime | `editado_en` nulo si no se editó |
| es_propio | bool | Calculado en la respuesta para el usuario autenticado |

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
| `GET /debates/{id}/aportes` | ⏳ | Aportes del debate (más recientes primero) | 200 · 401 · 404 |
| `POST /debates/{id}/aportes` | ⏳ | Crear `{tipo, texto}` | 201 · 401 · 404 · 422 |
| `PATCH /aportes/{id}` | ⏳ | Editar el propio `{tipo?, texto?}` | 200 · 401 · **403 si no es el autor** · 404 · 422 |
| `DELETE /aportes/{id}` | ⏳ | Eliminar el propio | 204 · 401 · **403** · 404 |
| `POST /asistente/debates/{id}` | ⏳ | `{modo: "contexto" \| "perspectivas"}` → `{texto, aviso}` | 200 · 401 · 404 · 422 · 503 proveedor no disponible |

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
├── repositorios/       consultas a la base (usuarios, debates)
├── routers/            auth.py, debates.py
├── catalogo.py         carga idempotente del catálogo (también: python -m app.catalogo)
└── datos/debates.json  20 debates editoriales
```

## Asistente (previsto)

- **Proveedor**: Gemini, invocado solo desde el backend. La clave vive exclusivamente en el
  `.env` del servidor (`.env.example` tendrá el nombre de la variable sin valor). La app nunca la
  recibe ni la conoce.
- **Entrada al modelo**: el contexto del debate (título, contexto, perspectivas) y una **selección
  acotada** de sus aportes (número máximo y longitud máxima fijos, definidos en el servidor).
- **Aportes como datos**: el texto de los aportes se envía delimitado y marcado como contenido de
  usuarios a resumir, nunca como instrucciones; las instrucciones del sistema indican ignorar
  órdenes contenidas en ellos.
- **Datos que no salen del servidor**: correos, contraseñas o hashes, tokens, identificadores
  internos de usuario. Como autor solo puede viajar el tipo de aporte, no la identidad.
- **Salida**: texto educativo con tratamiento equilibrado de las perspectivas y un aviso de que es
  generado por IA. **No** se publica ni se convierte en aporte automáticamente.
- **Sin modo de demostración**: si el proveedor falla o no hay clave, el endpoint responde 503 y la
  app muestra el error. Las respuestas simuladas solo pueden existir dentro de las pruebas
  automatizadas y nunca se presentan como evidencia de integración real.

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
- Previstas: `hive`, `hive_flutter` (guardados); cliente de Gemini en el backend (asistente).

## Python: local frente a contenedor

- Contenedor (referencia de ejecución): `python:3.12-slim`, comprobado Python 3.12.15.
- Entorno local de desarrollo y pruebas: Python 3.11.9 en `backend/.venv` (no hay 3.12 instalado).
- Una prueba que pasa en local no demuestra que el contenedor funcione; el contenedor se valida
  aparte (ver `docs/SEGUIMIENTO.md`).

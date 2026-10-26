# Ágora Joven

App Android (Flutter) para que personas adultas jóvenes **comprendan temas públicos**, **consulten
debates ciudadanos** y **publiquen preguntas, argumentos o propuestas**, con un backend propio
(FastAPI) y un asistente educativo con IA (Gemini) que explica el contexto y resume perspectivas.

> **Solo para personas de 18 años o más** (desde la v1.1). No está destinada a menores. La edad es
> una declaración de la persona, no una verificación, y por sí sola no garantiza el cumplimiento
> de las condiciones de los proveedores de IA. Desde el Bloque 7C el registro pide la
> declaración y las cuentas existentes deben confirmarla antes de seguir. Ver
> [docs/ALCANCE.md](docs/ALCANCE.md).

Proyecto Final del curso *Desarrolla Aplicaciones Móviles Robustas con Flutter e IA* (CEDIA). Los
20 debates son **material editorial de demostración** redactado para este proyecto.

> **Versión publicada: [v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0)** (APK para el emulador Android + SHA-256), generada por
> GitHub Actions desde el commit `1ce2f37` y validada por la persona autora en el emulador.
> Estado y evidencias de cada bloque: [docs/SEGUIMIENTO.md](docs/SEGUIMIENTO.md).
>
> **v1.1 en desarrollo en `main`** (sin publicar). Su backend **no es compatible** con el APK
> v1.0.0: para usar ese APK hay que ejecutar el backend de la etiqueta `v1.0.0` en un entorno
> separado. Ver [Qué código usar con cada app](#qué-código-usar-con-cada-app).

## Capturas de pantalla

Capturas reales de las **pruebas de desarrollo** de la persona autora en el emulador Android, con
la app ejecutada desde el código contra el backend Docker; **no** se tomaron con el APK de la
Release (ese APK se validó después con el recorrido descrito en `docs/SEGUIMIENTO.md`). Los
nombres visibles ("Jleiva", "patu") son cuentas de prueba.

| Acceso | Catálogo | Aportes de dos cuentas |
|---|---|---|
| <img src="docs/capturas/01-acceso.png" alt="Pantalla de acceso sin credenciales escritas" width="230"> | <img src="docs/capturas/02-catalogo.png" alt="Catálogo de debates con filtro por categoría" width="230"> | <img src="docs/capturas/03-aportes-dos-cuentas.png" alt="Aportes de dos cuentas; Editar y Eliminar solo en el propio" width="230"> |

| Guardados | Asistente: explicación del contexto | Asistente: sin aportes que resumir |
|---|---|---|
| <img src="docs/capturas/04-guardados.png" alt="Pantalla Guardados con un debate" width="230"> | <img src="docs/capturas/05-asistente-contexto.png" alt="Explicación real de Gemini con formato Markdown y etiqueta Generado por IA" width="230"> | <img src="docs/capturas/06-asistente-sin-aportes.png" alt="Asistente indicando que no hay aportes que resumir" width="230"> |

## Qué incluye

- [x] Registro, inicio y cierre de sesión con JWT del backend propio; token en almacenamiento
      seguro; la sesión se restaura al abrir la app.
- [x] Catálogo de 20 debates guardados en SQLite del backend, con filtro por categoría y estados de
      carga, vacío y error.
- [x] Aportes (pregunta, argumento o propuesta) visibles para todas las cuentas; solo su autor puede
      editarlos o eliminarlos (403 comprobado en el servidor).
- [x] Debates guardados con Hive, separados por cuenta, que sobreviven al cierre completo de la app.
- [x] Asistente educativo con Gemini **a través del backend**: explicar el contexto y resumir los
      aportes; sin claves en la app y sin publicar nada automáticamente.
- [x] Estado compartido con GetX y arquitectura en capas.
- [x] CI y Release del APK con GitHub Actions (`.github/workflows/`).

## Requisitos y versiones comprobadas

| Herramienta | Versión |
|---|---|
| Flutter / Dart | 3.47.5 / 3.13.4 (canal stable) |
| Docker / Docker Compose | 29.8.2 / v5.6.0 (Docker Desktop en ejecución) |
| Python del contenedor y de CI | 3.12 (`python:3.12-slim`; comprobado 3.12.15) |
| Python local (opcional, desarrollo sin Docker) | 3.11.9 |
| Android | Emulador con API 24 o superior (minSdk 24) |

## Qué código usar con cada app

| App | Backend | Proyecto Docker | Volumen | Contenedor | Imagen | Puerto del equipo |
|---|---|---|---|---|---|---|
| **APK v1.0.0** (Release) | Etiqueta **`v1.0.0`** (commit `1ce2f37`) | `agora-joven-v100` | `agora-joven-v100_agora_datos` | `agora-joven-api-v100` | `agora-joven-api:v1.0.0` | **8010** (fijo en el APK) |
| **App 1.1** desde el código (`flutter run`) | Rama **`main`** | `agora-joven` | `agora-joven_agora_datos` | `agora-joven-api` | `agora-joven-api:1.1-dev` | `API_PORT` (8010 por defecto) |

- **No mezcles backends y volúmenes.** El backend de `main` migra su base (revisión `0004`:
  historial de versiones, aportes ligados a una versión, roles). El backend de v1.0.0 no conoce
  esas migraciones: si abriera ese volumen, escribiría aportes sin versión y sin marcar la
  participación, rompiendo las protecciones de la v1.1. Cada entorno usa **su propio volumen**.
- **El APK v1.0.0 no funciona con el backend de `main`**: no envía la versión del debate al
  publicar aportes y recibe un error 422. No es un fallo que haya que relajar en el servidor.
- **Puertos:** el APK v1.0.0 solo llama a `http://10.0.2.2:8010`. Los dos backends no pueden usar
  el 8010 a la vez: detén el de desarrollo (`docker compose stop api` en su clon; **nunca**
  `down -v`) mientras pruebas el APK, o mueve el de desarrollo a otro puerto (`API_PORT=8012` en
  su `backend/.env` y `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8012`).
- **Secretos:** cada entorno tiene su `backend/.env`, creado y editado a mano a partir de
  `.env.example`, con un `JWT_SECRET` propio. No se copia entre clones ni se imprime.

## Probar la Release v1.0.0 (APK + backend de la etiqueta)

El `docker-compose.yml` de la etiqueta usa los mismos nombres fijos que el de desarrollo
(proyecto `agora-joven`, contenedor `agora-joven-api`, volumen `agora-joven_agora_datos`). La
etiqueta no se modifica; en su lugar, un archivo de anulación local y `-p` separan el entorno.
**No uses las instrucciones de "Puesta en marcha" del README de la etiqueta**: arrancarían el
backend antiguo sobre el volumen de desarrollo.

#### A1. Descargar el código de la etiqueta en otra carpeta

```powershell
cd ..        # fuera del clon de desarrollo
git clone --branch v1.0.0 --depth 1 https://github.com/jleivalabs/agora-joven.git agora-joven-v1.0.0
cd agora-joven-v1.0.0
git rev-parse --short HEAD             # debe mostrar 1ce2f37
```

También sirve el archivo "Source code" de la [Release v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0).

#### A2. Secretos de este entorno (a mano)

```powershell
cd backend
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Abre `backend/.env` en tu editor y pega el valor generado en `JWT_SECRET=` (uno **nuevo**, no el del
entorno de desarrollo). Deja `API_PORT=8010`: es el puerto que usa el APK. `GEMINI_API_KEY` es
opcional. No muestres el archivo en la terminal para comprobarlo.

#### A3. Anulación local de nombres (no versionada)

En `agora-joven-v1.0.0\backend`:

```powershell
@'
services:
  api:
    image: agora-joven-api:v1.0.0
    container_name: agora-joven-api-v100
volumes:
  agora_datos:
    name: agora-joven-v100_agora_datos
'@ | Set-Content -Encoding ascii docker-compose.v1.override.yml
```

Todas las órdenes de este entorno llevan `-p agora-joven-v100` y los dos `-f`. Para no
olvidarlos, define en esa terminal:

```powershell
function dc100 { docker compose -p agora-joven-v100 -f docker-compose.yml -f docker-compose.v1.override.yml @args }
```

#### A4. Liberar el puerto 8010 (si el backend de desarrollo está en marcha)

En el clon de desarrollo (`agora-joven\backend`): `docker compose stop api`. Solo lo detiene;
el volumen de desarrollo no se toca.

#### A5. Crear, comprobar el volumen y arrancar

```powershell
dc100 create --build api
docker inspect agora-joven-api-v100 --format "{{range .Mounts}}{{.Name}}{{end}}"
# Debe mostrar exactamente: agora-joven-v100_agora_datos
dc100 start api
dc100 ps                                # agora-joven-api-v100 (healthy)
curl.exe http://localhost:8010/health
```

Si `docker inspect` muestra otro volumen (por ejemplo `agora-joven_agora_datos`), **no arranques**:
elimina solo ese contenedor con `dc100 rm api` (sin `-v`) y revisa los pasos A3 y A5.

#### A6. Instalar el APK y probar

1. Descarga de la [Release v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0) los archivos
   `agora-joven-v1.0.0-emulador.apk` y `agora-joven-v1.0.0-emulador.apk.sha256`.
2. Verifica la descarga (el valor debe coincidir con el del archivo `.sha256`):

   ```powershell
   Get-FileHash .\agora-joven-v1.0.0-emulador.apk -Algorithm SHA256
   Get-Content .\agora-joven-v1.0.0-emulador.apk.sha256
   ```

3. Con el emulador abierto, instala (si había otra versión firmada con otra clave, desinstálala):

   ```powershell
   adb uninstall ec.edu.ute.agora_joven      # solo si ya estaba instalada
   adb install .\agora-joven-v1.0.0-emulador.apk
   ```

   Desinstalar la app borra lo que guarda **en el dispositivo**: la sesión (token) y los debates
   guardados con Hive. **No** borra nada del backend: cuentas, aportes y debates siguen en el
   volumen Docker. Tras reinstalar, inicia sesión de nuevo y vuelve a guardar los debates.

   El volumen `agora-joven-v100_agora_datos` empieza vacío: registra cuentas nuevas en este
   entorno (las del entorno de desarrollo no están aquí, y no deben copiarse).

**Dirección del backend de ese APK:** `http://10.0.2.2:8010`. `10.0.2.2` es tu equipo visto desde el
**emulador Android**; por eso el APK de la Release solo funciona en el emulador con el backend de
la etiqueta en marcha en el puerto 8010 del equipo. Un teléfono físico necesita compilar otra vez con la IP del equipo (ver
"Ejecutar desde el código").

#### A7. Volver al entorno de desarrollo

```powershell
dc100 stop api                          # en agora-joven-v1.0.0\backend
```

Después, en el clon de desarrollo: `docker compose start api`. Los dos volúmenes se conservan.

## Desarrollo v1.1 desde un clon limpio (rama `main`)

### 1. Clonar

```powershell
git clone https://github.com/jleivalabs/agora-joven.git
cd agora-joven
```

Esto descarga `main` (v1.1 en desarrollo). **No sirve para el APK v1.0.0**: para él, ver
[Probar la Release v1.0.0](#probar-la-release-v100-apk--backend-de-la-etiqueta).

### 2. Configurar los secretos del backend (solo en tu equipo)

```powershell
cd backend
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Abre `backend/.env` en tu editor:

- `JWT_SECRET=` → pega el valor generado. **Obligatorio**: sin él, Compose no arranca la API.
- `GEMINI_API_KEY=` → opcional. Crea la clave en
  [Google AI Studio](https://aistudio.google.com/app/apikey) y pégala solo aquí. Sin clave todo
  funciona salvo el asistente, que responde "no está configurado".

`backend/.env` está en `.gitignore`: no lo compartas, no lo subas y no pegues sus valores en chats
ni capturas. Cada clon (desarrollo y v1.0.0) tiene **su propio** `backend/.env`, creado a mano:
no se copia de un clon a otro ni se imprime para comprobarlo.

### 3. Arrancar el backend con Docker y comprobar /health

```powershell
docker compose up --build -d api
docker compose ps                     # agora-joven-api debe aparecer como (healthy)
curl.exe http://localhost:8010/health
# {"status":"ok","servicio":"agora-joven-api"}
```

- Puerto del host: `8010`. La base SQLite vive en el volumen `agora-joven_agora_datos` y sobrevive
  a `docker compose down` y a recrear el contenedor. **`docker compose down -v` borra el volumen**.
- Al arrancar se aplican las migraciones (Alembic) y se carga el catálogo de 20 debates (carga
  idempotente). Este volumen ya está en el esquema de la v1.1: **no lo abras con el backend de
  v1.0.0**.
- Documentación interactiva de la API: `http://localhost:8010/docs`.

### 4. Ejecutar la app desde el código

```powershell
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010
```

| Entorno | `API_BASE_URL` | Notas |
|---|---|---|
| Emulador Android | `http://10.0.2.2:8010` (por defecto) | Permitido en `network_security_config.xml` |
| Teléfono físico en la misma red | `http://<IP-del-PC>:8010` | Añadir esa IP a `app/android/app/src/main/res/xml/network_security_config.xml` o usar HTTPS |

## Recorrido de prueba (dos cuentas)

Recorrido de la v1.0.0. Con el APK de la Release, el backend es el de la etiqueta: donde dice
`docker compose`, usa `dc100` (paso A3) en `agora-joven-v1.0.0ackend`.

1. Abre la app → "Crear una cuenta" → registra la cuenta A → inicia sesión.
2. Catálogo: filtra por una categoría y vuelve a "Todas". Abre un debate: contexto, perspectivas y
   aviso editorial.
3. **Guardados:** pulsa el marcador del detalle → vuelve al catálogo → icono "Guardados".
   Cierra la app por completo (desde recientes o `adb shell am force-stop ec.edu.ute.agora_joven`),
   ábrela: la sesión se restaura y el debate sigue en Guardados.
4. **Aportes:** en el debate, "Publicar un aporte" (tipo y texto de 10 a 1000 caracteres). Edítalo.
5. **Asistente:** "Explicar el contexto" y "Resumir perspectivas de los aportes" (requiere la clave
   de Gemini en el backend; cada consulta es una llamada real al proveedor).
6. Menú de cuenta → "Cerrar sesión". Registra la cuenta B e inicia sesión.
7. Con B: Guardados está vacío; en el mismo debate ves el aporte de A **sin** Editar ni Eliminar.
   Publica un aporte propio.
8. Vuelve a A y pulsa "Actualizar aportes": ves los dos, el más reciente primero. Elimina el tuyo
   (pide confirmación); el de B se conserva.
9. Errores: con la app abierta, `docker compose stop api` y actualiza: mensaje de error con
   "Reintentar"; `docker compose start api` y reintenta. Guardados sigue disponible sin backend.

## Arquitectura

```text
app/lib/
├── screens/       pantallas y secciones (solo interfaz)
├── controllers/   estado compartido con GetX (sesión, debates, aportes, guardados, asistente)
├── repositories/  reglas de acceso y conversión a modelos
├── data/          ApiClient (Dio), TokenStorage (flutter_secure_storage), Hive
├── models/        Usuario, Debate, Aporte, DebateGuardado, RespuestaAsistente
└── widgets/       estados de carga/vacío/error, Markdown seguro

backend/app/
├── routers/       auth, debates, aportes, asistente
├── repositorios/  consultas SQLAlchemy
├── models.py      Usuario, Debate, Aporte (SQLite)
├── security.py    Argon2id, JWT y usuario actual
└── ia.py          cliente REST de Gemini (sin SDK)
```

Un dato viaja así: la pantalla llama a un controlador GetX; el controlador pide la operación a un
repositorio a través de `SesionController.ejecutar` (que añade el token y descarta respuestas de
sesiones anteriores); el repositorio usa `ApiClient` (Dio) y convierte el JSON en modelos; el
controlador actualiza sus observables y `Obx` repinta la pantalla con el estado de carga, vacío,
datos o error. Ninguna pantalla llama a HTTP, Hive ni al almacenamiento seguro.

Detalle de capas, contrato de la API y decisiones: [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).
Alcance y correspondencia con la rúbrica: [docs/ALCANCE.md](docs/ALCANCE.md).

## Decisiones técnicas propias

- **Contador de sesión contra respuestas tardías.** Cada operación captura el número de sesión al
  empezar y solo aplica su resultado si no cambió: una respuesta de la cuenta A nunca altera la
  cuenta B, un 401 antiguo no cierra la sesión nueva y varios 401 simultáneos producen un solo
  aviso. Se descartó confiar solo en cancelar peticiones, que no cubre escrituras ya enviadas.
- **Propiedad de los aportes solo en el servidor.** El autor sale del token; el cuerpo rechaza
  `autor_id`/`debate_id` (422) y editar o borrar lo ajeno da 403. Los botones de la app son solo
  cortesía visual.
- **SQLite en un volumen Docker** en lugar de PostgreSQL: un único servicio que levantar para quien
  evalúa, suficiente para la escala del proyecto.
- **Gemini por REST con la biblioteca estándar** en lugar del SDK: sin dependencias nuevas, tiempo
  máximo de espera explícito y errores clasificados (429/502/503) sin respuestas de reserva.

## Tecnologías

| App | Versión | Uso |
|---|---|---|
| `get` | 4.7.3 | Estado (GetxController) y navegación |
| `dio` | 5.11.1 | HTTP con límites de tiempo |
| `flutter_secure_storage` | 11.2.0 | Token cifrado (Keystore de Android) |
| `hive` / `hive_flutter` | 2.2.3 / 1.1.0 | Debates guardados por cuenta |
| `flutter_markdown_plus` | 1.0.12 | Respuestas del asistente con formato, sin HTML, imágenes ni enlaces activos |

| Backend | Versión | Uso |
|---|---|---|
| FastAPI / Starlette / Uvicorn | 0.142.2 / 1.7.0 / 0.54.0 | API |
| Pydantic / pydantic-settings | 2.13.5 / 2.15.0 | Validación y configuración desde el entorno |
| SQLAlchemy | 2.1.1 | SQLite con claves foráneas |
| PyJWT / pwdlib[argon2] | 2.15.1 / 0.3.1 | Tokens HS256 y contraseñas Argon2id |
| email-validator | 2.3.0 | Correo del registro |
| pytest / httpx2 | 9.1.1 / 2.13.1 | Pruebas (solo desarrollo) |

## Integración continua y Release

- `.github/workflows/ci.yml` — en cada push y pull request: Flutter (`pub get --enforce-lockfile`,
  `flutter analyze`, `flutter test`) y backend (Python 3.12, dependencias fijadas, `pytest`). Sin
  `.env`, sin claves y sin llamadas reales a IA. Permisos de solo lectura.
- `.github/workflows/release.yml` — al subir una etiqueta `v*`: vuelve a probar backend y app,
  comprueba que la etiqueta coincida con la versión de `pubspec.yaml`, compila el APK release con
  `API_BASE_URL=http://10.0.2.2:8010` y publica una GitHub Release con
  `agora-joven-vX.Y.Z-emulador.apk` y su `.sha256`. Solo el trabajo que publica tiene permiso de
  escritura.

## Seguridad

- No hay claves en el repositorio: `.env` está ignorado y solo se versiona `.env.example` con
  valores vacíos. `JWT_SECRET` y `GEMINI_API_KEY` viven solo en `backend/.env` del equipo que
  ejecuta el backend; ni GitHub Actions, ni la app, ni el APK los contienen.
- Contraseñas con Argon2id; ninguna respuesta devuelve contraseña, hash ni correo de otras personas.
- Solo el token se guarda en la app (`flutter_secure_storage`); no se registran cuerpos, tokens ni
  la cabecera `Authorization`. Uvicorn registra método, ruta y código.
- Al proveedor de IA no se envían nombres, correos, identificadores ni tokens; sí el texto de los
  aportes, que puede contener lo que sus autores escribieron. El backend no registra la clave, los
  prompts ni las respuestas.
- `AGENTS.md` y `.claude/settings.json` guían a los agentes de código, pero no son una barrera
  técnica absoluta ([límites](AGENTS.md#límites-conocidos-de-los-permisos)).

## Limitaciones conocidas

- **Firma del APK:** el build release usa la clave de **depuración** (plantilla de Flutter). En
  GitHub Actions esa clave se genera en cada ejecución, así que cada Release está firmada con una
  clave distinta: no se puede actualizar sobre otra versión (hay que desinstalar antes) y no sirve
  para publicar en una tienda. No hay firma de producción configurada.
- **APK solo para emulador:** apunta a `http://10.0.2.2:8010` por HTTP sin TLS, permitido solo para
  hosts locales. Un teléfono físico o un backend público requieren otra compilación y HTTPS.
- **Hive:** si la apertura de una caja falla por una ruta de almacenamiento inválida, además del
  mensaje controlado de la app, Hive genera una excepción asíncrona no capturada (reproducido en
  pruebas; efecto en Android no verificado). Ver `docs/SEGUIMIENTO.md` → Bloque 4.
- **Errores no previstos:** la app no instala un manejador global de errores no capturados.
- **Asistente:** depende de la disponibilidad, cuota y coste de Gemini; sus respuestas pueden
  contener errores aunque se indique en la interfaz. Resume como máximo los 20 aportes más recientes.
- Sin paginación del catálogo ni de los aportes, sin modo sin conexión (salvo la lista de
  guardados) y sin recuperación de contraseña.

## Versión 1.1 (en desarrollo)

Cambios en `main` posteriores a la v1.0.0, **sin Release publicada**. Para probarlos hay que
ejecutar la app desde el código (`flutter run`, sección 4 de "Desarrollo v1.1") con el backend de
`main` (`docker compose up --build -d api`). El APK v1.0.0 necesita el backend de su etiqueta (ver
[Qué código usar con cada app](#qué-código-usar-con-cada-app)).

- **Bloque 7A — dashboard de inicio.** Tras iniciar sesión, la app abre "Inicio", con navegación
  inferior entre Inicio, Debates y Guardados:
  - *La comunidad*: debates publicados, distribución por categoría (abre el catálogo filtrado),
    aportes, participantes (cuentas con al menos un aporte), debates sin aportes y actividad
    reciente.
  - *Mi participación*: mis aportes por tipo, debates en los que participé, mis aportes recientes
    y acceso a Mis guardados.
  - Cifras calculadas en el servidor (`GET /estadisticas/comunidad` y `/estadisticas/mias`);
    definiciones en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md#dashboard-bloque-7a-v11).
- **Bloque 7B — debates creados por usuarios.** "Crear debate" en el catálogo abre un asistente
  de 6 pasos (tema, pregunta, contexto, perspectivas, objetivo, revisión). Los borradores son
  privados, se guardan en el servidor al avanzar y se retoman desde Inicio → "Mis debates"
  (borradores, publicados, archivados). Publicado, el debate aparece en el catálogo como contenido
  de la comunidad no verificado; quien lo creó puede editarlo mientras no tenga aportes y
  solicitar su archivo, que revisa la administración (roles usuario/administrador; una cuenta se
  promueve solo con `docker compose exec api python -m app.admin promover <id>`). El backend migra la base existente con Alembic al arrancar, conservando cuentas,
  debates y aportes. Detalles en
  [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md#debates-de-usuarios-bloque-7b-v11).
- **Bloque 7B.1 — historial y protección del contexto.** Cada debate tiene "Historial" con sus
  versiones publicadas y las diferencias por campo. Editar exige un motivo y crea una versión; tras
  el primer aporte el contenido queda protegido para siempre. Los aportes indican la versión
  sobre la que se escribieron y, si el debate cambió mientras se redactaban, la app conserva el
  texto y pide confirmar. El autor puede añadir aclaraciones fechadas. Requiere la app de este
  bloque: el APK `v1.0.0` ya no puede publicar aportes contra este backend. Detalles en
  [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md#historial-de-versiones-bloque-7b1-v11).
- **Bloque 7C — fuentes y mayoría de edad.** En el paso "Contexto" del asistente, "Fuentes e IA
  (opcional)" busca referencias en Crossref con la pregunta y el ámbito, permite añadir hasta 8 al
  borrador y abrirlas en el navegador (enlace `https://doi.org/…`). Al publicar, aparecen como
  "Fuentes indicadas por la persona autora", sin presentarlas como verificadas. Los resúmenes no
  se procesan hasta aprobar una política de licencias, y la redacción con IA (Gemini **sin**
  búsqueda de Google) está desactivada (`REDACCION_IA_ACTIVA=false`): solo se ha probado con un
  proveedor simulado y no se activará hasta decidir el tratamiento de datos de Gemini. La búsqueda
  requiere `CROSSREF_MAILTO` en `backend/.env`, que configura la persona autora; se comprobó con
  Crossref real en el recorrido manual.
  Registro con declaración de 18 años o más; las cuentas existentes la confirman al entrar.
  Detalles en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md#investigación-asistida-y-mayoría-de-edad-bloque-7c-v11).
- Próximo: construcción de acuerdos. Alcance en [docs/ALCANCE.md](docs/ALCANCE.md).

## Desarrollo

### Backend sin Docker (Windows, PowerShell)

```powershell
cd backend
py -3.11 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8010
```

Lee `backend/.env` y guarda la base en `backend/data/agora.db` (ignorada). No uses este modo y
Docker a la vez: los dos ocupan el puerto 8010. Recarga manual del catálogo:
`docker compose exec api python -m app.catalogo` (o `.venv\Scripts\python -m app.catalogo`).

### Probar la API a mano (PowerShell)

```powershell
$u = "http://localhost:8010"
$cuenta = @{ nombre = "Prueba"; email = "prueba@example.com"; password = "clave-de-prueba-123" }
Invoke-RestMethod "$u/auth/registro" -Method Post -ContentType "application/json" -Body ($cuenta | ConvertTo-Json)
$login = Invoke-RestMethod "$u/auth/login" -Method Post -ContentType "application/json" `
  -Body (@{ email = $cuenta.email; password = $cuenta.password } | ConvertTo-Json)
$h = @{ Authorization = "Bearer $($login.access_token)" }
(Invoke-RestMethod "$u/debates" -Headers $h).Count          # 20
Invoke-RestMethod "$u/debates"                               # sin token: error 401
$nuevo = @{ tipo = "pregunta"; texto = "¿Qué opinan quienes estudian de noche?" } | ConvertTo-Json
$a = Invoke-RestMethod "$u/debates/1/aportes" -Method Post -Headers $h -ContentType "application/json" -Body $nuevo
Invoke-RestMethod "$u/aportes/$($a.id)" -Method Delete -Headers $h   # 204
```

Con el token de otra cuenta, `PATCH` y `DELETE` sobre ese aporte responden 403.

### Pruebas

```powershell
cd backend; .venv\Scripts\python -m pytest -q     # base temporal, secreto sintético, IA simulada
cd app; flutter analyze; flutter test               # servidor falso y almacenes simulados
```

## Créditos y licencias

- Debates: material editorial de demostración redactado para este proyecto; no representa
  posiciones oficiales ni contiene datos estadísticos o normativos.
- Asistente: Gemini API de Google (servicio externo; requiere clave propia y sus condiciones de uso).
- Paquetes de la app: Flutter (BSD-3), `get` (MIT), `dio` (MIT), `flutter_secure_storage` (BSD-3),
  `hive` y `hive_flutter` (Apache-2.0), `flutter_markdown_plus` y `markdown` (BSD-3).
- Paquetes del backend: FastAPI (MIT), Uvicorn (BSD-3), SQLAlchemy (MIT), PyJWT (MIT), pwdlib (MIT),
  argon2-cffi (MIT), pydantic-settings (MIT), email-validator (Unlicense).
- Licencias comprobadas en los archivos `LICENSE` o metadatos de los paquetes instalados.

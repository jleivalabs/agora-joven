# Desarrollo — Ágora Joven

Cómo ejecutar y probar el proyecto desde el código (rama `main`). Para usar un APK publicado, ver
[INSTALACION.md](INSTALACION.md); para las decisiones de diseño, [ARQUITECTURA.md](ARQUITECTURA.md).
Las reglas para agentes de código están en [AGENTS.md](../AGENTS.md).

## Puesta en marcha desde un clon limpio

Todas las órdenes parten de la raíz del repositorio (`agora-joven`).

```powershell
git clone https://github.com/jleivalabs/agora-joven.git
cd agora-joven
```

### Backend con Docker

```powershell
cd backend
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Edita `backend/.env` a mano (variables en
[INSTALACION.md → B2](INSTALACION.md#b2-secretos-y-configuración-a-mano)); está en `.gitignore`:
no lo compartas, no lo subas y no pegues sus valores en chats ni capturas.

```powershell
docker compose up --build -d api
docker compose ps                     # agora-joven-api (healthy)
curl.exe http://localhost:8010/health
cd ..                                 # vuelve a la raíz
```

### App desde el código

```powershell
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010
```

| Entorno | `API_BASE_URL` | Notas |
|---|---|---|
| Emulador Android | `http://10.0.2.2:8010` (por defecto) | Permitido en `network_security_config.xml` |
| Teléfono físico en la misma red | `http://<IP-del-PC>:8010` | Añadir esa IP a `app/android/app/src/main/res/xml/network_security_config.xml` o usar HTTPS |

APK release local para el emulador (queda en `app/build/`, ignorado por Git):
`flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:8010`.

## Backend sin Docker (Windows, PowerShell)

```powershell
cd backend
py -3.11 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8010
```

Lee `backend/.env` y guarda la base en `backend/data/agora.db` (ignorada). No uses este modo y
Docker a la vez: los dos ocupan el puerto 8010. Diferencias entre Python local y el del
contenedor: [ARQUITECTURA.md → Python](ARQUITECTURA.md#python-local-frente-a-contenedor).

## Comandos del backend

Con Docker (desde `backend`); sin Docker, usa `.venv\Scripts\python` en lugar de
`docker compose exec api python`.

| Orden | Efecto |
|---|---|
| `docker compose exec api python -m app.migrar` | Aplica migraciones pendientes e indica la revisión |
| `docker compose exec api python -m app.catalogo` | Recarga el catálogo editorial (no reescribe contenido protegido) |
| `docker compose exec api python -m app.admin listar` | Lista id, nombre y rol (sin correos) |
| `docker compose exec api python -m app.admin promover <id>` | Concede el rol de administración (pide confirmar el id) |
| `docker compose exec api python -m app.admin retirar <id>` | Devuelve la cuenta al rol de usuario |

## Probar la API a mano (PowerShell)

Escribe en la base del entorno en el que lo ejecutes (crea una cuenta y un aporte): úsalo solo en
una base de desarrollo. No llama a Gemini ni a Crossref.

```powershell
$u = "http://localhost:8010"
$cuenta = @{ nombre = "Prueba"; email = "prueba@example.com"; password = "clave-de-prueba-123";
             confirma_mayoria_edad = $true }    # declaración obligatoria (true estricto)
Invoke-RestMethod "$u/auth/registro" -Method Post -ContentType "application/json" -Body ($cuenta | ConvertTo-Json)
$login = Invoke-RestMethod "$u/auth/login" -Method Post -ContentType "application/json" `
  -Body (@{ email = $cuenta.email; password = $cuenta.password } | ConvertTo-Json)
$h = @{ Authorization = "Bearer $($login.access_token)" }
(Invoke-RestMethod "$u/debates" -Headers $h).Count          # 20 (más los debates de usuarios)
Invoke-RestMethod "$u/debates"                               # sin token: error 401
$debate = Invoke-RestMethod "$u/debates/1" -Headers $h
$nuevo = @{ tipo = "pregunta"; texto = "¿Qué opinan quienes estudian de noche?";
            version = $debate.version_actual } | ConvertTo-Json   # versión que se está viendo
$a = Invoke-RestMethod "$u/debates/1/aportes" -Method Post -Headers $h -ContentType "application/json" -Body $nuevo
Invoke-RestMethod "$u/aportes/$($a.id)" -Method Delete -Headers $h   # 204
```

Con el token de otra cuenta, `PATCH` y `DELETE` sobre ese aporte responden 403. Si la versión
enviada ya no es la vigente, la API responde 409 `version_desactualizada`. Contrato completo:
[ARQUITECTURA.md → Contrato de endpoints](ARQUITECTURA.md#contrato-de-endpoints).

## Pruebas

```powershell
cd backend
.venv\Scripts\python -m pytest -q     # base temporal, secreto sintético, IA y Crossref simulados
cd ..\app
flutter analyze
flutter test                          # servidor falso y almacenes simulados
```

El backend se valida también en Python 3.12 (el del contenedor y de CI). Ninguna prueba llama a
Gemini ni a Crossref: sus respuestas son simuladas y no cuentan como evidencia de integración real.

## CI y Release

- `.github/workflows/ci.yml` — en cada push y pull request: Flutter (`pub get --enforce-lockfile`,
  `flutter analyze`, `flutter test`) y backend (Python 3.12, dependencias fijadas, `pytest`). Sin
  `.env`, sin claves y sin llamadas reales a proveedores. Permisos de solo lectura.
- `.github/workflows/release.yml` — al subir una etiqueta `v*`: vuelve a probar backend y app,
  comprueba que la etiqueta coincida con la versión de `pubspec.yaml`, compila el APK release con
  `API_BASE_URL=http://10.0.2.2:8010` y publica una GitHub Release con
  `agora-joven-vX.Y.Z-emulador.apk` y su `.sha256`. Solo el trabajo que publica tiene permiso de
  escritura. Crear etiquetas y publicar Releases lo hace solo la persona autora.

Detalles: [ARQUITECTURA.md → CI y Release](ARQUITECTURA.md#ci-y-release-bloque-6).

## Seguridad y secretos

- No hay claves en el repositorio: `.env` está ignorado y solo se versiona `.env.example` con
  valores vacíos. `JWT_SECRET`, `GEMINI_API_KEY` y `CROSSREF_MAILTO` viven solo en `backend/.env`
  del equipo que ejecuta el backend; ni GitHub Actions, ni la app, ni el APK los contienen.
- Contraseñas con Argon2id; ninguna respuesta devuelve contraseña, hash ni correo de otras personas.
- Solo el token se guarda en la app (`flutter_secure_storage`); no se registran cuerpos, tokens ni
  la cabecera `Authorization`. Uvicorn registra método, ruta y código.
- Al proveedor de IA no se envían nombres, correos, identificadores ni tokens; sí el texto de los
  aportes, que puede contener lo que sus autores escribieron. El backend no registra la clave, los
  prompts ni las respuestas.
- `AGENTS.md` y `.claude/settings.json` guían a los agentes de código, pero no son una barrera
  técnica absoluta ([límites](../AGENTS.md#límites-conocidos-de-los-permisos)).

## Tecnologías

| App | Versión | Uso |
|---|---|---|
| `get` | 4.7.3 | Estado (GetxController) y navegación |
| `dio` | 5.11.1 | HTTP con límites de tiempo |
| `flutter_secure_storage` | 11.2.0 | Token cifrado (Keystore de Android) |
| `hive` / `hive_flutter` | 2.2.3 / 1.1.0 | Debates guardados por cuenta |
| `flutter_markdown_plus` | 1.0.12 | Respuestas del asistente con formato, sin HTML, imágenes ni enlaces activos |
| `url_launcher` | 6.3.3 | Abrir referencias (`https://doi.org/…`) en el navegador externo |

| Backend | Versión | Uso |
|---|---|---|
| FastAPI / Starlette / Uvicorn | 0.142.2 / 1.7.0 / 0.54.0 | API |
| Pydantic / pydantic-settings | 2.13.5 / 2.15.0 | Validación y configuración desde el entorno |
| SQLAlchemy / Alembic | 2.1.1 / 1.20.0 | SQLite con claves foráneas y migraciones versionadas |
| PyJWT / pwdlib[argon2] | 2.15.1 / 0.3.1 | Tokens HS256 y contraseñas Argon2id |
| email-validator | 2.3.0 | Correo del registro |
| pytest / httpx2 | 9.1.1 / 2.13.1 | Pruebas (solo desarrollo) |

Versiones fijadas en `app/pubspec.lock` y `backend/requirements*.txt`; no se actualizan sin acuerdo.

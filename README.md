# Ágora Joven

App Flutter para **comprender temas públicos**, **consultar debates ciudadanos** y **publicar
preguntas, argumentos o propuestas**, con un backend propio en FastAPI.

> **Estado: Bloque 3.** Backend con autenticación JWT, catálogo de 20 debates y aportes en SQLite.
> App con sesión, catálogo con filtro y detalle, y aportes compartidos (publicar, editar y eliminar
> los propios). Guardados y asistente están **planificados, no implementados**.
> Ver [docs/SEGUIMIENTO.md](docs/SEGUIMIENTO.md).

## Estructura

```
agora-joven/
├── app/        App Flutter (Android)
├── backend/    API FastAPI + Docker Compose
├── docs/       ALCANCE.md · ARQUITECTURA.md · SEGUIMIENTO.md
├── AGENTS.md   Reglas para agentes de código (CLAUDE.md lo importa)
└── README.md
```

## Requisitos

| Herramienta | Versión comprobada |
|---|---|
| Flutter / Dart | 3.47.5 / 3.13.4 (canal stable) |
| Python local (solo para `.venv` y pytest) | 3.11.9 |
| Python del contenedor | 3.12 (`python:3.12-slim`; comprobado 3.12.15) |
| Docker / Compose | 29.8.2 / v5.6.0 (Docker Desktop debe estar en ejecución) |
| Android | Emulador o dispositivo para ejecutar la app |

## Backend

### 1. Configurar el secreto (una vez)

El backend no arranca sin `JWT_SECRET` y no trae ningún valor por defecto. En `backend/`:

```powershell
cd backend
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Abre `backend/.env` en tu editor y pega el valor generado después de `JWT_SECRET=`. No lo
compartas ni lo subas al repositorio (`.env` está en `.gitignore`).

### 2. Con Docker Compose (recomendado)

```powershell
cd backend
docker compose up --build -d api
docker compose ps                     # agora-joven-api debe aparecer como (healthy)
curl.exe http://localhost:8010/health
# {"status":"ok","servicio":"agora-joven-api"}
```

- Puerto del host: `8010` (variable `API_PORT`), para no chocar con otros backends en `8000`.
- La base SQLite vive en el volumen `agora-joven_agora_datos` (`/srv/data/agora.db` dentro del
  contenedor) y sobrevive a `docker compose down` y a recrear el contenedor.
- `docker compose down` detiene solo este proyecto. **`docker compose down -v` borra el volumen y
  con él usuarios y datos.**
- Si falta `JWT_SECRET`, Compose se detiene con:
  `required variable JWT_SECRET is missing a value: Define JWT_SECRET en backend/.env`.

### 3. Sin Docker (Windows, PowerShell)

Entorno de desarrollo con Python 3.11 local; no reemplaza la comprobación del contenedor (3.12).
Lee `backend/.env` y guarda la base en `backend/data/agora.db` (ignorada por Git).

```powershell
cd backend
py -3.11 -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8010
```

Usa este modo o Docker, no ambos a la vez: los dos ocupan el puerto 8010.

### Catálogo de debates

Los 20 debates están en `backend/app/datos/debates.json` (material editorial de demostración). Se
cargan automáticamente al arrancar la API. Para recargarlos a mano tras editar el archivo:

```powershell
docker compose exec api python -m app.catalogo        # con Docker
.venv\Scripts\python -m app.catalogo                  # sin Docker
# Catálogo: 0 insertados, 0 actualizados, 20 en total.
```

La carga es idempotente: no duplica debates ni borra usuarios.

### Probar la API a mano (PowerShell)

```powershell
$u = "http://localhost:8010"
$cuenta = @{ nombre = "Prueba"; email = "prueba@example.com"; password = "clave-de-prueba-123" }
Invoke-RestMethod "$u/auth/registro" -Method Post -ContentType "application/json" -Body ($cuenta | ConvertTo-Json)
$login = Invoke-RestMethod "$u/auth/login" -Method Post -ContentType "application/json" `
  -Body (@{ email = $cuenta.email; password = $cuenta.password } | ConvertTo-Json)
$h = @{ Authorization = "Bearer $($login.access_token)" }
Invoke-RestMethod "$u/auth/me" -Headers $h
(Invoke-RestMethod "$u/debates" -Headers $h).Count          # 20
Invoke-RestMethod "$u/debates/categorias" -Headers $h
Invoke-RestMethod "$u/debates"                               # sin token: error 401

# Aportes
$nuevo = @{ tipo = "pregunta"; texto = "¿Qué opinan quienes estudian de noche?" } | ConvertTo-Json
$a = Invoke-RestMethod "$u/debates/1/aportes" -Method Post -Headers $h -ContentType "application/json" -Body $nuevo
Invoke-RestMethod "$u/debates/1/aportes" -Headers $h          # incluye autor_nombre y es_propio
Invoke-RestMethod "$u/aportes/$($a.id)" -Method Patch -Headers $h -ContentType "application/json" `
  -Body (@{ tipo = "argumento" } | ConvertTo-Json)
Invoke-RestMethod "$u/aportes/$($a.id)" -Method Delete -Headers $h   # 204
```

Con el token de otra cuenta, `PATCH` y `DELETE` sobre ese aporte responden 403.

La documentación interactiva está en `http://localhost:8010/docs`.

### Pruebas automáticas del backend

```powershell
cd backend
.venv\Scripts\python -m pytest -q
```

Usan una base SQLite temporal y un secreto sintético generado en cada ejecución; no necesitan
`.env` ni Docker.

## App

Requiere el backend en marcha (sección anterior) y un emulador Android abierto.

```powershell
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010
```

`API_BASE_URL` es opcional en el emulador: `http://10.0.2.2:8010` es el valor por defecto
(10.0.2.2 es el equipo anfitrión visto desde el emulador).

| Entorno | URL base | Notas |
|---|---|---|
| Emulador Android | `http://10.0.2.2:8010` | Permitido en `network_security_config.xml` |
| Dispositivo físico en la misma red | `http://<IP-del-PC>:8010` | Añadir esa IP a `app/android/app/src/main/res/xml/network_security_config.xml` o usar HTTPS |

Qué hace hoy la app: registro, inicio y cierre de sesión, restauración de la sesión al abrir,
catálogo de debates con filtro por categoría, detalle con contexto y perspectivas, y aportes
(preguntas, argumentos o propuestas) visibles para todas las cuentas; solo su autor puede
editarlos o eliminarlos.

### Paquetes de la app

| Paquete | Versión | Para qué |
|---|---|---|
| `get` | 4.7.3 | Estado (controladores GetX) y navegación |
| `dio` | 5.11.1 | HTTP con límites de tiempo; en pruebas se sustituye su adaptador por un servidor falso |
| `flutter_secure_storage` | 11.2.0 | Guardar solo el token, cifrado con el Keystore de Android (minSdk 24) |

Versiones iguales a las del proyecto del curso (ExploraEC), fijadas de forma exacta.

### Configuración Android (práctica)

- `INTERNET` declarado en el manifiesto principal (necesario en el APK de release).
- HTTP sin TLS permitido **solo** hacia `10.0.2.2`, `localhost` y `127.0.0.1`
  (`network_security_config.xml`). En producción el backend debe usar HTTPS.
- Copia de seguridad desactivada (`allowBackup="false"` y `data_extraction_rules.xml`): la sesión
  no se restaura en otro dispositivo, porque el token cifrado depende de una clave del Keystore.

### Pruebas de la app

```powershell
cd app
flutter analyze
flutter test
```

Las pruebas no necesitan el backend: usan un servidor falso conectado a Dio y un almacén de token
en memoria.

## Arquitectura

Pantalla (`screens/`) → controlador GetX (`controllers/`) → repositorio (`repositories/`) →
fuente de datos (`data/`). Detalle, modelos y contrato de endpoints en
[docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

## Seguridad

- No hay claves en el repositorio. `.env` está ignorado; solo se versiona `.env.example`.
- `JWT_SECRET` vive solo en `backend/.env` (o en el entorno del servidor); sin él la API no arranca.
- Contraseñas con Argon2id; ninguna respuesta incluye la contraseña ni su hash.
- Los registros de Uvicorn muestran método, ruta y código, nunca cabeceras ni tokens.
- En la app, solo el token se guarda, con `flutter_secure_storage`; nunca la contraseña. La app
  no registra cuerpos, tokens ni la cabecera `Authorization`, y no contiene claves del servidor.
- Asistente con Gemini a través del backend propio; la clave vivirá únicamente en el `.env` del
  servidor (previsto). No se envían correos, credenciales ni tokens al proveedor.
- `AGENTS.md` y `.claude/settings.json` guían a los agentes de código, pero no son una barrera
  técnica absoluta; ver sus límites en [AGENTS.md](AGENTS.md#límites-conocidos-de-los-permisos).

## Créditos y licencias

- Contenido de debates: material editorial de demostración redactado para este proyecto; no
  representa posiciones oficiales ni contiene datos estadísticos o normativos.
- Paquetes: Flutter (BSD-3), GetX `get` (MIT), `dio` (MIT), `flutter_secure_storage` (BSD-3), FastAPI (MIT), Uvicorn (BSD-3), SQLAlchemy (MIT),
  PyJWT (MIT), pwdlib (MIT), argon2-cffi (MIT), pydantic-settings (MIT), email-validator
  (Unlicense). Licencias comprobadas en los metadatos de los paquetes instalados.

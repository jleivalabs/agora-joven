# Instalación y versiones — Ágora Joven

Guía detallada para ejecutar cada versión publicada con su backend. El resumen está en el
[README](../README.md#inicio-rápido-evaluar-la-v110); el desarrollo desde el código, en
[DESARROLLO.md](DESARROLLO.md).

## Requisitos y versiones comprobadas

| Herramienta | Versión |
|---|---|
| Docker / Docker Compose | 29.8.2 / v5.6.0 (Docker Desktop en ejecución) |
| Android | Emulador con API 24 o superior (minSdk 24) y `adb` |
| Python | 3 (solo para generar el secreto del backend; el backend corre en `python:3.12-slim`) |
| Flutter / Dart | 3.47.5 / 3.13.4 (solo para compilar o ejecutar desde el código) |

## Qué código usar con cada app

| App | Backend | Proyecto Docker | Volumen | Contenedor | Imagen | Puerto del equipo |
|---|---|---|---|---|---|---|
| **APK v1.1.0** (Release) | Etiqueta **`v1.1.0`** (commit `382e5f8`) | `agora-joven` | `agora-joven_agora_datos` (revisión `0005`) | `agora-joven-api` | `agora-joven-api:1.1-dev` | **8010** (fijo en el APK) |
| **APK v1.0.0** (Release) | Etiqueta **`v1.0.0`** (commit `1ce2f37`) | `agora-joven-v100` | `agora-joven-v100_agora_datos` | `agora-joven-api-v100` | `agora-joven-api:v1.0.0` | **8010** (fijo en el APK) |
| **App 1.1** desde el código (`flutter run`) | Rama **`main`** | `agora-joven` | `agora-joven_agora_datos` | `agora-joven-api` | `agora-joven-api:1.1-dev` | `API_PORT` (8010 por defecto) |

- **No mezcles backends y volúmenes.** El backend de la v1.1.0 (y de `main`) migra su base a la
  revisión `0005` (roles, historial de versiones, aportes ligados a una versión, mayoría de edad,
  referencias). El backend de v1.0.0 no conoce esas migraciones: si abriera ese volumen,
  escribiría aportes sin versión y sin marcar la participación, rompiendo las protecciones de la
  v1.1. Cada entorno usa **su propio volumen**. Si `main` añade migraciones después de la v1.1.0,
  el backend de la etiqueta v1.1.0 tampoco debe abrir un volumen ya migrado por `main`: usa otro
  proyecto y volumen, como en los pasos A3–A5.
- **El APK v1.0.0 no funciona con el backend de la v1.1**: no envía la versión del debate al
  publicar aportes y recibe un error 422. No es un fallo que haya que relajar en el servidor.
- **Puertos:** los APK solo llaman a `http://10.0.2.2:8010` (`10.0.2.2` es tu equipo visto desde el
  emulador). Dos backends no pueden usar el 8010 a la vez: detén el otro (`docker compose stop api`
  en su clon; **nunca** `down -v`) o mueve el de desarrollo a otro puerto (`API_PORT=8012` en su
  `backend/.env` y `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8012`).
- **Secretos:** cada entorno tiene su `backend/.env`, creado y editado a mano a partir de
  `.env.example`, con un `JWT_SECRET` propio. No se copia entre clones, no se sube y no se imprime
  para comprobarlo.

## Release v1.1.0 (APK + backend de la etiqueta)

El APK de la [Release v1.1.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.1.0) se
usa con el backend de **esa misma etiqueta** (commit `382e5f8`), con la base en la revisión
`0005`.

### B1. Código de la etiqueta

```powershell
git clone --branch v1.1.0 --depth 1 https://github.com/jleivalabs/agora-joven.git agora-joven-v1.1.0
cd agora-joven-v1.1.0\backend
```

### B2. Secretos y configuración (a mano)

```powershell
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

En `backend/.env`, con tu editor y sin mostrarlo en la terminal:

| Variable | Valor |
|---|---|
| `JWT_SECRET` | **Obligatorio**: el valor generado (nuevo, no el de otro entorno). Sin él, Compose no arranca |
| `API_PORT` | `8010` (el que usa el APK) |
| `GEMINI_API_KEY` | Opcional: clave propia de [Google AI Studio](https://aistudio.google.com/app/apikey) para el asistente educativo. Sin ella, el asistente responde "no está configurado" |
| `CROSSREF_MAILTO` | Opcional: correo de contacto para buscar referencias en Crossref. Vacío, la búsqueda aparece como no configurada |
| `REDACCION_IA_ACTIVA` | `false` (la redacción con IA del asistente de creación no forma parte de la v1.1.0) |

### B3. Backend y revisión de la base

```powershell
docker compose up --build -d api
docker compose ps                              # agora-joven-api (healthy)
curl.exe http://localhost:8010/health          # {"status":"ok","servicio":"agora-joven-api"}
docker compose exec api python -m app.migrar   # "Esquema en la revisión 0005."
```

El arranque aplica las migraciones (Alembic) y carga el catálogo de 20 debates (carga
idempotente): una base nueva se crea en `0005` y una base de desarrollo v1.1 anterior se
actualiza conservando sus datos. Las cuentas que no hayan declarado la edad deben confirmarla al
entrar. La base vive en el volumen `agora-joven_agora_datos` y sobrevive a `docker compose down`
y a recrear el contenedor; **`docker compose down -v` borra el volumen**. Documentación interactiva
de la API: `http://localhost:8010/docs`.

### B4. Instalar el APK

Descarga de la Release `agora-joven-v1.1.0-emulador.apk` y `agora-joven-v1.1.0-emulador.apk.sha256`,
y comprueba que coinciden:

```powershell
Get-FileHash .\agora-joven-v1.1.0-emulador.apk -Algorithm SHA256
Get-Content .\agora-joven-v1.1.0-emulador.apk.sha256
```

Con el emulador abierto:

```powershell
adb uninstall ec.edu.ute.agora_joven      # necesario si había otra versión (firma distinta)
adb install .\agora-joven-v1.1.0-emulador.apk
```

El APK está firmado con la clave de **depuración** generada en GitHub Actions: cada Release tiene
una firma distinta, así que no se instala encima de otra versión. **Desinstalar borra lo guardado
en el dispositivo** (sesión y debates guardados con Hive); las cuentas, debates y aportes siguen en
el volumen Docker.

### Recorrido breve de la v1.1.0

1. Registra una cuenta marcando la declaración de 18 años o más (sin marcarla no se crea).
2. Inicio: cifras de la comunidad y de tu participación.
3. Debates → "Crear debate": completa los 6 pasos y publica. Si configuraste `CROSSREF_MAILTO`,
   en el paso Contexto "Fuentes e IA (opcional)" busca y añade una referencia.
4. Con otra cuenta, abre el debate, publica un aporte y comprueba el "Historial".
5. Con la primera cuenta: el debate ya no se puede editar (tiene aportes); puedes añadir una
   aclaración o solicitar su archivo.

Recorridos completos y evidencias de cada bloque: [SEGUIMIENTO.md](SEGUIMIENTO.md).

## Teléfono físico

El APK publicado solo sirve en el emulador. Para un teléfono hay que ejecutar o compilar desde el
código con la dirección del equipo (ver [DESARROLLO.md](DESARROLLO.md#app-desde-el-código)) y añadir
esa IP a `app/android/app/src/main/res/xml/network_security_config.xml`, o usar HTTPS.

## Copias de seguridad y restauración

Antes de migrar una base con datos, haz una copia consistente fuera de Git. Las copias usadas en
el proyecto y sus resultados están en [SEGUIMIENTO.md](SEGUIMIENTO.md) (respaldos previos a 7B,
a los roles, al historial y a 7C).

Restaurar una copia, con la API detenida:

```powershell
cd backend
docker compose stop api
docker compose cp <ruta-de-la-copia>.db api:/srv/data/agora.db   # el contenedor detenido admite cp
docker compose start api
```

Al arrancar, la API aplica las migraciones pendientes: restaurar una copia con el código actual la
vuelve a migrar a la última revisión conservando sus datos (y las cuentas sin declaración de edad
vuelven a quedar pendientes); para quedarse en un esquema anterior hay que usar también el código
de esa versión. Copia antes la base actual y no uses `down -v`.

## Versión anterior: Release v1.0.0 (APK + backend de la etiqueta)

El `docker-compose.yml` de la etiqueta v1.0.0 usa los mismos nombres fijos que el de la v1.1
(proyecto `agora-joven`, contenedor `agora-joven-api`, volumen `agora-joven_agora_datos`). La
etiqueta no se modifica; en su lugar, un archivo de anulación local y `-p` separan el entorno.
**No uses las instrucciones de "Puesta en marcha" del README de la etiqueta**: arrancarían el
backend antiguo sobre el volumen de la v1.1.

### A1. Descargar el código de la etiqueta en otra carpeta

```powershell
cd ..        # fuera del clon de la v1.1
git clone --branch v1.0.0 --depth 1 https://github.com/jleivalabs/agora-joven.git agora-joven-v1.0.0
cd agora-joven-v1.0.0
git rev-parse --short HEAD             # debe mostrar 1ce2f37
```

También sirve el archivo "Source code" de la
[Release v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0).

### A2. Secretos de este entorno (a mano)

```powershell
cd backend
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Pega en `JWT_SECRET=` un valor **nuevo**. Deja `API_PORT=8010`. `GEMINI_API_KEY` es opcional.

### A3. Anulación local de nombres (no versionada)

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

Todas las órdenes de este entorno llevan `-p agora-joven-v100` y los dos `-f`. Define en esa
terminal:

```powershell
function dc100 { docker compose -p agora-joven-v100 -f docker-compose.yml -f docker-compose.v1.override.yml @args }
```

### A4. Liberar el puerto 8010

Si el backend de la v1.1 está en marcha, en su clon (`agora-joven\backend`):
`docker compose stop api`. Solo lo detiene; su volumen no se toca.

### A5. Crear, comprobar el volumen y arrancar

```powershell
dc100 create --build api
docker inspect agora-joven-api-v100 --format "{{range .Mounts}}{{.Name}}{{end}}"
# Debe mostrar exactamente: agora-joven-v100_agora_datos
dc100 start api
dc100 ps                                # agora-joven-api-v100 (healthy)
curl.exe http://localhost:8010/health
```

Si `docker inspect` muestra otro volumen (por ejemplo `agora-joven_agora_datos`), **no arranques**:
elimina solo ese contenedor con `dc100 rm api` (sin `-v`) y revisa A3 y A5.

### A6. Instalar el APK

Descarga de la [Release v1.0.0](https://github.com/jleivalabs/agora-joven/releases/tag/v1.0.0)
`agora-joven-v1.0.0-emulador.apk` y su `.sha256`, compruébalos como en B4 e instálalo:

```powershell
adb uninstall ec.edu.ute.agora_joven      # solo si ya estaba instalada
adb install .\agora-joven-v1.0.0-emulador.apk
```

El volumen `agora-joven-v100_agora_datos` empieza vacío: registra cuentas nuevas en este entorno.

### Recorrido de la v1.0.0 (dos cuentas)

Donde dice `docker compose`, usa `dc100` en `agora-joven-v1.0.0\backend`.

1. Abre la app → "Crear una cuenta" → registra la cuenta A → inicia sesión.
2. Catálogo: filtra por una categoría y vuelve a "Todas". Abre un debate: contexto, perspectivas y
   aviso editorial.
3. **Guardados:** pulsa el marcador del detalle → vuelve al catálogo → icono "Guardados". Cierra la
   app por completo (desde recientes o `adb shell am force-stop ec.edu.ute.agora_joven`) y ábrela:
   la sesión se restaura y el debate sigue en Guardados.
4. **Aportes:** en el debate, "Publicar un aporte" (tipo y texto de 10 a 1000 caracteres). Edítalo.
5. **Asistente:** "Explicar el contexto" y "Resumir perspectivas de los aportes" (requiere la clave
   de Gemini en el backend; cada consulta es una llamada real al proveedor).
6. Menú de cuenta → "Cerrar sesión". Registra la cuenta B e inicia sesión.
7. Con B: Guardados está vacío; en el mismo debate ves el aporte de A **sin** Editar ni Eliminar.
   Publica un aporte propio.
8. Vuelve a A y pulsa "Actualizar aportes": ves los dos, el más reciente primero. Elimina el tuyo
   (pide confirmación); el de B se conserva.
9. Errores: con la app abierta, `dc100 stop api` y actualiza: mensaje de error con "Reintentar";
   `dc100 start api` y reintenta. Guardados sigue disponible sin backend.

### A7. Volver a la v1.1

```powershell
dc100 stop api                          # en agora-joven-v1.0.0\backend
```

Después, en el clon de la v1.1: `docker compose start api`. Los dos volúmenes se conservan.

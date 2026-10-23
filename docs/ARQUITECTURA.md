# Arquitectura — Ágora Joven

> Estado: **propuesta**. En el Bloque 0 solo existen la pantalla inicial, `ArranqueController`,
> el tema visual y `GET /health`. El resto describe lo previsto.

## Vista general

```
┌──────────────── App Flutter (app/) ────────────────┐        ┌──────── Backend (backend/) ────────┐
│ screens/      Pantallas y widgets (sin HTTP/Hive)  │        │ FastAPI                             │
│     │ Obx / Get.find                               │        │  routers/  → services/ → repos/     │
│ controllers/  GetxController (estado compartido)   │        │             │                       │
│     │                                              │  HTTPS │  SQLite persistente (volumen)       │
│ repositories/ Reglas de acceso y mapeo a modelos   │ ─────► │  JWT (firma con secreto en .env)    │
│     │                                              │  JSON  │  Asistente → proveedor de IA        │
│ data/         ApiClient (Dio) · TokenStorage       │        │  (clave solo en el servidor)        │
│               (flutter_secure_storage) · Hive      │        └─────────────────────────────────────┘
└────────────────────────────────────────────────────┘
```

Regla: una pantalla solo habla con controladores; un controlador solo con repositorios; solo
`data/` conoce Dio, `flutter_secure_storage` o Hive.

## Capas de la app (previstas)

| Pantalla (`screens/`) | Controlador GetX | Repositorio | Fuente de datos |
|---|---|---|---|
| `InicioScreen` (existe) | `ArranqueController` (existe) | — | — |
| `LoginScreen`, `RegistroScreen` | `SesionController` | `AuthRepository` | `ApiClient`, `TokenStorage` |
| `DebatesScreen` (lista por categoría) | `DebatesController` | `DebatesRepository` | `ApiClient` |
| `DebateDetalleScreen` | `DebateDetalleController` | `DebatesRepository` | `ApiClient` |
| Sección de aportes + `AporteFormScreen` | `AportesController` | `AportesRepository` | `ApiClient` |
| `GuardadosScreen` | `GuardadosController` | `GuardadosRepository` | Hive (caja por usuario) |
| `AsistenteSheet` (en el detalle) | `AsistenteController` | `AsistenteRepository` | `ApiClient` |

Widgets comunes de estado: `EstadoCargando`, `EstadoVacio`, `EstadoError` (con reintentar).

### Protección de sesión

- `SesionController` mantiene un **número de sesión** que aumenta en cada login y logout.
- Cada petición registra el número vigente al salir; si al volver ya cambió, la respuesta se
  descarta y no modifica el estado (evita que una respuesta tardía de la sesión A aparezca en la
  sesión B).
- Al cerrar sesión: borrar token, limpiar controladores dependientes y cerrar la caja Hive del
  usuario.
- Un 401 cierra la sesión solo si pertenece al número de sesión vigente.

### Errores

`ApiClient` convierte errores de Dio en un `AppException` tipado (`sinConexion`, `noAutorizado`
401, `prohibido` 403, `noEncontrado` 404, `solicitudInvalida` 400, `validacion` 422, `servidor`
5xx). Los controladores exponen un mensaje en español distinto para cada caso.

## Modelos (propuesta)

**Usuario**
| Campo | Tipo | Notas |
|---|---|---|
| id | int | |
| nombre | str (2–60) | Nombre visible en los aportes |
| email | str | Único; solo lo ve su dueño |
| password_hash | str | Solo en el servidor (Argon2); nunca se devuelve |
| creado_en | datetime (UTC) | |

**Debate**
| Campo | Tipo | Notas |
|---|---|---|
| id | int | |
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

## Contrato inicial de endpoints

Base: `http://<host>:8010` (Docker Compose). Errores con el formato estándar de FastAPI
(`{"detail": ...}`).

Solo son públicos `GET /health`, `POST /auth/registro` y `POST /auth/login`. **Todo lo demás,
incluido `GET /auth/me`, exige un token válido** (`Authorization: Bearer <token>`); sin token, con
un token mal formado o caducado, la respuesta es 401.

| Método y ruta | Uso | Respuestas principales |
|---|---|---|
| `GET /health` | Salud del servicio (**implementado**) | 200 |
| `POST /auth/registro` | Crear cuenta `{nombre, email, password}` | 201 usuario · 400 email ya registrado · 422 |
| `POST /auth/login` | `{email, password}` → `{access_token, token_type}` | 200 · 401 credenciales inválidas · 422 |
| `GET /auth/me` | Usuario del token | 200 · 401 |
| `GET /debates/categorias` | Categorías con número de debates | 200 · 401 |
| `GET /debates?categoria=` | Lista resumida | 200 · 401 · 422 categoría inválida |
| `GET /debates/{id}` | Detalle con contexto y perspectivas | 200 · 401 · 404 |
| `GET /debates/{id}/aportes` | Aportes del debate (más recientes primero) | 200 · 401 · 404 |
| `POST /debates/{id}/aportes` | Crear `{tipo, texto}` | 201 · 401 · 404 · 422 |
| `PATCH /aportes/{id}` | Editar el propio `{tipo?, texto?}` | 200 · 401 · **403 si no es el autor** · 404 · 422 |
| `DELETE /aportes/{id}` | Eliminar el propio | 204 · 401 · **403** · 404 |
| `POST /asistente/debates/{id}` | `{modo: "contexto" \| "perspectivas"}` → `{texto, aviso}` | 200 · 401 · 404 · 422 · 503 proveedor no disponible |

El cierre de sesión es local (se borra el token); el JWT expira por tiempo.

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

## Persistencia (decisiones previstas)

| Dónde | Tecnología | Motivo |
|---|---|---|
| Backend | SQLite en un volumen de Docker | Sin servicio extra que levantar; suficiente para la escala del proyecto. Se descartó Postgres (más pasos para quien evalúa). |
| App, guardados | Hive (caja por usuario) | Mismo patrón practicado en el curso; sobrevive al cierre completo. |
| App, token | `flutter_secure_storage` | Requisito del curso: el token no va en Hive ni en preferencias. |

## Paquetes previstos (aún no instalados)

- App: `dio`, `flutter_secure_storage`, `hive`, `hive_flutter` (mismas versiones que ExploraEC,
  confirmar al añadirlos).
- Backend: `sqlalchemy`, `pyjwt`, `pwdlib[argon2]`, `pydantic-settings`, `email-validator` y el
  cliente de Gemini (paquete y versión por confirmar en el bloque del asistente).

## Python: local frente a contenedor

- Contenedor (referencia de ejecución): `python:3.12-slim`, comprobado Python 3.12.15.
- Entorno local de desarrollo y pruebas: Python 3.11.9 en `backend/.venv` (no hay 3.12 instalado).
- Una prueba que pasa en local no demuestra que el contenedor funcione; el contenedor se valida
  aparte con `docker compose up` y `GET /health`.

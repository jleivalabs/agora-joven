# AGENTS.md — reglas del proyecto Ágora Joven

Contexto para agentes de código (Claude Code, Codex u otros). Corto y concreto.

> Estas son **instrucciones de comportamiento**, no una barrera técnica: un agente puede
> incumplirlas por error. La protección real está en el código (autorización en el backend), en
> `.gitignore` y en la revisión humana del `git diff`. Ver "Límites conocidos" al final.

## Qué es

Ágora Joven: app Flutter (Android) para comprender temas públicos, consultar debates ciudadanos y
publicar preguntas, argumentos o propuestas. Backend propio FastAPI. Alcance en `docs/ALCANCE.md`,
capas y contrato de API en `docs/ARQUITECTURA.md`, avance en `docs/SEGUIMIENTO.md`.

## Estructura

- `app/` — Flutter. `lib/screens/` → `lib/controllers/` (GetX) → `lib/repositories/` → `lib/data/`.
- `backend/` — FastAPI. `app/` código, `tests/` pruebas, `docker-compose.yml`.
- `docs/` — alcance, arquitectura y seguimiento.

## Cómo verificar antes de dar algo por terminado

```bash
cd app && flutter analyze && flutter test
cd backend && .venv/Scripts/python -m pytest -q        # Windows
cd backend && docker compose config                     # valida Compose
```

Si algo falla, corrige el código; no desactives el análisis ni borres pruebas.

## Versiones (no actualizar sin acuerdo)

Flutter 3.47.5 / Dart 3.13.4, `get` 4.7.3, `dio` 5.11.1, `flutter_secure_storage` 11.2.0. Backend: Python 3.12 (Docker), FastAPI 0.142.2,
Starlette 1.7.0, Pydantic 2.13.5, Uvicorn 0.54.0, SQLAlchemy 2.1.1, PyJWT 2.15.1, pwdlib 0.3.1,
pydantic-settings 2.15.0, email-validator 2.3.0 (fijadas en `backend/requirements.txt`). No actualizar herramientas ni dependencias
globales.

## Reglas de diseño

- Las pantallas no llaman a HTTP, Hive ni almacenamiento seguro: solo a controladores GetX.
- Estado compartido en `GetxController`; nada de `setState` para estado entre pantallas.
- Cada pantalla con datos muestra carga, vacío y error (con salida o reintento).
- Textos de interfaz en español neutro. Contenido semilla marcado como material editorial de demostración.
- **Sesiones protegidas**: una respuesta tardía de una sesión no puede modificar el estado de
  otra (número de sesión; ver `docs/ARQUITECTURA.md`).
- **Propiedad de aportes en el backend**: el autor sale del token; editar o borrar ajeno → 403.
  Nunca confiar en un `autor_id` enviado por la app.
- **IA (Gemini vía backend)**: la clave vive solo en el `.env` del servidor; la app nunca la
  conoce. El asistente usa el contexto del debate y una selección acotada de aportes, tratados
  como datos y no como instrucciones. Nunca enviar al proveedor correos, credenciales ni tokens.
  Es educativo, equilibrado y no publica nada automáticamente. Sin modo de demostración: las
  respuestas simuladas solo existen en pruebas y no cuentan como evidencia de integración real.
- Solo son públicos `GET /health`, `POST /auth/registro` y `POST /auth/login`; el resto (incluido
  `GET /auth/me`) exige token válido.
- Fuera de alcance: mapas, chat en tiempo real, notificaciones, votaciones, rankings, panel de
  administración.
- Cambios pequeños, un bloque a la vez; no añadir paquetes para funciones aún no implementadas y
  avisar antes de añadir cualquier dependencia.

## Forma de trabajo del agente

- No usar subagentes ni equipos de agentes salvo petición expresa de la persona.
- Mantener búsquedas y salidas de herramientas acotadas.
- Distinguir propuesta, acción realizada y resultado verificado.

## Prohibido

- Leer, mostrar o modificar archivos `.env` reales; escribir claves, tokens o contraseñas en
  código, registros o documentación. Usar `.env.example` con valores ficticios.
- `git push`, crear etiquetas, Releases o repositorios remotos: lo hace la persona autora.
- Modificar los proyectos de referencia (`../exploraec`, `../proyecto-curso-spec-kit`) o
  configuraciones globales.
- Marcar como terminada una función sin evidencia (comando ejecutado y su resultado).

## Límites conocidos de los permisos

`.claude/settings.json` reduce riesgos, pero **no garantiza protección absoluta**:

- `Read(**/.env)` bloquea la herramienta de lectura, no un comando de terminal que lea el archivo
  (por ejemplo `cat` o `Get-Content`), ni variantes de nombre no listadas.
- Las reglas `Bash(...)`/`PowerShell(...)` comparan el texto del comando; una forma equivalente
  escrita de otra manera (alias, scripts, comandos encadenados) puede no coincidir.
- La configuración local o global de cada persona puede ampliar o reducir estos permisos.
- Otros agentes distintos de Claude Code no leen `.claude/settings.json`.

Por eso: revisar siempre el `git diff` antes de un commit y auditar secretos antes de publicar.

# Alcance — Ágora Joven

Proyecto Final del curso *Desarrolla Aplicaciones Móviles Robustas con Flutter e IA* (CEDIA).
Entrega: lunes 26 de octubre de 2026, 08:00, en Moodle (enlace al repositorio).

## Propósito

Ágora Joven ayuda a personas adultas jóvenes (**18 años o más**) a **comprender temas públicos**,
**consultar debates ciudadanos** y **publicar preguntas, argumentos o propuestas**. Ver "Público".

Los contenidos iniciales son **material editorial de demostración**, identificado como tal en la
app y en el backend. El asistente es **educativo**: explica contexto y resume perspectivas de forma
equilibrada; **nunca publica contenido automáticamente**.

## Público: solo personas adultas (decisión del 25/10/2026)

Ágora Joven está dirigida **exclusivamente a personas de 18 años o más**. No está destinada a
menores de edad. Los debates sobre colegios, adolescentes o menores se mantienen como temas que
discuten personas adultas.

Medidas implementadas con 7C (comprobadas con pruebas automáticas y recorrido manual):

- Registro: aviso claro del rango de edad y confirmación obligatoria de que la persona tiene 18
  años o más, validada también por el backend (sin la confirmación, no se crea la cuenta).
- Cuentas existentes: deben confirmar la edad antes de seguir usando la plataforma; la
  confirmación no se da por aceptada automáticamente en la migración.
- No se recopilan documentos de identidad ni fecha de nacimiento en esta versión.

Es una **declaración de la persona, no una verificación de edad**. Por sí sola no garantiza el
cumplimiento de las condiciones de los proveedores (por ejemplo, los términos de Gemini API exigen
18 años o más y prohíben aplicaciones dirigidas a menores o con probabilidad de que accedan
menores).

La v1.0.0 publicada (etiqueta y Release, que no se modifican) se describía como dirigida a
"personas jóvenes"; esta decisión rige desde la v1.1.

## Funciones obligatorias

| # | Función | Notas |
|---|---------|-------|
| F1 | Registro, inicio y cierre de sesión | JWT emitido por el backend propio; token en `flutter_secure_storage`. |
| F2 | Catálogo de 20 debates propios | Almacenados en SQLite del backend (semilla cargada al iniciar si la tabla está vacía). |
| F3 | Lista por categorías y detalle de debate | Estados de carga, vacío y error en cada pantalla con datos. |
| F4 | Aportes remotos visibles para varios usuarios | Tipos: pregunta, argumento, propuesta. |
| F5 | Crear, editar y eliminar aportes propios | Propiedad comprobada **en el servidor** (403 si no es el autor). |
| F6 | Debates guardados localmente | Hive; sobreviven al cierre completo de la app. Independientes por usuario. |
| F7 | Asistente de contexto y perspectivas | Gemini vía backend propio; usa el contexto del debate y una selección acotada de aportes; clave solo en el servidor. |
| F8 | Calidad | GetX, arquitectura en capas, manejo de errores (401/400/422/5xx/red), pruebas, CI y Release con APK. |

## Versión 1.1.0 (alcance definitivo, decisión del 25/10/2026)

La v1.0.0 (alcance anterior, publicada y validada) no cambia. La v1.1.0 (`1.1.0+2`) **cierra con
las funciones actuales**; no se implementan 7D ni funciones nuevas. Alcance entregado:

- Dashboard de comunidad y participación (7A).
- Creación guiada, borradores privados y publicación de debates (7B).
- Roles usuario/administrador y archivo mediante revisión administrativa (7B).
- Historial de versiones y protección del contexto de los aportes (7B.1).
- Declaración de 18 años o más (7C).
- Referencias bibliográficas de Crossref, solo metadatos (7C).
- Asistente educativo existente (F7, sin cambios).

**No entregado en la v1.1.0:** la redacción con IA del asistente de creación (implementada pero
**desactivada**, `REDACCION_IA_ACTIVA=false`, probada solo con un proveedor simulado); el
procesamiento de resúmenes de las obras (**no se procesan** hasta aprobar una política de
licencias); la investigación científica automatizada o la verificación de afirmaciones; las
métricas de consenso y la construcción de acuerdos. Sigue pendiente revisar el tratamiento de
datos de Gemini (también del asistente educativo) antes de activar la redacción.

Detalle por bloques:

| Bloque | Función | Estado |
|---|---|---|
| 7A | Dashboard de comunidad y participación personal como inicio de la sesión | Implementado y comprobado (ver `docs/SEGUIMIENTO.md`) |
| 7B | Creación de debates por usuarios: borradores privados, publicación, edición sin aportes; archivo mediante solicitud revisada por la administración (roles usuario/administrador) | Implementado y comprobado (ver `docs/SEGUIMIENTO.md`) |
| 7B.1 | Historial de versiones publicadas, protección permanente del contenido tras el primer aporte, aportes vinculados a su versión y aclaraciones del autor | Implementado y comprobado (ver `docs/SEGUIMIENTO.md`) |
| 7C | Referencias bibliográficas localizadas en Crossref (búsqueda, selección y publicación de metadatos) y redacción con Gemini **sin** búsqueda de Google (desactivada por defecto); confirmación de mayoría de edad | Comprobado: declaración de edad y referencias con Crossref real (pruebas automáticas y recorrido manual). Redacción con IA desactivada y probada solo con proveedor simulado; resúmenes sin procesar hasta aprobar una política de licencias (ver `docs/SEGUIMIENTO.md`) |
| — | Construcción de acuerdos y métricas de consenso | Fuera de la v1.1.0; no implementada |

En 7B: cualquier cuenta crea debates con un asistente de 6 pasos; los borradores son privados y
se pueden retomar; publicar los muestra en el catálogo, marcados como contenido de la comunidad no
verificado. Quien lo creó puede editarlo solo mientras no tenga aportes y **solicitar** su archivo con un
motivo; la administración aprueba o rechaza con una justificación, o archiva directamente con un
motivo. No hay borrado físico. El rol de administración solo se concede con un comando local. No incluye
moderación. El dashboard no muestra métricas de consenso.

En 7B.1: cada publicación y edición permitida queda como versión inmutable consultable desde
"Historial", con diferencias por campo. Tras el primer aporte el contenido no se puede reescribir
(aunque se borren los aportes); los debates anteriores al historial quedan protegidos de forma
conservadora. Los aportes indican la versión sobre la que se escribieron y, si el debate cambió
mientras se redactaban, no se publican sin confirmación. El autor puede añadir aclaraciones
fechadas e inmutables. No incluye bifurcaciones ni copias automáticas de debates.

## Exclusiones

No se implementan: mapas o geolocalización, chat en tiempo real, notificaciones, votaciones o
"me gusta", rankings, panel de administración, moderación automática, publicación automática de
textos del asistente, recuperación de contraseña por correo, subida de imágenes.

## Correspondencia con la rúbrica (9 criterios)

| Criterio (peso) | Cómo lo cubre Ágora Joven | Evidencia prevista |
|---|---|---|
| Persistencia remota o colaborativa (20 %) | F4 + F5: CRUD de aportes en SQLite, visible para otros usuarios | Usuario A publica; usuario B lo ve; B recibe 403 al intentar editar el aporte de A (prueba de backend) |
| Autenticación (15 %) | F1 con JWT y almacenamiento seguro | Registro/login/logout en la app; `GET /debates` o `POST /debates/{id}/aportes` sin token → 401 |
| Datos reales (15 %) | F2: 20 debates en la base de datos del backend, no en el código de la app | `GET /debates` devuelve 20 registros |
| Persistencia local (10 %) | F6 con Hive | Guardar, cerrar la app por completo, reabrir y verlo guardado |
| Estado con GetX (10 %) | Controladores GetX para sesión, debates, aportes, guardados, asistente | Código en `app/lib/controllers/`; sin `setState` para estado compartido |
| IA sin secretos (10 %) | F7 vía backend propio; clave solo en `.env` del servidor | Búsqueda de patrones de claves limpia; `.env` ignorado |
| Manejo de errores (10 %) | Mensajes distintos para red, 400, 401, 403, 404, 422 y 5xx | Apagar el backend y ver el estado de error con reintento |
| Arquitectura (5 %) | Pantalla → controlador → repositorio → fuente de datos | Ninguna pantalla importa Dio ni Hive |
| Documentación y entrega (5 %) | README, docs/, CI, Release con APK por etiqueta | Release `v1.0.0` generado por GitHub Actions (lo publica la persona autora) |

## Decisiones acordadas (2026-10-22)

- Debates y aportes requieren sesión. Solo `GET /health`, `POST /auth/registro` y
  `POST /auth/login` son públicos.
- Proveedor de IA: Gemini a través del backend propio; clave exclusivamente en el servidor.
- Sin modo de demostración de IA. Las respuestas preparadas para pruebas nunca se presentan como
  evidencia de integración real.
- Se mantiene `flutter_lints ^6.0.0` (la que genera Flutter 3.47.5).

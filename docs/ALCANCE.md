# Alcance — Ágora Joven

Proyecto Final del curso *Desarrolla Aplicaciones Móviles Robustas con Flutter e IA* (CEDIA).
Entrega: lunes 26 de octubre de 2026, 08:00, en Moodle (enlace al repositorio).

## Propósito

Ágora Joven ayuda a personas jóvenes a **comprender temas públicos**, **consultar debates
ciudadanos** y **publicar preguntas, argumentos o propuestas**.

Los contenidos iniciales son **material editorial de demostración**, identificado como tal en la
app y en el backend. El asistente es **educativo**: explica contexto y resume perspectivas de forma
equilibrada; **nunca publica contenido automáticamente**.

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

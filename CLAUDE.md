@AGENTS.md

## Claude Code

- Responde en español, breve y práctico. Distingue propuesta, acción realizada y resultado verificado.
- Mantén las búsquedas y salidas acotadas (filtra con `head`, `tail` o `--head-limit`); no vuelques
  `build/`, `.dart_tool/`, `.venv/` ni archivos de bloqueo completos.
- Usa el modo plan antes de cambios que toquen varias capas o más de un bloque.
- Pide confirmación antes de commits, `docker compose up/down`, instalar paquetes o borrar archivos.
- No afirmes que la app se probó en emulador si no se ejecutó allí.

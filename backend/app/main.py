"""API de Ágora Joven.

Bloque 0: solo expone la comprobación de salud. Autenticación, debates,
aportes y asistente se añadirán en bloques posteriores (ver docs/ARQUITECTURA.md).
"""

from fastapi import FastAPI

app = FastAPI(title="Ágora Joven API", version="0.1.0")


@app.get("/health", tags=["sistema"])
def health() -> dict[str, str]:
    """Indica que el servicio está en marcha. No consulta dependencias externas."""
    return {"status": "ok", "servicio": "agora-joven-api"}

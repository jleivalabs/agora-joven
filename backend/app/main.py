"""API de Ágora Joven.

Se arranca con la fábrica `create_app` (uvicorn --factory) para que la configuración se lea
al iniciar y no al importar el módulo.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.catalogo import cargar_catalogo
from app.config import Settings
from app.asistente import MAX_TOKENS_SALIDA
from app.db import Base, crear_fabrica_sesiones, crear_motor
from app.ia import GeminiProveedor, ProveedorIA
from app.routers import aportes, asistente, auth, debates


def crear_proveedor(settings: Settings) -> ProveedorIA | None:
    """Gemini si hay clave; si no, None (el asistente responde 503 y el resto funciona)."""
    if settings.gemini_api_key is None:
        return None
    return GeminiProveedor(
        clave=settings.gemini_api_key,
        modelo=settings.gemini_model,
        timeout_segundos=settings.gemini_timeout_segundos,
        base_url=settings.gemini_base_url,
        max_tokens_salida=MAX_TOKENS_SALIDA,
    )


def create_app(
    settings: Settings | None = None, proveedor_ia: ProveedorIA | None = None
) -> FastAPI:
    """[proveedor_ia] permite inyectar un proveedor simulado en las pruebas."""
    settings = settings or Settings()
    proveedor = proveedor_ia or crear_proveedor(settings)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        motor = crear_motor(settings.database_url)
        Base.metadata.create_all(motor)
        app.state.settings = settings
        app.state.proveedor_ia = proveedor
        app.state.fabrica_sesiones = crear_fabrica_sesiones(motor)
        with app.state.fabrica_sesiones() as db:
            cargar_catalogo(db)
        yield
        motor.dispose()

    app = FastAPI(title="Ágora Joven API", version="0.5.0", lifespan=lifespan)

    @app.get("/health", tags=["sistema"])
    def health() -> dict[str, str]:
        """Indica que el servicio está en marcha. No consulta dependencias externas."""
        return {"status": "ok", "servicio": "agora-joven-api"}

    app.include_router(auth.router)
    app.include_router(debates.router)
    app.include_router(aportes.router)
    app.include_router(asistente.router)
    return app

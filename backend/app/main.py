"""API de Ágora Joven.

Se arranca con la fábrica `create_app` (uvicorn --factory) para que la configuración se lea
al iniciar y no al importar el módulo.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.catalogo import cargar_catalogo
from app.config import Settings
from app.db import Base, crear_fabrica_sesiones, crear_motor
from app.routers import auth, debates


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        motor = crear_motor(settings.database_url)
        Base.metadata.create_all(motor)
        app.state.settings = settings
        app.state.fabrica_sesiones = crear_fabrica_sesiones(motor)
        with app.state.fabrica_sesiones() as db:
            cargar_catalogo(db)
        yield
        motor.dispose()

    app = FastAPI(title="Ágora Joven API", version="0.2.0", lifespan=lifespan)

    @app.get("/health", tags=["sistema"])
    def health() -> dict[str, str]:
        """Indica que el servicio está en marcha. No consulta dependencias externas."""
        return {"status": "ok", "servicio": "agora-joven-api"}

    app.include_router(auth.router)
    app.include_router(debates.router)
    return app

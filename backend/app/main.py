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
from app.db import crear_fabrica_sesiones, crear_motor
from app.crossref import CrossrefCliente, FuenteBibliografica
from app.ia import GeminiProveedor, ProveedorIA, ProveedorRedaccion
from app.investigacion import MAX_TOKENS_SALIDA_REDACCION
from app.limites import Limitador
from app.migrar import aplicar_migraciones
from app.routers import (
    aportes,
    asistente,
    auth,
    borradores,
    debates,
    estadisticas,
    investigacion,
    solicitudes,
)


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


def crear_fuente(settings: Settings) -> FuenteBibliografica | None:
    """Crossref si hay correo de contacto configurado; si no, la búsqueda responde 503."""
    if settings.crossref_mailto is None:
        return None
    return CrossrefCliente(
        settings.crossref_mailto,
        settings.crossref_base_url,
        settings.crossref_timeout_segundos,
    )


def crear_redactor(settings: Settings) -> ProveedorRedaccion | None:
    """Solo si REDACCION_IA_ACTIVA=true y hay clave. Desactivada por defecto."""
    if not settings.redaccion_ia_activa or settings.gemini_api_key is None:
        return None
    return GeminiProveedor(
        clave=settings.gemini_api_key,
        modelo=settings.gemini_model,
        timeout_segundos=settings.gemini_timeout_segundos,
        base_url=settings.gemini_base_url,
        max_tokens_salida=MAX_TOKENS_SALIDA_REDACCION,
    )


def create_app(
    settings: Settings | None = None,
    proveedor_ia: ProveedorIA | None = None,
    fuente: FuenteBibliografica | None = None,
    redactor: ProveedorRedaccion | None = None,
) -> FastAPI:
    """Los proveedores se pueden inyectar como simulados en las pruebas."""
    settings = settings or Settings()
    proveedor = proveedor_ia or crear_proveedor(settings)
    fuente = fuente or crear_fuente(settings)
    redactor = redactor or crear_redactor(settings)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        motor = crear_motor(settings.database_url)
        # Migraciones versionadas (Alembic); create_all no modifica tablas existentes.
        aplicar_migraciones(motor)
        app.state.settings = settings
        app.state.proveedor_ia = proveedor
        app.state.fuente = fuente
        app.state.redactor = redactor
        app.state.limitador = Limitador()
        app.state.fabrica_sesiones = crear_fabrica_sesiones(motor)
        with app.state.fabrica_sesiones() as db:
            cargar_catalogo(db)
        yield
        motor.dispose()

    app = FastAPI(title="Ágora Joven API", version="1.1.0-dev", lifespan=lifespan)

    @app.get("/health", tags=["sistema"])
    def health() -> dict[str, str]:
        """Indica que el servicio está en marcha. No consulta dependencias externas."""
        return {"status": "ok", "servicio": "agora-joven-api"}

    app.include_router(auth.router)
    app.include_router(debates.router)
    app.include_router(aportes.router)
    app.include_router(asistente.router)
    app.include_router(estadisticas.router)
    app.include_router(borradores.router)
    app.include_router(solicitudes.router)
    app.include_router(solicitudes.admin)
    app.include_router(investigacion.router)
    return app

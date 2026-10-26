"""Asistente educativo de un debate. Requiere sesión. No guarda ni publica el resultado."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.asistente import AVISO_IA, INSTRUCCIONES, AccionAsistente, construir_consulta
from app.db import get_db
from app.ia import ErrorProveedor, FalloProveedor, ProveedorIA
from app.repositorios import aportes as repo_aportes
from app.repositorios import debates as repo_debates
from app.schemas import AsistenteEntrada, AsistenteSalida
from app.security import usuario_actual

router = APIRouter(
    prefix="/asistente", tags=["asistente"], dependencies=[Depends(usuario_actual)]
)

Db = Annotated[Session, Depends(get_db)]

_ERRORES = {
    FalloProveedor.CUOTA: (
        status.HTTP_429_TOO_MANY_REQUESTS,
        "Se alcanzó el límite de uso del asistente. Inténtalo más tarde.",
    ),
    FalloProveedor.NO_DISPONIBLE: (
        status.HTTP_503_SERVICE_UNAVAILABLE,
        "El asistente no está disponible en este momento.",
    ),
    FalloProveedor.SIN_RESPUESTA: (
        status.HTTP_502_BAD_GATEWAY,
        "El asistente no pudo generar una respuesta adecuada.",
    ),
}


def get_proveedor(request: Request) -> ProveedorIA | None:
    return request.app.state.proveedor_ia


# Función síncrona: FastAPI la ejecuta en un hilo, así la espera al proveedor no bloquea el servidor.
@router.post("/debates/{debate_id}", response_model=AsistenteSalida)
def consultar(
    debate_id: int,
    datos: AsistenteEntrada,
    db: Db,
    proveedor: Annotated[ProveedorIA | None, Depends(get_proveedor)],
) -> AsistenteSalida:
    debate = repo_debates.obtener(db, debate_id)
    if debate is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")
    aportes = [aporte for aporte, _, _ in repo_aportes.listar(db, debate_id)]

    if datos.accion is AccionAsistente.perspectivas and not aportes:
        # Nada que resumir: no se llama al proveedor ni se inventa un resumen.
        return AsistenteSalida(
            debate_id=debate_id,
            accion=datos.accion,
            estado="sin_aportes",
            texto=None,
            aviso=None,
            aportes_usados=0,
            aportes_totales=0,
            parcial=False,
            truncado=False,
        )

    if proveedor is None:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El asistente no está configurado en este servidor.",
        )

    consulta = construir_consulta(datos.accion, debate, aportes)
    try:
        respuesta = proveedor.generar(INSTRUCCIONES, consulta.contenido)
    except ErrorProveedor as e:
        codigo, mensaje = _ERRORES[e.fallo]
        raise HTTPException(codigo, detail=mensaje) from None

    return AsistenteSalida(
        debate_id=debate_id,
        accion=datos.accion,
        estado="generado",
        texto=respuesta.texto,
        aviso=AVISO_IA,
        aportes_usados=consulta.aportes_usados,
        aportes_totales=consulta.aportes_totales,
        parcial=consulta.aportes_usados < consulta.aportes_totales,
        truncado=respuesta.truncado,
    )

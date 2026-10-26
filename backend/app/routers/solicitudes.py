"""Solicitudes de archivo (autores) y su revisión (administración).

- El autor de un debate de usuario activo solicita archivarlo con un motivo. La solicitud no
  archiva ni bloquea nada. Solo hay una pendiente por debate: repetir devuelve la misma (200).
- El solicitante consulta y cancela las suyas; una ajena responde 404.
- La administración (rol leído de la base en cada petición) lista, aprueba o rechaza con una
  justificación. Aprobar archiva el debate en la misma transacción.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import EstadoSolicitud
from app.repositorios import solicitudes as repo
from app.schemas import (
    DebateBreve,
    ResolucionEntrada,
    SolicitudAdmin,
    SolicitudEntrada,
    SolicitudPropia,
    SolicitudPropiaConDebate,
)
from app.security import AdministradorActual, UsuarioActual, usuario_actual

router = APIRouter(tags=["solicitudes de archivo"], dependencies=[Depends(usuario_actual)])
admin = APIRouter(prefix="/admin", tags=["administración"])

Db = Annotated[Session, Depends(get_db)]

NO_ENCONTRADA = "Solicitud no encontrada."
YA_RESUELTA = "Esta solicitud ya se resolvió o se canceló."
YA_ARCHIVADO = "Este debate ya está archivado."


@router.post("/debates/{debate_id}/solicitud-archivo", response_model=SolicitudPropia)
def solicitar(
    debate_id: int, datos: SolicitudEntrada, respuesta: Response, db: Db, usuario: UsuarioActual
) -> SolicitudPropia:
    """201 al crearla; 200 si ya había una pendiente (la misma, sin duplicar)."""
    try:
        solicitud, creada = repo.crear(db, debate_id, usuario.id, datos.motivo)
    except repo.DebateNoEncontrado:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.") from None
    except repo.NoEsAutor:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            detail="Solo quien creó este debate puede solicitar su archivo.",
        ) from None
    except repo.DebateYaArchivado:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=YA_ARCHIVADO) from None
    respuesta.status_code = status.HTTP_201_CREATED if creada else status.HTTP_200_OK
    return SolicitudPropia.model_validate(solicitud)


@router.get("/solicitudes-archivo", response_model=list[SolicitudPropiaConDebate])
def mis_solicitudes(db: Db, usuario: UsuarioActual) -> list[SolicitudPropiaConDebate]:
    return [
        SolicitudPropiaConDebate.model_validate(
            {**SolicitudPropia.model_validate(s).model_dump(), "debate_titulo": titulo}
        )
        for s, titulo in repo.propias(db, usuario.id)
    ]


def _propia(db: Session, solicitud_id: int, usuario_id: int):
    solicitud = repo.obtener(db, solicitud_id)
    if solicitud is None or solicitud.solicitante_id != usuario_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=NO_ENCONTRADA)
    return solicitud


@router.get("/solicitudes-archivo/{solicitud_id}", response_model=SolicitudPropia)
def mi_solicitud(solicitud_id: int, db: Db, usuario: UsuarioActual) -> SolicitudPropia:
    return SolicitudPropia.model_validate(_propia(db, solicitud_id, usuario.id))


@router.post("/solicitudes-archivo/{solicitud_id}/cancelar", response_model=SolicitudPropia)
def cancelar(solicitud_id: int, db: Db, usuario: UsuarioActual) -> SolicitudPropia:
    """Solo mientras esté pendiente. Repetir sobre una cancelada responde igual."""
    try:
        solicitud = repo.cancelar(db, _propia(db, solicitud_id, usuario.id))
    except repo.SolicitudNoPendiente:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=YA_RESUELTA) from None
    return SolicitudPropia.model_validate(solicitud)


# --- Administración ---------------------------------------------------------------------------


def _salida_admin(fila: tuple) -> SolicitudAdmin:
    solicitud, solicitante, revisor, debate, aportes = fila
    return SolicitudAdmin(
        id=solicitud.id,
        estado=solicitud.estado,
        motivo=solicitud.motivo,
        creada_en=solicitud.creada_en,
        resuelta_en=solicitud.resuelta_en,
        justificacion=solicitud.justificacion,
        solicitante_nombre=solicitante,
        revisor_nombre=revisor,
        debate=DebateBreve.model_validate(debate),
        debate_estado=debate.estado,
        debate_resumen=debate.resumen,
        debate_aportes=aportes,
    )


def _una(db: Session, solicitud_id: int) -> SolicitudAdmin:
    filas = repo.para_administracion(db, solicitud_id=solicitud_id)
    if not filas:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=NO_ENCONTRADA)
    return _salida_admin(filas[0])


@admin.get("/solicitudes-archivo", response_model=list[SolicitudAdmin])
def listar_solicitudes(
    db: Db, _: AdministradorActual, estado: EstadoSolicitud | None = EstadoSolicitud.pendiente
) -> list[SolicitudAdmin]:
    """Por defecto, las pendientes por orden de llegada."""
    return [_salida_admin(f) for f in repo.para_administracion(db, estado=estado)]


@admin.get("/solicitudes-archivo/{solicitud_id}", response_model=SolicitudAdmin)
def ver_solicitud(solicitud_id: int, db: Db, _: AdministradorActual) -> SolicitudAdmin:
    return _una(db, solicitud_id)


def _resolver(
    db: Session, solicitud_id: int, revisor_id: int, aprobar: bool, justificacion: str
) -> SolicitudAdmin:
    if repo.obtener(db, solicitud_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=NO_ENCONTRADA)
    try:
        repo.resolver(db, solicitud_id, revisor_id, aprobar, justificacion)
    except repo.SolicitudNoPendiente:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=YA_RESUELTA) from None
    except repo.DebateYaArchivado:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=YA_ARCHIVADO) from None
    return _una(db, solicitud_id)


@admin.post("/solicitudes-archivo/{solicitud_id}/aprobar", response_model=SolicitudAdmin)
def aprobar(
    solicitud_id: int, datos: ResolucionEntrada, db: Db, administrador: AdministradorActual
) -> SolicitudAdmin:
    return _resolver(db, solicitud_id, administrador.id, True, datos.justificacion)


@admin.post("/solicitudes-archivo/{solicitud_id}/rechazar", response_model=SolicitudAdmin)
def rechazar(
    solicitud_id: int, datos: ResolucionEntrada, db: Db, administrador: AdministradorActual
) -> SolicitudAdmin:
    return _resolver(db, solicitud_id, administrador.id, False, datos.justificacion)

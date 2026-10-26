"""Borradores privados y "Mis debates". Todo se resuelve con la cuenta del token.

Un borrador ajeno responde 404 en cualquier operación: no se revela que exista.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Borrador, EstadoDebate, Usuario
from app.repositorios import borradores as repo
from app.repositorios import debates as repo_debates
from app.repositorios import solicitudes as repo_solicitudes
from app.routers.debates import resumen
from app.schemas import (
    BorradorCambios,
    BorradorSalida,
    ContenidoDebate,
    DebateResumen,
    MiDebate,
    MisDebates,
    SolicitudPropia,
)
from app.security import UsuarioActual, usuario_actual

router = APIRouter(tags=["borradores"], dependencies=[Depends(usuario_actual)])

Db = Annotated[Session, Depends(get_db)]


def _propio(db: Session, borrador_id: int, usuario: Usuario) -> Borrador:
    borrador = repo.obtener_propio(db, borrador_id, usuario.id)
    if borrador is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Borrador no encontrado.")
    return borrador


def _ya_publicado() -> HTTPException:
    return HTTPException(
        status.HTTP_409_CONFLICT,
        detail="Este borrador ya se publicó: los cambios se hacen en el debate.",
    )


def _valores(cambios: BorradorCambios) -> dict:
    return cambios.model_dump(mode="json", exclude_unset=True)


@router.get("/borradores", response_model=list[BorradorSalida])
def listar(db: Db, usuario: UsuarioActual) -> list[Borrador]:
    """Borradores sin publicar de la cuenta, del más reciente al más antiguo."""
    return repo.listar_pendientes(db, usuario.id)


@router.post("/borradores", response_model=BorradorSalida, status_code=status.HTTP_201_CREATED)
def crear(cambios: BorradorCambios, db: Db, usuario: UsuarioActual) -> Borrador:
    return repo.crear(db, usuario.id, _valores(cambios))


@router.get("/borradores/{borrador_id}", response_model=BorradorSalida)
def obtener(borrador_id: int, db: Db, usuario: UsuarioActual) -> Borrador:
    return _propio(db, borrador_id, usuario)


@router.patch("/borradores/{borrador_id}", response_model=BorradorSalida)
def actualizar(
    borrador_id: int, cambios: BorradorCambios, db: Db, usuario: UsuarioActual
) -> Borrador:
    try:
        return repo.actualizar(db, _propio(db, borrador_id, usuario), _valores(cambios))
    except repo.BorradorYaPublicado:
        raise _ya_publicado() from None


@router.delete("/borradores/{borrador_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(borrador_id: int, db: Db, usuario: UsuarioActual) -> Response:
    try:
        repo.eliminar(db, _propio(db, borrador_id, usuario))
    except repo.BorradorYaPublicado:
        raise _ya_publicado() from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/borradores/{borrador_id}/publicar", response_model=DebateResumen)
def publicar(
    borrador_id: int, respuesta: Response, db: Db, usuario: UsuarioActual
) -> DebateResumen:
    """Valida el borrador completo y lo publica como debate de la cuenta del token.

    201 al crear el debate; 200 si ya estaba publicado (mismo debate, sin duplicar).
    422 indica qué campos faltan o no cumplen los límites.
    """
    borrador = _propio(db, borrador_id, usuario)
    if borrador.debate_id is None:
        try:
            contenido = ContenidoDebate.model_validate(
                {
                    campo: getattr(borrador, campo)
                    for campo in ContenidoDebate.model_fields
                }
            )
        except ValidationError as e:
            raise RequestValidationError(e.errors(include_url=False, include_context=False))
    else:
        contenido = None
    debate, creado = repo.publicar(db, borrador, contenido)
    respuesta.status_code = status.HTTP_201_CREATED if creado else status.HTTP_200_OK
    return resumen(debate, usuario.nombre)


@router.get("/mis-debates", response_model=MisDebates)
def mis_debates(db: Db, usuario: UsuarioActual) -> MisDebates:
    publicados, archivados = [], []
    solicitudes = repo_solicitudes.ultimas_por_debate(db, usuario.id)
    for debate, aportes in repo_debates.de_autor(db, usuario.id):
        solicitud = solicitudes.get(debate.id)
        item = MiDebate(
            id=debate.id,
            titulo=debate.titulo,
            categoria=debate.categoria,
            estado=debate.estado,
            aportes=aportes,
            publicado_en=debate.publicado_en,
            archivado_en=debate.archivado_en,
            archivo_origen=debate.archivo_origen,
            editable=repo_debates.es_editable(debate, aportes),
            solicitud_archivo=(
                None if solicitud is None else SolicitudPropia.model_validate(solicitud)
            ),
        )
        (publicados if debate.estado == EstadoDebate.publicado.value else archivados).append(item)
    return MisDebates(
        borradores=[BorradorSalida.model_validate(b) for b in repo.listar_pendientes(db, usuario.id)],
        publicados=publicados,
        archivados=archivados,
    )

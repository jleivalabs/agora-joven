"""Rutas del catálogo de debates. Todas requieren sesión.

El catálogo y las categorías muestran solo debates publicados activos. El detalle también sirve
debates archivados (siguen siendo consultables, por ejemplo desde Guardados). Editar solo lo
puede hacer la cuenta autora de un debate de usuario; los editoriales no tienen autor. Archivar
lo hace únicamente la administración: directamente (aquí, con motivo) o aprobando una solicitud
del autor (`routers/solicitudes.py`).
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import ETIQUETAS_CATEGORIA, Categoria, Debate, EstadoDebate, Usuario
from app.repositorios import debates as repo_debates
from app.repositorios import solicitudes as repo_solicitudes
from app.schemas import (
    ArchivoDirectoEntrada,
    CategoriaSalida,
    ContenidoDebate,
    DebateDetalle,
    DebateResumen,
    SolicitudPropia,
)
from app.security import AdministradorActual, UsuarioActual, usuario_actual

router = APIRouter(
    prefix="/debates", tags=["debates"], dependencies=[Depends(usuario_actual)]
)

Db = Annotated[Session, Depends(get_db)]


def resumen(debate: Debate, autor_nombre: str | None) -> DebateResumen:
    return DebateResumen.model_validate(debate).model_copy(update={"autor_nombre": autor_nombre})


def _detalle_salida(db: Session, debate_id: int, usuario: Usuario) -> DebateDetalle:
    fila = repo_debates.detalle(db, debate_id)
    if fila is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")
    debate, autor_nombre, aportes = fila
    propio = debate.autor_id is not None and debate.autor_id == usuario.id
    solicitud = (
        repo_solicitudes.ultimas_por_debate(db, usuario.id).get(debate.id) if propio else None
    )
    return DebateDetalle.model_validate(debate).model_copy(
        update={
            "autor_nombre": autor_nombre,
            "aportes": aportes,
            "es_propio": propio,
            "editable": propio and debate.estado == EstadoDebate.publicado.value and aportes == 0,
            "solicitud_archivo": (
                None if solicitud is None else SolicitudPropia.model_validate(solicitud)
            ),
        }
    )


@router.get("/categorias", response_model=list[CategoriaSalida])
def categorias(db: Db) -> list[CategoriaSalida]:
    """Todas las categorías, en orden fijo, con su número de debates publicados activos."""
    totales = repo_debates.contar_por_categoria(db)
    return [
        CategoriaSalida(categoria=c, etiqueta=ETIQUETAS_CATEGORIA[c], total=totales.get(c, 0))
        for c in Categoria
    ]


@router.get("", response_model=list[DebateResumen])
def listar(db: Db, categoria: Categoria | None = None) -> list[DebateResumen]:
    return [resumen(d, autor) for d, autor in repo_debates.listar(db, categoria)]


@router.get("/{debate_id}", response_model=DebateDetalle)
def detalle(debate_id: int, db: Db, usuario: UsuarioActual) -> DebateDetalle:
    return _detalle_salida(db, debate_id, usuario)


def _motivo_rechazo(db: Session, debate_id: int, usuario: Usuario) -> HTTPException:
    """Explica por qué una edición condicional no se aplicó."""
    fila = repo_debates.detalle(db, debate_id)
    if fila is None:
        return HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")
    debate, _, aportes = fila
    if debate.autor_id is None or debate.autor_id != usuario.id:
        return HTTPException(
            status.HTTP_403_FORBIDDEN, detail="Solo quien creó este debate puede modificarlo."
        )
    if debate.estado == EstadoDebate.archivado.value:
        return HTTPException(status.HTTP_409_CONFLICT, detail="Este debate está archivado.")
    if aportes:
        return HTTPException(
            status.HTTP_409_CONFLICT,
            detail="El debate ya tiene aportes: su contenido queda bloqueado.",
        )
    return HTTPException(status.HTTP_409_CONFLICT, detail="No se pudo modificar el debate.")


@router.put("/{debate_id}", response_model=DebateDetalle)
def editar(
    debate_id: int, contenido: ContenidoDebate, db: Db, usuario: UsuarioActual
) -> DebateDetalle:
    """Sustituye el contenido de un debate propio publicado que aún no tiene aportes."""
    valores = contenido.model_dump(mode="json")
    if not repo_debates.editar_si_permitido(db, debate_id, usuario.id, valores):
        raise _motivo_rechazo(db, debate_id, usuario)
    return _detalle_salida(db, debate_id, usuario)


@router.post("/{debate_id}/archivar", response_model=DebateDetalle)
def archivar(
    debate_id: int, datos: ArchivoDirectoEntrada, db: Db, administrador: AdministradorActual
) -> DebateDetalle:
    """Archivo directo por la administración, con motivo obligatorio (interno).

    Cualquier otra cuenta recibe 403, aunque sea la autora: el autor debe solicitarlo
    (`POST /debates/{id}/solicitud-archivo`). Se conservan el contenido y los aportes.
    """
    try:
        repo_solicitudes.archivar_directamente(db, debate_id, administrador.id, datos.motivo)
    except repo_solicitudes.DebateNoEncontrado:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.") from None
    except repo_solicitudes.DebateYaArchivado:
        raise HTTPException(
            status.HTTP_409_CONFLICT, detail="Este debate ya está archivado."
        ) from None
    return _detalle_salida(db, debate_id, administrador)

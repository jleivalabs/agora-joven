"""Acceso a datos del catálogo de debates (editoriales y de usuarios)."""

from enum import StrEnum

from sqlalchemy import exists, func, select, update
from sqlalchemy.orm import Session

from app.models import (
    Aporte,
    Categoria,
    Debate,
    EstadoDebate,
    Procedencia,
    TipoVersion,
    Usuario,
    ahora_utc,
)
from app.repositorios import versiones as repo_versiones

PUBLICADO = EstadoDebate.publicado.value


def contar_por_categoria(db: Session) -> dict[str, int]:
    """Debates publicados activos (no archivados) por categoría."""
    filas = db.execute(
        select(Debate.categoria, func.count())
        .where(Debate.estado == PUBLICADO)
        .group_by(Debate.categoria)
    )
    return {categoria: total for categoria, total in filas}


def listar(db: Session, categoria: Categoria | None = None) -> list[tuple[Debate, str | None]]:
    """Catálogo: solo publicados activos, con el nombre del autor si lo hay. Orden por id."""
    consulta = (
        select(Debate, Usuario.nombre)
        .outerjoin(Usuario, Debate.autor_id == Usuario.id)
        .where(Debate.estado == PUBLICADO)
        .order_by(Debate.id)
    )
    if categoria is not None:
        consulta = consulta.where(Debate.categoria == categoria.value)
    return [(debate, nombre) for debate, nombre in db.execute(consulta)]


def obtener(db: Session, debate_id: int) -> Debate | None:
    """Cualquier debate publicado o archivado (los archivados siguen siendo consultables)."""
    return db.get(Debate, debate_id)


def detalle(db: Session, debate_id: int) -> tuple[Debate, str | None, int] | None:
    fila = db.execute(
        select(
            Debate,
            Usuario.nombre,
            select(func.count(Aporte.id))
            .where(Aporte.debate_id == Debate.id)
            .scalar_subquery(),
        )
        .outerjoin(Usuario, Debate.autor_id == Usuario.id)
        .where(Debate.id == debate_id)
    ).first()
    return None if fila is None else (fila[0], fila[1], fila[2])


def _sin_aportes(debate_id: int):
    return ~exists().where(Aporte.debate_id == debate_id)


def es_editable(debate: Debate, aportes: int) -> bool:
    """Contenido reescribible: debate de usuario publicado, sin participación registrada nunca,
    sin bloqueo histórico y sin aportes. La autoría se comprueba aparte."""
    return (
        debate.procedencia == Procedencia.usuario.value
        and debate.estado == PUBLICADO
        and not debate.con_participacion
        and not debate.bloqueo_historico
        and aportes == 0
    )


class ResultadoEdicion(StrEnum):
    editado = "editado"  # se creó una versión nueva
    sin_cambios = "sin_cambios"  # contenido idéntico: no se crea versión
    rechazado = "rechazado"  # no cumple las condiciones (el motivo se averigua aparte)


def editar_si_permitido(
    db: Session, debate_id: int, autor_id: int, valores: dict, motivo: str
) -> ResultadoEdicion:
    """Edita y crea la versión siguiente en una transacción.

    1. Un UPDATE condicionado (autor, publicado, nunca con participación, sin bloqueo histórico,
       sin aportes) toma el bloqueo de escritura de SQLite y comprueba los permisos de forma
       atómica: un aporte simultáneo no puede colarse entre la comprobación y el cambio, porque
       publicar un aporte también escribe en `debates` antes de insertarse.
    2. Con el bloqueo tomado, si el contenido es idéntico no se crea versión.
    3. Si cambia, se actualiza el debate, se incrementa `version_actual` y se inserta la versión.
    """
    permitido = db.execute(
        update(Debate)
        .where(
            Debate.id == debate_id,
            Debate.autor_id == autor_id,
            Debate.procedencia == Procedencia.usuario.value,
            Debate.estado == PUBLICADO,
            Debate.con_participacion.is_(False),
            Debate.bloqueo_historico.is_(False),
            _sin_aportes(debate_id),
        )
        .values(id=Debate.id)  # sin cambios visibles: solo comprueba y bloquea
        .execution_options(synchronize_session=False)
    )
    if permitido.rowcount != 1:
        db.rollback()
        return ResultadoEdicion.rechazado
    debate = db.execute(
        select(Debate).where(Debate.id == debate_id).execution_options(populate_existing=True)
    ).scalar_one()
    if repo_versiones.contenido_de(debate) == repo_versiones.contenido_de(valores):
        db.rollback()
        return ResultadoEdicion.sin_cambios
    numero = (debate.version_actual or 0) + 1
    for campo, valor in valores.items():
        setattr(debate, campo, valor)
    debate.version_actual = numero
    debate.actualizado_en = ahora_utc()
    db.flush()
    repo_versiones.nueva_version(
        db, debate, numero, TipoVersion.edicion, autor_id=autor_id, motivo=motivo
    )
    db.commit()
    return ResultadoEdicion.editado


def de_autor(db: Session, autor_id: int) -> list[tuple[Debate, int]]:
    """Debates publicados o archivados de la cuenta, con su número de aportes."""
    aportes = (
        select(func.count(Aporte.id)).where(Aporte.debate_id == Debate.id).scalar_subquery()
    )
    filas = db.execute(
        select(Debate, aportes)
        .where(Debate.autor_id == autor_id)
        .order_by(Debate.publicado_en.desc(), Debate.id.desc())
    )
    return [(debate, total) for debate, total in filas]

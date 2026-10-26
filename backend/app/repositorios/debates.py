"""Acceso a datos del catálogo de debates (editoriales y de usuarios)."""

from sqlalchemy import exists, func, select, update
from sqlalchemy.orm import Session

from app.models import Aporte, Categoria, Debate, EstadoDebate, Procedencia, Usuario, ahora_utc

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


def editar_si_permitido(db: Session, debate_id: int, autor_id: int, valores: dict) -> bool:
    """Una sola sentencia condicional (atómica en SQLite): solo si la cuenta es la autora, el
    debate está publicado y no tiene aportes en ese momento."""
    resultado = db.execute(
        update(Debate)
        .where(
            Debate.id == debate_id,
            Debate.autor_id == autor_id,
            Debate.procedencia == Procedencia.usuario.value,
            Debate.estado == PUBLICADO,
            _sin_aportes(debate_id),
        )
        .values(**valores, actualizado_en=ahora_utc())
        .execution_options(synchronize_session=False)
    )
    db.commit()
    return resultado.rowcount == 1


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

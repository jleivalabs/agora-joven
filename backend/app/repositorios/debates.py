"""Acceso a datos del catálogo de debates."""

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Categoria, Debate


def contar_por_categoria(db: Session) -> dict[str, int]:
    filas = db.execute(select(Debate.categoria, func.count()).group_by(Debate.categoria))
    return {categoria: total for categoria, total in filas}


def listar(db: Session, categoria: Categoria | None = None) -> list[Debate]:
    """Orden estable: el del catálogo editorial (id ascendente)."""
    consulta = select(Debate).order_by(Debate.id)
    if categoria is not None:
        consulta = consulta.where(Debate.categoria == categoria.value)
    return list(db.scalars(consulta))


def obtener(db: Session, debate_id: int) -> Debate | None:
    return db.get(Debate, debate_id)

"""Consultas agregadas para el dashboard. Se calculan en la base, sin cargar todos los aportes."""

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Aporte, Debate

# Límites de los listados (documentados en docs/ARQUITECTURA.md → Dashboard).
LIMITE_RECIENTES = 5
LIMITE_SIN_APORTES = 5


def total_debates(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(Debate)) or 0


def debates_por_categoria(db: Session) -> dict[str, int]:
    filas = db.execute(select(Debate.categoria, func.count()).group_by(Debate.categoria))
    return {categoria: total for categoria, total in filas}


def total_aportes(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(Aporte)) or 0


def participantes(db: Session) -> int:
    """Cuentas distintas con al menos un aporte (no las cuentas registradas)."""
    return db.scalar(select(func.count(func.distinct(Aporte.autor_id)))) or 0


def debates_sin_aportes(db: Session) -> tuple[int, list[Debate]]:
    """Total y los primeros en el orden del catálogo (id ascendente)."""
    sin_aportes = ~select(Aporte.id).where(Aporte.debate_id == Debate.id).exists()
    total = db.scalar(select(func.count()).select_from(Debate).where(sin_aportes)) or 0
    debates = list(
        db.scalars(select(Debate).where(sin_aportes).order_by(Debate.id).limit(LIMITE_SIN_APORTES))
    )
    return total, debates


def debates_con_actividad_reciente(db: Session) -> list[tuple[Debate, int, datetime]]:
    """Debates con aportes, por la fecha de su aporte más reciente (desc) y luego id (desc)."""
    actividad = (
        select(
            Aporte.debate_id,
            func.count(Aporte.id).label("aportes"),
            func.max(Aporte.creado_en).label("ultimo"),
        )
        .group_by(Aporte.debate_id)
        .subquery()
    )
    filas = db.execute(
        select(Debate, actividad.c.aportes, actividad.c.ultimo)
        .join(actividad, actividad.c.debate_id == Debate.id)
        .order_by(actividad.c.ultimo.desc(), Debate.id.desc())
        .limit(LIMITE_RECIENTES)
    )
    return [(debate, aportes, ultimo) for debate, aportes, ultimo in filas]


def mis_aportes_por_tipo(db: Session, usuario_id: int) -> dict[str, int]:
    filas = db.execute(
        select(Aporte.tipo, func.count())
        .where(Aporte.autor_id == usuario_id)
        .group_by(Aporte.tipo)
    )
    return {tipo: total for tipo, total in filas}


def mis_debates_participados(db: Session, usuario_id: int) -> int:
    return (
        db.scalar(
            select(func.count(func.distinct(Aporte.debate_id))).where(
                Aporte.autor_id == usuario_id
            )
        )
        or 0
    )


def mis_aportes_recientes(db: Session, usuario_id: int) -> list[tuple[Aporte, Debate]]:
    filas = db.execute(
        select(Aporte, Debate)
        .join(Debate, Aporte.debate_id == Debate.id)
        .where(Aporte.autor_id == usuario_id)
        .order_by(Aporte.creado_en.desc(), Aporte.id.desc())
        .limit(LIMITE_RECIENTES)
    )
    return [(aporte, debate) for aporte, debate in filas]

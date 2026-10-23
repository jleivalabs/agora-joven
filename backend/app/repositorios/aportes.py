"""Acceso a datos de aportes."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Aporte, Usuario, ahora_utc


def listar(db: Session, debate_id: int) -> list[tuple[Aporte, str]]:
    """Aportes del debate con el nombre de su autor. Más recientes primero; desempate por id."""
    consulta = (
        select(Aporte, Usuario.nombre)
        .join(Usuario, Aporte.autor_id == Usuario.id)
        .where(Aporte.debate_id == debate_id)
        .order_by(Aporte.creado_en.desc(), Aporte.id.desc())
    )
    return [(aporte, nombre) for aporte, nombre in db.execute(consulta)]


def obtener(db: Session, aporte_id: int) -> Aporte | None:
    return db.get(Aporte, aporte_id)


def crear(db: Session, debate_id: int, autor_id: int, tipo: str, texto: str) -> Aporte:
    aporte = Aporte(debate_id=debate_id, autor_id=autor_id, tipo=tipo, texto=texto)
    db.add(aporte)
    db.commit()
    return aporte


def actualizar(db: Session, aporte: Aporte, cambios: dict[str, str]) -> Aporte:
    """Aplica solo los valores distintos; marca la edición si algo cambió."""
    distintos = {k: v for k, v in cambios.items() if getattr(aporte, k) != v}
    for campo, valor in distintos.items():
        setattr(aporte, campo, valor)
    if distintos:
        aporte.editado_en = ahora_utc()
        db.commit()
    return aporte


def eliminar(db: Session, aporte: Aporte) -> None:
    db.delete(aporte)
    db.commit()

"""Borradores privados. Todas las consultas filtran por autor: no existe acceso a los ajenos."""

from uuid import uuid4

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.models import (
    ORIGEN_USUARIO,
    Borrador,
    Debate,
    EstadoDebate,
    Procedencia,
    TipoVersion,
    ahora_utc,
)
from app.repositorios import versiones as repo_versiones
from app.schemas import ContenidoDebate


class BorradorYaPublicado(Exception):
    pass


def listar_pendientes(db: Session, autor_id: int) -> list[Borrador]:
    return list(
        db.scalars(
            select(Borrador)
            .where(Borrador.autor_id == autor_id, Borrador.debate_id.is_(None))
            .order_by(Borrador.actualizado_en.desc(), Borrador.id.desc())
        )
    )


def contar_pendientes(db: Session, autor_id: int) -> int:
    return (
        db.scalar(
            select(func.count())
            .select_from(Borrador)
            .where(Borrador.autor_id == autor_id, Borrador.debate_id.is_(None))
        )
        or 0
    )


def obtener_propio(db: Session, borrador_id: int, autor_id: int) -> Borrador | None:
    """None tanto si no existe como si es de otra cuenta (no se revela su existencia)."""
    return db.scalar(
        select(Borrador).where(Borrador.id == borrador_id, Borrador.autor_id == autor_id)
    )


def crear(db: Session, autor_id: int, valores: dict) -> Borrador:
    borrador = Borrador(autor_id=autor_id, **valores)
    db.add(borrador)
    db.commit()
    return borrador


def actualizar(db: Session, borrador: Borrador, valores: dict) -> Borrador:
    if borrador.debate_id is not None:
        raise BorradorYaPublicado
    for campo, valor in valores.items():
        setattr(borrador, campo, valor)
    borrador.actualizado_en = ahora_utc()
    db.commit()
    return borrador


def eliminar(db: Session, borrador: Borrador) -> None:
    if borrador.debate_id is not None:
        raise BorradorYaPublicado
    db.delete(borrador)
    db.commit()


def publicar(db: Session, borrador: Borrador, contenido: ContenidoDebate) -> tuple[Debate, bool]:
    """Crea el debate y enlaza el borrador en una sola transacción.

    Devuelve (debate, creado). Si el borrador ya estaba publicado, o se publica a la vez desde
    otra petición, devuelve el debate existente sin crear otro.
    """
    if borrador.debate_id is not None:
        return db.get(Debate, borrador.debate_id), False

    ahora = ahora_utc()
    debate = Debate(
        slug=f"u-{uuid4().hex}",
        procedencia=Procedencia.usuario.value,
        estado=EstadoDebate.publicado.value,
        autor_id=borrador.autor_id,
        origen=ORIGEN_USUARIO,
        publicado_en=ahora,
        **contenido.model_dump(mode="json"),
    )
    db.add(debate)
    db.flush()  # INSERT: toma el bloqueo de escritura de SQLite
    enlazado = db.execute(
        update(Borrador)
        .where(Borrador.id == borrador.id, Borrador.debate_id.is_(None))
        .values(debate_id=debate.id, actualizado_en=ahora)
        .execution_options(synchronize_session=False)
    )
    if enlazado.rowcount != 1:
        db.rollback()  # otra petición lo publicó primero: se descarta este debate
        existente = db.scalar(select(Borrador.debate_id).where(Borrador.id == borrador.id))
        return db.get(Debate, existente), False
    # Versión 1 inmutable con el contenido publicado (los guardados del borrador no son versiones).
    debate.version_actual = 1
    repo_versiones.nueva_version(
        db, debate, 1, TipoVersion.publicacion, autor_id=borrador.autor_id
    )
    db.commit()
    return debate, True

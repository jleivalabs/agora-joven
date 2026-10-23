"""Acceso a datos de usuarios."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Usuario


class EmailDuplicado(Exception):
    pass


def obtener(db: Session, usuario_id: int) -> Usuario | None:
    return db.get(Usuario, usuario_id)


def obtener_por_email(db: Session, email: str) -> Usuario | None:
    return db.scalar(select(Usuario).where(Usuario.email == email))


def crear(db: Session, nombre: str, email: str, password_hash: str) -> Usuario:
    usuario = Usuario(nombre=nombre, email=email, password_hash=password_hash)
    db.add(usuario)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise EmailDuplicado from None
    return usuario

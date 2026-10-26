"""Acceso a datos de usuarios."""

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Usuario, ahora_utc


class EmailDuplicado(Exception):
    pass


def obtener(db: Session, usuario_id: int) -> Usuario | None:
    return db.get(Usuario, usuario_id)


def obtener_por_email(db: Session, email: str) -> Usuario | None:
    return db.scalar(select(Usuario).where(Usuario.email == email))


def crear(db: Session, nombre: str, email: str, password_hash: str) -> Usuario:
    """Solo se llama tras validar la declaración de mayoría de edad del registro."""
    usuario = Usuario(
        nombre=nombre,
        email=email,
        password_hash=password_hash,
        mayoria_edad_declarada_en=ahora_utc(),
    )
    db.add(usuario)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise EmailDuplicado from None
    return usuario


def declarar_mayoria_edad(db: Session, usuario: Usuario) -> Usuario:
    if usuario.mayoria_edad_declarada_en is None:
        usuario.mayoria_edad_declarada_en = ahora_utc()
        db.commit()
    return usuario

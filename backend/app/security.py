"""Contraseñas (Argon2), tokens JWT y dependencia de usuario autenticado."""

from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from sqlalchemy.orm import Session

from app.config import JWT_ALGORITMO, Settings
from app.db import get_db
from app.models import Usuario
from app.repositorios import usuarios as repo_usuarios

_hasher = PasswordHash.recommended()  # Argon2id
# Se verifica contra este hash cuando el correo no existe, para igualar el tiempo de respuesta.
_HASH_SENUELO = _hasher.hash("contraseña-señuelo-sin-uso")

_bearer = HTTPBearer(auto_error=False)



def no_autenticado() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Sesión no válida o caducada. Inicia sesión de nuevo.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def hashear_password(password: str) -> str:
    return _hasher.hash(password)


def verificar_password(password: str, password_hash: str | None) -> bool:
    if password_hash is None:
        _hasher.verify(password, _HASH_SENUELO)
        return False
    return _hasher.verify(password, password_hash)


def crear_token(usuario_id: int, settings: Settings, ahora: datetime | None = None) -> str:
    emitido = ahora or datetime.now(timezone.utc)
    carga = {
        "sub": str(usuario_id),
        "iat": emitido,
        "exp": emitido + timedelta(minutes=settings.jwt_expira_minutos),
    }
    return jwt.encode(carga, settings.jwt_secret.get_secret_value(), algorithm=JWT_ALGORITMO)


def leer_usuario_id(token: str, settings: Settings) -> int:
    """Devuelve el id del token o lanza 401 si falta firma válida, caducidad o sujeto."""
    try:
        carga = jwt.decode(
            token,
            settings.jwt_secret.get_secret_value(),
            algorithms=[JWT_ALGORITMO],
            options={"require": ["exp", "iat", "sub"]},
        )
        return int(carga["sub"])
    except (jwt.InvalidTokenError, ValueError):
        raise no_autenticado() from None


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def usuario_actual(
    credenciales: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
    db: Annotated[Session, Depends(get_db)],
) -> Usuario:
    if credenciales is None or credenciales.scheme.lower() != "bearer":
        raise no_autenticado()
    usuario = repo_usuarios.obtener(db, leer_usuario_id(credenciales.credentials, settings))
    if usuario is None:
        raise no_autenticado()
    return usuario


UsuarioActual = Annotated[Usuario, Depends(usuario_actual)]

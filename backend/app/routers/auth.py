"""Rutas de autenticación: registro, inicio de sesión y usuario actual."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import Settings
from app.db import get_db
from app.repositorios import usuarios as repo_usuarios
from app.schemas import (
    ConfirmacionEdadEntrada,
    LoginEntrada,
    RegistroEntrada,
    TokenSalida,
    UsuarioSalida,
    normalizar_email,
)
from app.security import (
    UsuarioAutenticado,
    crear_token,
    get_settings,
    hashear_password,
    verificar_password,
)

router = APIRouter(prefix="/auth", tags=["autenticación"])

Db = Annotated[Session, Depends(get_db)]


@router.post("/registro", response_model=UsuarioSalida, status_code=status.HTTP_201_CREATED)
def registro(datos: RegistroEntrada, db: Db) -> UsuarioSalida:
    try:
        usuario = repo_usuarios.crear(
            db, datos.nombre, datos.email, hashear_password(datos.password)
        )
    except repo_usuarios.EmailDuplicado:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe una cuenta con ese correo.",
        ) from None
    return _salida(usuario)


@router.post("/login", response_model=TokenSalida)
def login(
    datos: LoginEntrada,
    db: Db,
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenSalida:
    usuario = repo_usuarios.obtener_por_email(db, normalizar_email(datos.email))
    if not verificar_password(datos.password, usuario.password_hash if usuario else None):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenSalida(
        access_token=crear_token(usuario.id, settings),
        expira_en=settings.jwt_expira_minutos * 60,
    )


@router.get("/me", response_model=UsuarioSalida)
def me(usuario: UsuarioAutenticado) -> UsuarioSalida:
    """Disponible aunque la edad esté pendiente: la app lo usa para pedir la confirmación."""
    return _salida(usuario)


@router.post("/confirmar-edad", response_model=UsuarioSalida)
def confirmar_edad(
    _: ConfirmacionEdadEntrada, db: Db, usuario: UsuarioAutenticado
) -> UsuarioSalida:
    """La cuenta declara tener 18 años o más. Repetir no cambia la fecha de la primera
    declaración. No se piden documentos ni fecha de nacimiento."""
    return _salida(repo_usuarios.declarar_mayoria_edad(db, usuario))


def _salida(usuario) -> UsuarioSalida:
    return UsuarioSalida(
        id=usuario.id,
        nombre=usuario.nombre,
        email=usuario.email,
        creado_en=usuario.creado_en,
        rol=usuario.rol,
        edad_confirmada=usuario.mayoria_edad_declarada_en is not None,
    )

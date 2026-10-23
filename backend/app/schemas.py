"""Esquemas de entrada y salida de la API."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import Categoria


def normalizar_email(email: str) -> str:
    return email.strip().lower()


class RegistroEntrada(BaseModel):
    nombre: str = Field(min_length=2, max_length=60)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @field_validator("nombre")
    @classmethod
    def _limpiar_nombre(cls, valor: str) -> str:
        valor = " ".join(valor.split())
        if len(valor) < 2:
            raise ValueError("El nombre debe tener al menos 2 caracteres.")
        return valor

    @field_validator("email")
    @classmethod
    def _normalizar(cls, valor: str) -> str:
        return normalizar_email(valor)


class LoginEntrada(BaseModel):
    # Sin EmailStr: un correo mal escrito debe dar 401, no revelar reglas de formato.
    email: str = Field(min_length=1, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class UsuarioSalida(BaseModel):
    """Datos públicos del usuario autenticado. Nunca incluye la contraseña ni su hash."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    nombre: str
    email: str
    creado_en: datetime


class TokenSalida(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expira_en: int = Field(description="Segundos hasta la caducidad del token.")


class CategoriaSalida(BaseModel):
    categoria: Categoria
    etiqueta: str
    total: int


class Perspectiva(BaseModel):
    titulo: str = Field(min_length=3)
    descripcion: str = Field(min_length=20)


class DebateResumen(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    titulo: str
    categoria: Categoria
    resumen: str
    origen: str


class DebateDetalle(DebateResumen):
    contexto: str
    perspectivas: list[Perspectiva]
    actualizado_en: datetime

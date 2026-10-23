"""Configuración del servidor, leída del entorno (o de backend/.env en desarrollo local).

No hay secreto predeterminado: si JWT_SECRET falta o es demasiado corto, el arranque falla.
"""

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

JWT_ALGORITMO = "HS256"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    jwt_secret: SecretStr = Field(min_length=32)
    jwt_expira_minutos: int = Field(default=60, ge=1, le=7 * 24 * 60)
    database_url: str = "sqlite:///./data/agora.db"

"""Configuración del servidor, leída del entorno (o de backend/.env en desarrollo local).

No hay secreto predeterminado: si JWT_SECRET falta o es demasiado corto, el arranque falla.
GEMINI_API_KEY es opcional: sin ella el backend arranca y solo el asistente responde 503.
"""

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

JWT_ALGORITMO = "HS256"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    jwt_secret: SecretStr = Field(min_length=32)
    jwt_expira_minutos: int = Field(default=60, ge=1, le=7 * 24 * 60)
    database_url: str = "sqlite:///./data/agora.db"

    # Asistente (Gemini). La clave vive solo en el entorno del servidor.
    gemini_api_key: SecretStr | None = None
    # Modelo estable de la familia Flash-Lite (ver docs/ARQUITECTURA.md → Asistente).
    gemini_model: str = Field(default="gemini-3.5-flash-lite", pattern=r"^[a-z0-9.\-]+$")
    gemini_timeout_segundos: float = Field(default=25, gt=0, le=60)
    gemini_base_url: str = "https://generativelanguage.googleapis.com"

    @field_validator("gemini_api_key", mode="before")
    @classmethod
    def _clave_vacia_es_ausente(cls, valor: object) -> object:
        if valor is None or (isinstance(valor, str) and not valor.strip()):
            return None
        return valor

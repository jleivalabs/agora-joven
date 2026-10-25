"""Esquemas de entrada y salida de la API."""

from datetime import datetime
from typing import Annotated, Literal, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

from app.asistente import AccionAsistente
from app.models import Categoria, TipoAporte


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


# Se quitan los espacios exteriores antes de comprobar la longitud.
TextoAporte = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=10, max_length=1000)
]


class AporteEntrada(BaseModel):
    """Cuerpo de POST. Campos extra (autor_id, debate_id…) se rechazan con 422."""

    model_config = ConfigDict(extra="forbid")

    tipo: TipoAporte
    texto: TextoAporte


class AporteCambios(BaseModel):
    """Cuerpo de PATCH: cambios parciales; al menos un campo y ninguno nulo."""

    model_config = ConfigDict(extra="forbid")

    tipo: TipoAporte | None = None
    texto: TextoAporte | None = None

    @model_validator(mode="after")
    def _cambios_validos(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("Indica al menos un campo para cambiar.")
        nulos = [c for c in self.model_fields_set if getattr(self, c) is None]
        if nulos:
            raise ValueError(f"Estos campos no pueden ser nulos: {', '.join(sorted(nulos))}.")
        return self


class AporteSalida(BaseModel):
    """Aporte visible para cualquier usuario autenticado. Sin correo ni datos privados."""

    id: int
    debate_id: int
    tipo: TipoAporte
    texto: str
    autor_nombre: str
    creado_en: datetime
    editado_en: datetime | None
    es_propio: bool = Field(description="Calculado en el servidor para quien consulta.")


class AsistenteEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    accion: AccionAsistente


class AsistenteSalida(BaseModel):
    """Resultado educativo generado por IA. No se guarda ni se publica como aporte."""

    debate_id: int
    accion: AccionAsistente
    estado: Literal["generado", "sin_aportes"]
    texto: str | None
    aviso: str | None
    aportes_usados: int
    aportes_totales: int
    parcial: bool = Field(description="True si el resumen usó solo parte de los aportes.")
    truncado: bool = Field(description="True si la respuesta alcanzó el límite de longitud.")


class DebateBreve(BaseModel):
    """Identificación mínima de un debate para listados del dashboard."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    titulo: str
    categoria: Categoria


class DebateConActividad(BaseModel):
    debate: DebateBreve
    aportes: int
    ultimo_aporte_en: datetime


class DebatesSinAportes(BaseModel):
    total: int
    debates: list[DebateBreve]


class EstadisticasComunidad(BaseModel):
    """Cifras públicas agregadas. No contiene identidades, correos ni nombres."""

    total_debates: int
    por_categoria: list[CategoriaSalida]
    total_aportes: int
    participantes: int = Field(description="Cuentas distintas con al menos un aporte.")
    sin_aportes: DebatesSinAportes
    actividad_reciente: list[DebateConActividad]


class AportesPorTipo(BaseModel):
    pregunta: int
    argumento: int
    propuesta: int


class MiAporteReciente(BaseModel):
    id: int
    tipo: TipoAporte
    texto: str
    creado_en: datetime
    editado_en: datetime | None
    debate: DebateBreve


class EstadisticasPersonales(BaseModel):
    """Participación de la cuenta del token. No acepta identificadores de otras cuentas."""

    total_aportes: int
    por_tipo: AportesPorTipo
    debates_participados: int
    aportes_recientes: list[MiAporteReciente]

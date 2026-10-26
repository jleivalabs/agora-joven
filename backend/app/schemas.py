"""Esquemas de entrada y salida de la API."""

from datetime import datetime
from typing import Annotated, Literal, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    StrictBool,
    StringConstraints,
    field_validator,
    model_validator,
)

from app.asistente import AccionAsistente
from app.models import (
    Categoria,
    EstadoDebate,
    EstadoSolicitud,
    OrigenArchivo,
    Procedencia,
    Rol,
    TipoAporte,
    TipoVersion,
)


def normalizar_email(email: str) -> str:
    return email.strip().lower()


class RegistroEntrada(BaseModel):
    """El registro siempre crea cuentas con rol `usuario`. Cualquier otro campo (`rol`, `id`…)
    se rechaza con 422: el rol no se puede elegir ni cambiar desde la API pública."""

    model_config = ConfigDict(extra="forbid")

    nombre: str = Field(min_length=2, max_length=60)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    # 7C: declaración obligatoria de tener 18 años o más. Booleano estricto: solo `true` (ni
    # "true", ni 1). Es una declaración de la persona, no una verificación de edad.
    confirma_mayoria_edad: StrictBool

    @field_validator("confirma_mayoria_edad")
    @classmethod
    def _exigir_confirmacion(cls, valor: bool) -> bool:
        if valor is not True:
            raise ValueError("Debes confirmar que tienes 18 años o más.")
        return valor

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
    # Informativo para la interfaz; los permisos se comprueban siempre en el servidor.
    rol: Rol
    # False: la cuenta aún no declaró tener 18 años o más; solo puede consultar /auth/me y
    # confirmar en /auth/confirmar-edad.
    edad_confirmada: bool


class ConfirmacionEdadEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    confirma_mayoria_edad: StrictBool

    @field_validator("confirma_mayoria_edad")
    @classmethod
    def _exigir_confirmacion(cls, valor: bool) -> bool:
        if valor is not True:
            raise ValueError("Debes confirmar que tienes 18 años o más.")
        return valor


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
    procedencia: Procedencia
    estado: EstadoDebate
    # Nombre visible de quien creó el debate (nunca el correo); None en los editoriales.
    autor_nombre: str | None = None


class DebateDetalle(DebateResumen):
    contexto: str
    perspectivas: list[Perspectiva]
    actualizado_en: datetime
    ambito: str | None = None
    objetivo: str | None = None
    publicado_en: datetime | None = None
    archivado_en: datetime | None = None
    # Público: cómo se archivó (sin revisor ni motivos internos).
    archivo_origen: OrigenArchivo | None = None
    aportes: int = 0
    es_propio: bool = False
    editable: bool = Field(
        default=False,
        description="La cuenta del token es la autora, está publicado y aún no tiene aportes.",
    )
    # Solo para la cuenta autora: su solicitud de archivo más reciente sobre este debate.
    solicitud_archivo: "SolicitudPropia | None" = None
    # 7B.1: versión vigente, protección del contenido y aclaraciones del autor.
    version_actual: int | None = None
    # 7C: fuentes publicadas (metadatos bibliográficos) y procedencia de texto sugerido por IA.
    # Vacías en los debates anteriores: no se les atribuye investigación.
    referencias: list["ReferenciaSalida"] = []
    evidencias: list["EvidenciaSalida"] = []

    @field_validator("referencias", "evidencias", mode="before")
    @classmethod
    def _sin_datos_es_vacio(cls, valor: object) -> object:
        return valor or []

    motivo_bloqueo: Literal["participacion", "historico"] | None = Field(
        default=None,
        description="Por qué el contenido ya no se puede reescribir (si aplica).",
    )
    aclaraciones: list["AclaracionSalida"] = []


# Se quitan los espacios exteriores antes de comprobar la longitud.
TextoAporte = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=10, max_length=1000)
]


class AporteEntrada(BaseModel):
    """Cuerpo de POST. Campos extra (autor_id, debate_id…) se rechazan con 422."""

    model_config = ConfigDict(extra="forbid")

    tipo: TipoAporte
    texto: TextoAporte
    # Número de la versión del debate que la persona estaba viendo (7B.1). Si ya no es la
    # vigente, el servidor responde 409 `version_desactualizada` y no publica.
    version: int = Field(ge=1)


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
    version: int | None = Field(
        default=None,
        description="Versión del debate al publicar el aporte. None: anterior al historial "
        "(versión original desconocida).",
    )


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

    total_debates: int = Field(description="Debates publicados activos (sin archivados).")
    debates_archivados: int
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
    mis_debates: "MisDebatesTotales"


# --- Bloque 7B: creación de debates por usuarios -------------------------------------------

def _texto(minimo: int, maximo: int):
    return Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=minimo, max_length=maximo)
    ]


LIMITES = {
    "ambito": (3, 120),
    "titulo": (10, 160),
    "resumen": (30, 300),
    "contexto": (80, 3000),
    "objetivo": (20, 500),
    "perspectiva_titulo": (3, 80),
    "perspectiva_descripcion": (20, 600),
}
MIN_PERSPECTIVAS, MAX_PERSPECTIVAS = 2, 5


class PerspectivaNueva(BaseModel):
    model_config = ConfigDict(extra="forbid")

    titulo: _texto(*LIMITES["perspectiva_titulo"])
    descripcion: _texto(*LIMITES["perspectiva_descripcion"])


class ContenidoDebate(BaseModel):
    """Contenido completo y válido de un debate de usuario (al publicar o editar).

    No incluye autor, estado, procedencia ni ids: se rechazan como campos extra (422).
    """

    model_config = ConfigDict(extra="forbid")

    categoria: Categoria
    ambito: _texto(*LIMITES["ambito"])
    titulo: _texto(*LIMITES["titulo"])
    resumen: _texto(*LIMITES["resumen"])
    contexto: _texto(*LIMITES["contexto"])
    perspectivas: list[PerspectivaNueva] = Field(
        min_length=MIN_PERSPECTIVAS, max_length=MAX_PERSPECTIVAS
    )
    objetivo: _texto(*LIMITES["objetivo"])

    @field_validator("perspectivas")
    @classmethod
    def _titulos_distintos(cls, valor: list[PerspectivaNueva]) -> list[PerspectivaNueva]:
        if len({p.titulo.casefold() for p in valor}) != len(valor):
            raise ValueError("Las perspectivas deben tener títulos distintos.")
        return valor


def _parcial(maximo: int):
    return Annotated[str, StringConstraints(strip_whitespace=True, max_length=maximo)]


class PerspectivaBorrador(BaseModel):
    model_config = ConfigDict(extra="forbid")

    titulo: _parcial(LIMITES["perspectiva_titulo"][1]) = ""
    descripcion: _parcial(LIMITES["perspectiva_descripcion"][1]) = ""


class BorradorCambios(BaseModel):
    """Cambios de un borrador: todo es opcional e incompleto; solo se limitan las longitudes.

    `null` vacía un campo. Autor, estado, ids y debate publicado no se aceptan (422).
    """

    model_config = ConfigDict(extra="forbid")

    categoria: Categoria | None = None
    ambito: _parcial(LIMITES["ambito"][1]) | None = None
    titulo: _parcial(LIMITES["titulo"][1]) | None = None
    resumen: _parcial(LIMITES["resumen"][1]) | None = None
    contexto: _parcial(LIMITES["contexto"][1]) | None = None
    perspectivas: list[PerspectivaBorrador] | None = Field(
        default=None, max_length=MAX_PERSPECTIVAS
    )
    objetivo: _parcial(LIMITES["objetivo"][1]) | None = None
    paso: int | None = Field(default=None, ge=1, le=6)


class BorradorSalida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    categoria: Categoria | None
    ambito: str | None
    titulo: str | None
    resumen: str | None
    contexto: str | None
    perspectivas: list[PerspectivaBorrador] | None
    objetivo: str | None
    paso: int
    creado_en: datetime
    actualizado_en: datetime
    debate_id: int | None
    # 7C: referencias seleccionadas, procedencia de sugerencias aceptadas y redacción pendiente.
    referencias: list["ReferenciaSalida"] = []
    evidencias: list["EvidenciaSalida"] = []
    redaccion: "RedaccionSalida | None" = Field(default=None, validation_alias="redaccion_vigente")

    @field_validator("referencias", "evidencias", mode="before")
    @classmethod
    def _sin_datos_es_vacio(cls, valor: object) -> object:
        return valor or []


class MiDebate(BaseModel):
    id: int
    titulo: str
    categoria: Categoria
    estado: EstadoDebate
    aportes: int
    publicado_en: datetime | None
    archivado_en: datetime | None
    archivo_origen: OrigenArchivo | None = None
    editable: bool
    solicitud_archivo: "SolicitudPropia | None" = None


class MisDebates(BaseModel):
    """Debates de la cuenta del token, separados por estado. Solo los propios."""

    borradores: list[BorradorSalida]
    publicados: list[MiDebate]
    archivados: list[MiDebate]


class MisDebatesTotales(BaseModel):
    borradores: int
    publicados: int
    archivados: int


# --- Solicitudes de archivo y administración --------------------------------------------------

LIMITES_MOTIVO = (10, 500)
Motivo = _texto(*LIMITES_MOTIVO)


class SolicitudEntrada(BaseModel):
    """Solicitud de archivo del autor. Estado, solicitante y revisor los fija el servidor."""

    model_config = ConfigDict(extra="forbid")

    motivo: Motivo


class ResolucionEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    justificacion: Motivo


class ArchivoDirectoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    motivo: Motivo


class SolicitudPropia(BaseModel):
    """Lo que ve quien solicitó: estado y respuesta de la administración, sin datos del revisor."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    debate_id: int
    motivo: str
    estado: EstadoSolicitud
    creada_en: datetime
    resuelta_en: datetime | None
    respuesta: str | None = Field(
        default=None, validation_alias="justificacion", description="Justificación de la resolución."
    )


class SolicitudPropiaConDebate(SolicitudPropia):
    debate_titulo: str


class SolicitudAdmin(BaseModel):
    """Registro completo de una solicitud, solo para la administración. Sin correos."""

    id: int
    estado: EstadoSolicitud
    motivo: str
    creada_en: datetime
    resuelta_en: datetime | None
    justificacion: str | None
    solicitante_nombre: str
    revisor_nombre: str | None
    debate: DebateBreve
    debate_estado: EstadoDebate
    debate_resumen: str
    debate_aportes: int


# --- Bloque 7B.1: historial de versiones y aclaraciones ---------------------------------------

LIMITES_ACLARACION = (10, 1000)


class EdicionDebate(ContenidoDebate):
    """Contenido completo nuevo y motivo obligatorio del cambio (queda en el historial)."""

    motivo: Motivo


class AclaracionEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    texto: _texto(*LIMITES_ACLARACION)


class AclaracionSalida(BaseModel):
    id: int
    texto: str
    autor_nombre: str
    creada_en: datetime


class VersionResumen(BaseModel):
    numero: int
    tipo: TipoVersion
    creada_en: datetime
    # Quién hizo el cambio y por qué; None cuando no se conservó (registro inicial, catálogo).
    autor_nombre: str | None
    motivo: str | None
    campos_cambiados: list[str]
    es_actual: bool


class CambioCampo(BaseModel):
    campo: str
    antes: object
    despues: object


class VersionDetalle(VersionResumen):
    categoria: Categoria
    ambito: str | None
    titulo: str
    resumen: str
    contexto: str
    perspectivas: list[Perspectiva]
    objetivo: str | None
    cambios: list[CambioCampo] = Field(description="Diferencias con la versión anterior.")
    referencias: list["ReferenciaSalida"] = []
    evidencias: list["EvidenciaSalida"] = []

    @field_validator("referencias", "evidencias", mode="before")
    @classmethod
    def _sin_datos_es_vacio(cls, valor: object) -> object:
        return valor or []


# --- Bloque 7C: referencias bibliográficas y redacción asistida ------------------------------


class LicenciaSalida(BaseModel):
    url: str
    aplica_a: str | None = None
    inicio: str | None = None


class RelacionSalida(BaseModel):
    relacion: str
    doi: str


class ReferenciaSalida(BaseModel):
    """Metadatos bibliográficos obtenidos por el servidor en Crossref. Una referencia localizada
    no certifica la calidad de la obra ni respalda por sí sola ninguna afirmación."""

    doi: str
    titulo: str
    autores: list[str] = []
    fecha_publicacion: str | None = None
    tipo: str
    tipo_crossref: str | None = None
    publicacion: str | None = None
    editorial: str | None = None
    licencias: list[LicenciaSalida] = []
    relacionadas: list[RelacionSalida] = []
    misma_obra_que: list[str] = []
    enlace: str
    procedencia: Literal["crossref"]
    consultada_en: str


class EvidenciaSalida(BaseModel):
    """Procedencia de un texto aceptado a partir de una sugerencia de IA."""

    id: str
    tipo: str
    campo: str
    procedencia: str
    texto_sugerido: str
    texto_aceptado: str
    editada: bool
    referencias: list[str] = []
    requiere_revision: bool = False
    aceptada_en: str
    presente_al_publicar: bool | None = None


class SugerenciaSalida(BaseModel):
    id: str
    tipo: Literal["contexto", "perspectiva", "pregunta", "afirmacion"]
    estado: Literal["pendiente", "aceptada"]
    texto: str | None = None
    titulo: str | None = None
    descripcion: str | None = None
    aviso: str
    referencias: list[str] = []


class RedaccionSalida(BaseModel):
    creada_en: str
    sugerencias: list[SugerenciaSalida]
    limitaciones: list[str]
    desactualizada: bool = Field(description="El borrador cambió después de pedir la redacción.")


class BusquedaSalida(BaseModel):
    estado: Literal["resultados", "sin_resultados"]
    consulta: str = Field(description="Texto exacto enviado a Crossref.")
    referencias: list[ReferenciaSalida]
    consultada_en: datetime


class ReferenciaEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    doi: str = Field(min_length=7, max_length=220)


class AceptacionEntrada(BaseModel):
    """Aceptar una sugerencia, opcionalmente editada. `valor_anterior` es el contenido del campo
    que la persona vio al confirmar: si cambió entretanto, no se sobrescribe (409)."""

    model_config = ConfigDict(extra="forbid")

    modo: Literal["anadir", "sustituir"] = "anadir"
    valor_anterior: str | None = None
    texto: _parcial(1500) | None = None
    titulo: _parcial(80) | None = None
    descripcion: _parcial(600) | None = None


class EstadoInvestigacion(BaseModel):
    busqueda_disponible: bool
    redaccion_disponible: bool
    max_referencias: int
    limites_por_hora: dict[str, int]


EstadisticasPersonales.model_rebuild()
DebateDetalle.model_rebuild()
BorradorSalida.model_rebuild()
VersionDetalle.model_rebuild()
MiDebate.model_rebuild()

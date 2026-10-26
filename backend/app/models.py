"""Tablas de la base de datos."""

from datetime import datetime, timezone
from enum import StrEnum

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

ORIGEN_EDITORIAL = "Material editorial de demostración"
ORIGEN_USUARIO = "Debate creado por una persona usuaria"


def ahora_utc() -> datetime:
    return datetime.now(timezone.utc)


class Categoria(StrEnum):
    """Categorías del catálogo. El orden de declaración es el orden de presentación."""

    educacion = "educacion"
    ambiente = "ambiente"
    movilidad = "movilidad"
    empleo = "empleo"
    salud = "salud"
    tecnologia = "tecnologia"
    cultura = "cultura"
    participacion = "participacion"


ETIQUETAS_CATEGORIA: dict[Categoria, str] = {
    Categoria.educacion: "Educación",
    Categoria.ambiente: "Ambiente",
    Categoria.movilidad: "Movilidad",
    Categoria.empleo: "Empleo",
    Categoria.salud: "Salud",
    Categoria.tecnologia: "Tecnología",
    Categoria.cultura: "Cultura",
    Categoria.participacion: "Participación",
}


class Procedencia(StrEnum):
    editorial = "editorial"  # catálogo de demostración (sin autor)
    usuario = "usuario"  # creado y publicado por una cuenta


class EstadoDebate(StrEnum):
    publicado = "publicado"  # visible en el catálogo y abierto a aportes
    archivado = "archivado"  # consultable, sin nuevos aportes ni cambios


class Rol(StrEnum):
    usuario = "usuario"  # cualquier cuenta registrada
    administrador = "administrador"  # solo por comando local (python -m app.admin)


class OrigenArchivo(StrEnum):
    """Cómo se archivó un debate. Es público: explica el archivo sin revelar la revisión."""

    anterior = "anterior"  # archivado por su autor antes de la revisión administrativa
    solicitud = "solicitud"  # solicitud de su autor aprobada por la administración
    administracion = "administracion"  # archivo directo de la administración


class EstadoSolicitud(StrEnum):
    pendiente = "pendiente"
    aprobada = "aprobada"
    rechazada = "rechazada"
    cancelada = "cancelada"


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(60))
    # Se guarda normalizado (sin espacios y en minúsculas); la unicidad la garantiza la base.
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)
    # Migración 0003. Nunca se toma de la petición ni del token: se lee de la base en cada uso.
    rol: Mapped[str] = mapped_column(
        String(20), default=Rol.usuario.value, server_default="usuario"
    )
    # Migración 0005 (7C). Momento en que la persona **declaró** tener 18 años o más. No es una
    # verificación de edad. Nulo: pendiente (las cuentas anteriores no se dan por confirmadas).
    mayoria_edad_declarada_en: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), default=None
    )


class Debate(Base):
    __tablename__ = "debates"

    id: Mapped[int] = mapped_column(primary_key=True)
    # Clave estable del archivo editorial: permite recargar sin duplicar.
    slug: Mapped[str] = mapped_column(String(80), unique=True)
    titulo: Mapped[str] = mapped_column(String(160))
    categoria: Mapped[str] = mapped_column(String(30), index=True)
    resumen: Mapped[str] = mapped_column(Text)
    contexto: Mapped[str] = mapped_column(Text)
    perspectivas: Mapped[list[dict[str, str]]] = mapped_column(JSON)
    origen: Mapped[str] = mapped_column(String(80))
    actualizado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=ahora_utc, onupdate=ahora_utc
    )
    # Bloque 7B (migración 0002). Los debates editoriales tienen procedencia "editorial" y
    # ningún autor; ninguna cuenta puede editarlos ni archivarlos.
    procedencia: Mapped[str] = mapped_column(
        String(20), default=Procedencia.editorial.value, server_default="editorial"
    )
    estado: Mapped[str] = mapped_column(
        String(20), default=EstadoDebate.publicado.value, server_default="publicado", index=True
    )
    autor_id: Mapped[int | None] = mapped_column(
        ForeignKey("usuarios.id"), default=None, index=True
    )
    ambito: Mapped[str | None] = mapped_column(Text, default=None)
    objetivo: Mapped[str | None] = mapped_column(Text, default=None)
    publicado_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    archivado_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    # Migración 0003. `archivo_origen` es público; quién archivó y el motivo son internos.
    archivo_origen: Mapped[str | None] = mapped_column(String(20), default=None)
    archivado_por_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), default=None)
    motivo_archivo: Mapped[str | None] = mapped_column(Text, default=None)
    # Migración 0004 (Bloque 7B.1). Número de la versión publicada vigente (versiones_debate).
    version_actual: Mapped[int | None] = mapped_column(Integer, default=None)
    # Se marca al aceptar el primer aporte y **nunca** se desmarca: aunque luego se eliminen
    # todos los aportes, el contenido ya no se puede reescribir.
    con_participacion: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("0")
    )
    # Bloqueo conservador de los debates publicados antes del historial: no se puede demostrar
    # que nunca tuvieron aportes (eliminados después), así que su contenido no se reescribe.
    bloqueo_historico: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("0")
    )
    # Migración 0005 (7C). Referencias bibliográficas y procedencia de sugerencias aceptadas,
    # copiadas del borrador al publicar. Nulas en los debates anteriores (sin fuentes).
    referencias: Mapped[list[dict] | None] = mapped_column(JSON, default=None)
    evidencias: Mapped[list[dict] | None] = mapped_column(JSON, default=None)


class TipoVersion(StrEnum):
    publicacion = "publicacion"  # primera versión de un debate de usuario
    edicion = "edicion"  # edición permitida por su autor, con motivo
    catalogo = "catalogo"  # alta o actualización del catálogo editorial (semilla)
    registro_inicial = "registro_inicial"  # instantánea tomada al incorporar el historial


# Campos de contenido que se conservan en cada versión.
CAMPOS_VERSION = (
    "categoria",
    "ambito",
    "titulo",
    "resumen",
    "contexto",
    "perspectivas",
    "objetivo",
)


class VersionDebate(Base):
    """Contenido publicado de un debate en un momento dado. Inmutable: solo se insertan filas.

    Los borradores nunca generan versiones: la primera se crea al publicar.
    """

    __tablename__ = "versiones_debate"
    __table_args__ = (UniqueConstraint("debate_id", "numero", name="uq_versiones_debate_numero"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    debate_id: Mapped[int] = mapped_column(ForeignKey("debates.id"), index=True)
    numero: Mapped[int] = mapped_column(Integer)
    tipo: Mapped[str] = mapped_column(String(20))
    categoria: Mapped[str] = mapped_column(String(30))
    ambito: Mapped[str | None] = mapped_column(Text, default=None)
    titulo: Mapped[str] = mapped_column(String(160))
    resumen: Mapped[str] = mapped_column(Text)
    contexto: Mapped[str] = mapped_column(Text)
    perspectivas: Mapped[list[dict[str, str]]] = mapped_column(JSON)
    objetivo: Mapped[str | None] = mapped_column(Text, default=None)
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)
    # Quién hizo el cambio y por qué. Nulos cuando no se conservó (registro inicial) o en el
    # catálogo editorial.
    autor_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), default=None)
    motivo: Mapped[str | None] = mapped_column(Text, default=None)
    # Migración 0005 (7C): fuentes y procedencia vigentes en esta versión (inmutables).
    referencias: Mapped[list[dict] | None] = mapped_column(JSON, default=None)
    evidencias: Mapped[list[dict] | None] = mapped_column(JSON, default=None)


class Aclaracion(Base):
    """Añadido fechado del autor a su debate. Inmutable: una rectificación es otra aclaración."""

    __tablename__ = "aclaraciones"

    id: Mapped[int] = mapped_column(primary_key=True)
    debate_id: Mapped[int] = mapped_column(ForeignKey("debates.id"), index=True)
    autor_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"))
    texto: Mapped[str] = mapped_column(Text)
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)


class SolicitudArchivo(Base):
    """Petición de archivo de un debate por su autor, revisada por la administración.

    Nunca se borra: cancelar o resolver cambia `estado`. Un índice único parcial impide más de
    una solicitud pendiente por debate.
    """

    __tablename__ = "solicitudes_archivo"
    __table_args__ = (
        Index(
            "ux_solicitudes_archivo_pendiente",
            "debate_id",
            unique=True,
            sqlite_where=text("estado = 'pendiente'"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    debate_id: Mapped[int] = mapped_column(ForeignKey("debates.id"), index=True)
    solicitante_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    motivo: Mapped[str] = mapped_column(Text)
    estado: Mapped[str] = mapped_column(
        String(20), default=EstadoSolicitud.pendiente.value, index=True
    )
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)
    revisor_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), default=None)
    justificacion: Mapped[str | None] = mapped_column(Text, default=None)
    resuelta_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class Borrador(Base):
    """Borrador privado de un debate. Todos sus campos de contenido pueden estar incompletos.

    Al publicarse se enlaza con el debate creado (`debate_id`) y deja de ser editable; publicar
    otra vez devuelve ese mismo debate.
    """

    __tablename__ = "borradores"

    id: Mapped[int] = mapped_column(primary_key=True)
    autor_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    categoria: Mapped[str | None] = mapped_column(String(30), default=None)
    ambito: Mapped[str | None] = mapped_column(Text, default=None)
    titulo: Mapped[str | None] = mapped_column(Text, default=None)
    resumen: Mapped[str | None] = mapped_column(Text, default=None)
    contexto: Mapped[str | None] = mapped_column(Text, default=None)
    perspectivas: Mapped[list[dict[str, str]] | None] = mapped_column(JSON, default=None)
    objetivo: Mapped[str | None] = mapped_column(Text, default=None)
    paso: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)
    actualizado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=ahora_utc, onupdate=ahora_utc
    )
    debate_id: Mapped[int | None] = mapped_column(
        ForeignKey("debates.id"), default=None, unique=True
    )
    # Migración 0005 (7C). Referencias seleccionadas (metadatos obtenidos por el servidor),
    # procedencia de sugerencias aceptadas y la última redacción con IA pendiente de revisar.
    referencias: Mapped[list[dict] | None] = mapped_column(JSON, default=None)
    evidencias: Mapped[list[dict] | None] = mapped_column(JSON, default=None)
    redaccion: Mapped[dict | None] = mapped_column(JSON, default=None)

    @property
    def redaccion_vigente(self) -> dict | None:
        from app.repositorios.investigacion import redaccion_vigente

        return redaccion_vigente(self)


class TipoAporte(StrEnum):
    pregunta = "pregunta"
    argumento = "argumento"
    propuesta = "propuesta"


class Aporte(Base):
    __tablename__ = "aportes"
    __table_args__ = (Index("ix_aportes_debate_orden", "debate_id", "creado_en", "id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    debate_id: Mapped[int] = mapped_column(ForeignKey("debates.id"))
    # El autor sale siempre del token; nunca del cuerpo de la petición.
    autor_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    tipo: Mapped[str] = mapped_column(String(20))
    texto: Mapped[str] = mapped_column(Text)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)
    editado_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    # Versión del debate que se veía al publicar (migración 0004). Nula en los aportes anteriores
    # al historial: su versión original es desconocida. Editar el texto no la cambia.
    version_id: Mapped[int | None] = mapped_column(
        ForeignKey("versiones_debate.id"), default=None
    )

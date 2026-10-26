"""Tablas de la base de datos."""

from datetime import datetime, timezone
from enum import StrEnum

from sqlalchemy import JSON, DateTime, ForeignKey, Index, Integer, String, Text, text
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

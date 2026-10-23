"""Tablas de la base de datos."""

from datetime import datetime, timezone
from enum import StrEnum

from sqlalchemy import JSON, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base

ORIGEN_EDITORIAL = "Material editorial de demostración"


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


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(60))
    # Se guarda normalizado (sin espacios y en minúsculas); la unicidad la garantiza la base.
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=ahora_utc)


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

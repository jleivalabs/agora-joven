"""Carga reproducible del catálogo editorial desde app/datos/debates.json.

Idempotente: cada debate se identifica por su `slug`. Si no existe, se inserta con su versión 1
(tipo `catalogo`). Si existe y su contenido cambió en el archivo, solo se actualiza cuando no está
protegido (sin participación, sin bloqueo histórico y publicado), y cada actualización crea la
versión siguiente. Nunca borra debates ni toca usuarios, y nunca modifica debates creados por
usuarios (procedencia "usuario"), aunque coincidiera un slug.

Uso manual: python -m app.catalogo
"""

import json
from dataclasses import dataclass
from pathlib import Path

from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import (
    CAMPOS_VERSION,
    ORIGEN_EDITORIAL,
    Categoria,
    Debate,
    EstadoDebate,
    Procedencia,
    TipoVersion,
)
from app.repositorios import versiones as repo_versiones
from app.schemas import Perspectiva

ARCHIVO_CATALOGO = Path(__file__).parent / "datos" / "debates.json"


class DebateEditorial(BaseModel):
    slug: str = Field(pattern=r"^[a-z0-9-]{3,80}$")
    categoria: Categoria
    titulo: str = Field(min_length=10, max_length=160)
    resumen: str = Field(min_length=30)
    contexto: str = Field(min_length=80)
    perspectivas: list[Perspectiva] = Field(min_length=2)
    origen: str

    @field_validator("origen")
    @classmethod
    def _es_demostracion(cls, valor: str) -> str:
        if valor != ORIGEN_EDITORIAL:
            raise ValueError(f"origen debe ser '{ORIGEN_EDITORIAL}'")
        return valor

    @field_validator("perspectivas")
    @classmethod
    def _perspectivas_distintas(cls, valor: list[Perspectiva]) -> list[Perspectiva]:
        if len({p.titulo.casefold() for p in valor}) != len(valor):
            raise ValueError("las perspectivas deben tener títulos distintos")
        return valor


@dataclass
class ResultadoCarga:
    insertados: int
    actualizados: int
    protegidos: int = 0  # con cambios en el archivo, pero con contenido protegido: no se tocan


def leer_catalogo(archivo: Path = ARCHIVO_CATALOGO) -> list[DebateEditorial]:
    datos = json.loads(archivo.read_text(encoding="utf-8"))
    debates = [DebateEditorial.model_validate(d) for d in datos]
    slugs = [d.slug for d in debates]
    if len(set(slugs)) != len(slugs):
        raise ValueError("Hay slugs repetidos en el catálogo.")
    return debates


def cargar_catalogo(db: Session, archivo: Path = ARCHIVO_CATALOGO) -> ResultadoCarga:
    existentes = {d.slug: d for d in db.scalars(select(Debate))}
    resultado = ResultadoCarga(insertados=0, actualizados=0)
    for editorial in leer_catalogo(archivo):
        campos = editorial.model_dump(mode="json", exclude={"slug"})
        debate = existentes.get(editorial.slug)
        if debate is not None and debate.procedencia != Procedencia.editorial.value:
            continue  # nunca se sobrescribe un debate de usuario
        if debate is None:
            debate = Debate(slug=editorial.slug, version_actual=1, **campos)
            db.add(debate)
            db.flush()
            repo_versiones.nueva_version(db, debate, 1, TipoVersion.catalogo)
            resultado.insertados += 1
            continue
        cambios = {k: v for k, v in campos.items() if getattr(debate, k) != v}
        if not cambios:
            continue
        if (
            debate.con_participacion
            or debate.bloqueo_historico
            or debate.estado != EstadoDebate.publicado.value
        ):
            # Contenido protegido (participación, historial anterior o archivado): la semilla no
            # lo reescribe; un cambio de tema se publica como otro debate.
            resultado.protegidos += 1
            continue
        for campo, valor in cambios.items():
            setattr(debate, campo, valor)
        if set(cambios) & set(CAMPOS_VERSION):
            debate.version_actual = (debate.version_actual or 0) + 1
            db.flush()
            repo_versiones.nueva_version(db, debate, debate.version_actual, TipoVersion.catalogo)
        resultado.actualizados += 1
    db.commit()
    return resultado


def main() -> None:
    from app.config import Settings
    from app.db import crear_fabrica_sesiones, crear_motor
    from app.migrar import aplicar_migraciones

    motor = crear_motor(Settings().database_url)
    aplicar_migraciones(motor)
    with crear_fabrica_sesiones(motor)() as db:
        r = cargar_catalogo(db)
        total = len(list(db.scalars(select(Debate.id))))
    motor.dispose()
    print(
        f"Catálogo: {r.insertados} insertados, {r.actualizados} actualizados, "
        f"{r.protegidos} protegidos sin cambios, {total} en total."
    )


if __name__ == "__main__":
    main()

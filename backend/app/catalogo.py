"""Carga reproducible del catálogo editorial desde app/datos/debates.json.

Idempotente: cada debate se identifica por su `slug`. Si existe, se actualizan sus campos
editoriales; si no, se inserta. Nunca borra debates ni toca usuarios.

Uso manual: python -m app.catalogo
"""

import json
from dataclasses import dataclass
from pathlib import Path

from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ORIGEN_EDITORIAL, Categoria, Debate
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
        if debate is None:
            db.add(Debate(slug=editorial.slug, **campos))
            resultado.insertados += 1
        else:
            cambios = {k: v for k, v in campos.items() if getattr(debate, k) != v}
            for campo, valor in cambios.items():
                setattr(debate, campo, valor)
            if cambios:
                resultado.actualizados += 1
    db.commit()
    return resultado


def main() -> None:
    from app.config import Settings
    from app.db import Base, crear_fabrica_sesiones, crear_motor

    motor = crear_motor(Settings().database_url)
    Base.metadata.create_all(motor)
    with crear_fabrica_sesiones(motor)() as db:
        r = cargar_catalogo(db)
        total = len(list(db.scalars(select(Debate.id))))
    motor.dispose()
    print(f"Catálogo: {r.insertados} insertados, {r.actualizados} actualizados, {total} en total.")


if __name__ == "__main__":
    main()

"""Rutas del catálogo de debates. Todas requieren sesión."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import ETIQUETAS_CATEGORIA, Categoria
from app.repositorios import debates as repo_debates
from app.schemas import CategoriaSalida, DebateDetalle, DebateResumen
from app.security import usuario_actual

router = APIRouter(
    prefix="/debates", tags=["debates"], dependencies=[Depends(usuario_actual)]
)

Db = Annotated[Session, Depends(get_db)]


@router.get("/categorias", response_model=list[CategoriaSalida])
def categorias(db: Db) -> list[CategoriaSalida]:
    """Todas las categorías, en orden fijo, con su número de debates (puede ser 0)."""
    totales = repo_debates.contar_por_categoria(db)
    return [
        CategoriaSalida(categoria=c, etiqueta=ETIQUETAS_CATEGORIA[c], total=totales.get(c, 0))
        for c in Categoria
    ]


@router.get("", response_model=list[DebateResumen])
def listar(db: Db, categoria: Categoria | None = None) -> list[DebateResumen]:
    return [DebateResumen.model_validate(d) for d in repo_debates.listar(db, categoria)]


@router.get("/{debate_id}", response_model=DebateDetalle)
def detalle(debate_id: int, db: Db) -> DebateDetalle:
    debate = repo_debates.obtener(db, debate_id)
    if debate is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Debate no encontrado."
        )
    return DebateDetalle.model_validate(debate)

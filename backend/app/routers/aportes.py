"""Rutas de aportes. Todas requieren sesión; editar y borrar, además, ser el autor."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Aporte, Usuario
from app.repositorios import aportes as repo_aportes
from app.repositorios import debates as repo_debates
from app.schemas import AporteCambios, AporteEntrada, AporteSalida
from app.security import UsuarioActual

router = APIRouter(tags=["aportes"])

Db = Annotated[Session, Depends(get_db)]


def _salida(aporte: Aporte, autor_nombre: str, usuario: Usuario) -> AporteSalida:
    return AporteSalida(
        id=aporte.id,
        debate_id=aporte.debate_id,
        tipo=aporte.tipo,
        texto=aporte.texto,
        autor_nombre=autor_nombre,
        creado_en=aporte.creado_en,
        editado_en=aporte.editado_en,
        es_propio=aporte.autor_id == usuario.id,
    )


def _exigir_debate(db: Session, debate_id: int) -> None:
    if repo_debates.obtener(db, debate_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")


def _aporte_propio(db: Session, aporte_id: int, usuario: Usuario) -> Aporte:
    aporte = repo_aportes.obtener(db, aporte_id)
    if aporte is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Aporte no encontrado.")
    if aporte.autor_id != usuario.id:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, detail="Solo el autor puede modificar este aporte."
        )
    return aporte


@router.get("/debates/{debate_id}/aportes", response_model=list[AporteSalida])
def listar(debate_id: int, db: Db, usuario: UsuarioActual) -> list[AporteSalida]:
    _exigir_debate(db, debate_id)
    return [_salida(a, nombre, usuario) for a, nombre in repo_aportes.listar(db, debate_id)]


@router.post(
    "/debates/{debate_id}/aportes",
    response_model=AporteSalida,
    status_code=status.HTTP_201_CREATED,
)
def crear(
    debate_id: int, datos: AporteEntrada, db: Db, usuario: UsuarioActual
) -> AporteSalida:
    _exigir_debate(db, debate_id)
    aporte = repo_aportes.crear(db, debate_id, usuario.id, datos.tipo.value, datos.texto)
    return _salida(aporte, usuario.nombre, usuario)


@router.patch("/aportes/{aporte_id}", response_model=AporteSalida)
def editar(
    aporte_id: int, cambios: AporteCambios, db: Db, usuario: UsuarioActual
) -> AporteSalida:
    aporte = _aporte_propio(db, aporte_id, usuario)
    valores = cambios.model_dump(mode="json", exclude_unset=True)
    repo_aportes.actualizar(db, aporte, valores)
    return _salida(aporte, usuario.nombre, usuario)


@router.delete("/aportes/{aporte_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(aporte_id: int, db: Db, usuario: UsuarioActual) -> Response:
    repo_aportes.eliminar(db, _aporte_propio(db, aporte_id, usuario))
    return Response(status_code=status.HTTP_204_NO_CONTENT)

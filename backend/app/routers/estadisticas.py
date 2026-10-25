"""Estadísticas del dashboard. Requieren sesión.

`/estadisticas/comunidad` solo devuelve cifras agregadas y títulos de debates (sin identidades).
`/estadisticas/mias` usa exclusivamente el usuario del token: no admite otro identificador.
"""

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import ETIQUETAS_CATEGORIA, Categoria, TipoAporte
from app.repositorios import estadisticas as repo
from app.schemas import (
    AportesPorTipo,
    CategoriaSalida,
    DebateBreve,
    DebateConActividad,
    DebatesSinAportes,
    EstadisticasComunidad,
    EstadisticasPersonales,
    MiAporteReciente,
)
from app.security import UsuarioActual, usuario_actual

router = APIRouter(
    prefix="/estadisticas", tags=["estadísticas"], dependencies=[Depends(usuario_actual)]
)

Db = Annotated[Session, Depends(get_db)]


@router.get("/comunidad", response_model=EstadisticasComunidad)
def comunidad(db: Db) -> EstadisticasComunidad:
    por_categoria = repo.debates_por_categoria(db)
    total_sin, sin_aportes = repo.debates_sin_aportes(db)
    return EstadisticasComunidad(
        total_debates=repo.total_debates(db),
        por_categoria=[
            CategoriaSalida(
                categoria=c, etiqueta=ETIQUETAS_CATEGORIA[c], total=por_categoria.get(c, 0)
            )
            for c in Categoria
        ],
        total_aportes=repo.total_aportes(db),
        participantes=repo.participantes(db),
        sin_aportes=DebatesSinAportes(
            total=total_sin, debates=[DebateBreve.model_validate(d) for d in sin_aportes]
        ),
        actividad_reciente=[
            DebateConActividad(
                debate=DebateBreve.model_validate(debate), aportes=aportes, ultimo_aporte_en=ultimo
            )
            for debate, aportes, ultimo in repo.debates_con_actividad_reciente(db)
        ],
    )


@router.get("/mias", response_model=EstadisticasPersonales)
def mias(db: Db, usuario: UsuarioActual) -> EstadisticasPersonales:
    por_tipo = repo.mis_aportes_por_tipo(db, usuario.id)
    return EstadisticasPersonales(
        total_aportes=sum(por_tipo.values()),
        por_tipo=AportesPorTipo(**{t.value: por_tipo.get(t.value, 0) for t in TipoAporte}),
        debates_participados=repo.mis_debates_participados(db, usuario.id),
        aportes_recientes=[
            MiAporteReciente(
                id=aporte.id,
                tipo=aporte.tipo,
                texto=aporte.texto,
                creado_en=aporte.creado_en,
                editado_en=aporte.editado_en,
                debate=DebateBreve.model_validate(debate),
            )
            for aporte, debate in repo.mis_aportes_recientes(db, usuario.id)
        ],
    )

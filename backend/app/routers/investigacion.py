"""Investigación asistida de un borrador propio (Bloque 7C).

- Referencias: búsqueda y consulta por DOI en Crossref (metadatos). Un borrador ajeno responde 404.
- Redacción: Gemini sin búsqueda de Google, desactivada por defecto.
- Nada se aplica al borrador sin una acción explícita de aceptar; no se publica nada.

Errores diferenciados (`detail.codigo`): `busqueda_no_configurada` y `redaccion_desactivada`
(503), `limite_cuenta` (429), `en_curso` (409), `proveedor_ocupado` (503), `cuota_proveedor`
(429), `proveedor_no_disponible` (503), `respuesta_no_valida` (502), `doi_no_encontrado` (404),
`limite_referencias`, `campo_cambiado`, `sin_espacio`, `ya_publicado` (409).
"""

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.crossref import ErrorFuente, FalloFuente, agrupar, doi_valido, normalizar_obra
from app.db import get_db
from app.ia import ErrorProveedor, FalloProveedor
from app.investigacion import ESQUEMA, INSTRUCCIONES, construir_contenido, interpretar
from app.limites import POR_HORA, Accion, EnCurso, LimiteSuperado, ProveedorOcupado
from app.models import Borrador, Usuario
from app.repositorios import borradores as repo_borradores
from app.repositorios import investigacion as repo
from app.schemas import (
    AceptacionEntrada,
    BorradorSalida,
    BusquedaSalida,
    EstadoInvestigacion,
    ReferenciaEntrada,
)
from app.security import UsuarioActual, usuario_actual

router = APIRouter(tags=["investigación"], dependencies=[Depends(usuario_actual)])

Db = Annotated[Session, Depends(get_db)]


def _error(codigo: int, clave: str, mensaje: str) -> HTTPException:
    return HTTPException(codigo, detail={"codigo": clave, "mensaje": mensaje})


def _propio(db: Session, borrador_id: int, usuario: Usuario) -> Borrador:
    borrador = repo_borradores.obtener_propio(db, borrador_id, usuario.id)
    if borrador is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Borrador no encontrado.")
    if borrador.debate_id is not None:
        raise _error(409, "ya_publicado", "Este borrador ya se publicó.")
    return borrador


def _fallo_fuente(e: ErrorFuente) -> HTTPException:
    return {
        FalloFuente.CUOTA: _error(429, "cuota_proveedor", "Crossref limitó las consultas."),
        FalloFuente.NO_DISPONIBLE: _error(
            503, "proveedor_no_disponible", "No se pudo contactar con Crossref."
        ),
        FalloFuente.MAL_FORMADA: _error(
            502, "respuesta_no_valida", "Crossref devolvió una respuesta no válida."
        ),
    }.get(e.fallo, _error(503, "busqueda_no_configurada", "Búsqueda no configurada."))


def _ejecutar(request: Request, usuario: Usuario, accion: Accion, operacion):
    """Aplica límites de uso y concurrencia y traduce los fallos del proveedor."""
    try:
        with request.app.state.limitador.accion(
            usuario.id, accion, espera_crossref=request.app.state.settings.crossref_timeout_segundos
        ):
            return operacion()
    except LimiteSuperado:
        raise _error(
            429, "limite_cuenta", f"Alcanzaste el máximo de {POR_HORA[accion]} por hora."
        ) from None
    except EnCurso:
        raise _error(409, "en_curso", "Ya hay una consulta en curso para tu cuenta.") from None
    except ProveedorOcupado:
        raise _error(503, "proveedor_ocupado", "Crossref está ocupado; inténtalo de nuevo.") from None
    except ErrorFuente as e:
        raise _fallo_fuente(e) from None
    except ErrorProveedor as e:
        if e.fallo == FalloProveedor.CUOTA:
            raise _error(429, "cuota_proveedor", "El proveedor de IA limitó las consultas.") from None
        if e.fallo == FalloProveedor.SIN_RESPUESTA:
            raise _error(502, "respuesta_no_valida", "La IA no devolvió una respuesta válida.") from None
        raise _error(503, "proveedor_no_disponible", "No se pudo contactar con la IA.") from None


@router.get("/investigacion/estado", response_model=EstadoInvestigacion)
def estado(request: Request) -> EstadoInvestigacion:
    return EstadoInvestigacion(
        busqueda_disponible=request.app.state.fuente is not None,
        redaccion_disponible=request.app.state.redactor is not None,
        max_referencias=repo.MAX_REFERENCIAS_BORRADOR,
        limites_por_hora={a.value: n for a, n in POR_HORA.items()},
    )


@router.post("/borradores/{borrador_id}/referencias/buscar", response_model=BusquedaSalida)
def buscar(borrador_id: int, request: Request, db: Db, usuario: UsuarioActual) -> BusquedaSalida:
    """Busca en Crossref con la pregunta y el ámbito del borrador. No guarda los resultados."""
    borrador = _propio(db, borrador_id, usuario)
    fuente = request.app.state.fuente
    if fuente is None:
        raise _error(503, "busqueda_no_configurada", "La búsqueda de referencias no está configurada.")
    pregunta = (borrador.titulo or "").strip()
    if len(pregunta) < 10:
        raise _error(422, "falta_pregunta", "Escribe primero la pregunta del debate.")
    consulta = " ".join(p for p in (pregunta, (borrador.ambito or "").strip()) if p)[:300]
    consultada_en = datetime.now(timezone.utc)
    items = _ejecutar(request, usuario, Accion.busqueda, lambda: fuente.buscar(consulta))
    referencias = agrupar(
        [r for r in (normalizar_obra(i, consultada_en) for i in items) if r is not None]
    )[:10]
    return BusquedaSalida(
        estado="resultados" if referencias else "sin_resultados",
        consulta=consulta,
        referencias=referencias,
        consultada_en=consultada_en,
    )


@router.post("/borradores/{borrador_id}/referencias", response_model=BorradorSalida)
def agregar(
    borrador_id: int, datos: ReferenciaEntrada, request: Request, db: Db, usuario: UsuarioActual
) -> Borrador:
    """Selecciona una obra por DOI. El servidor vuelve a pedirla a Crossref: nunca guarda
    metadatos enviados por la app."""
    borrador = _propio(db, borrador_id, usuario)
    doi = doi_valido(datos.doi)
    if doi is None:
        raise _error(422, "doi_no_valido", "El DOI no tiene un formato válido.")
    if any(r["doi"] == doi for r in borrador.referencias or []):
        return borrador
    if len(borrador.referencias or []) >= repo.MAX_REFERENCIAS_BORRADOR:
        raise _error(
            409, "limite_referencias",
            f"Máximo {repo.MAX_REFERENCIAS_BORRADOR} referencias por borrador.",
        )
    fuente = request.app.state.fuente
    if fuente is None:
        raise _error(503, "busqueda_no_configurada", "La búsqueda de referencias no está configurada.")
    item = _ejecutar(request, usuario, Accion.consulta_doi, lambda: fuente.obra(doi))
    referencia = normalizar_obra(item) if item is not None else None
    if referencia is None or referencia["doi"] != doi:
        raise _error(404, "doi_no_encontrado", "Crossref no tiene una obra válida con ese DOI.")
    try:
        return repo.agregar_referencia(db, borrador, referencia)
    except repo.LimiteReferencias:
        raise _error(
            409, "limite_referencias",
            f"Máximo {repo.MAX_REFERENCIAS_BORRADOR} referencias por borrador.",
        ) from None


@router.delete("/borradores/{borrador_id}/referencias/{doi:path}", response_model=BorradorSalida)
def quitar(borrador_id: int, doi: str, db: Db, usuario: UsuarioActual) -> Borrador:
    borrador = _propio(db, borrador_id, usuario)
    normalizado = doi_valido(doi)
    if normalizado is None:
        raise _error(422, "doi_no_valido", "El DOI no tiene un formato válido.")
    return repo.quitar_referencia(db, borrador, normalizado)


@router.post("/borradores/{borrador_id}/redaccion", response_model=BorradorSalida)
def redactar(borrador_id: int, request: Request, db: Db, usuario: UsuarioActual) -> Borrador:
    """Sugerencias de IA (sin búsqueda) sobre el borrador. Sustituye las pendientes anteriores."""
    borrador = _propio(db, borrador_id, usuario)
    redactor = request.app.state.redactor
    if redactor is None:
        raise _error(503, "redaccion_desactivada", "La redacción con IA está desactivada.")
    if len((borrador.titulo or "").strip()) < 10:
        raise _error(422, "falta_pregunta", "Escribe primero la pregunta del debate.")
    contenido = construir_contenido(borrador, borrador.referencias or [])
    respuesta = _ejecutar(
        request, usuario, Accion.redaccion,
        lambda: redactor.redactar(INSTRUCCIONES, contenido, ESQUEMA),
    )
    try:
        # Sin política de licencias no se envía contenido de ninguna referencia.
        sugerencias, limitaciones = interpretar(respuesta.texto, ids_con_contenido=set())
    except ErrorProveedor:
        raise _error(502, "respuesta_no_valida", "La IA no devolvió una respuesta válida.") from None
    if respuesta.truncado:
        limitaciones.append("La respuesta se cortó por el límite de longitud.")
    return repo.guardar_redaccion(db, borrador, sugerencias, limitaciones)


@router.post(
    "/borradores/{borrador_id}/sugerencias/{sugerencia_id}/aceptar",
    response_model=BorradorSalida,
)
def aceptar(
    borrador_id: int,
    sugerencia_id: str,
    datos: AceptacionEntrada,
    db: Db,
    usuario: UsuarioActual,
) -> Borrador:
    borrador = _propio(db, borrador_id, usuario)
    try:
        return repo.aceptar(
            db, borrador, sugerencia_id,
            modo=datos.modo, valor_anterior=datos.valor_anterior,
            texto=datos.texto, titulo=datos.titulo, descripcion=datos.descripcion,
        )
    except repo.SugerenciaNoEncontrada:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Sugerencia no encontrada.") from None
    except repo.CampoCambiado:
        raise _error(409, "campo_cambiado", "El campo cambió: revisa el cambio de nuevo.") from None
    except repo.SinEspacio:
        raise _error(409, "sin_espacio", "No cabe: supera el límite del campo.") from None


@router.post(
    "/borradores/{borrador_id}/sugerencias/{sugerencia_id}/descartar",
    response_model=BorradorSalida,
)
def descartar(borrador_id: int, sugerencia_id: str, db: Db, usuario: UsuarioActual) -> Borrador:
    borrador = _propio(db, borrador_id, usuario)
    try:
        return repo.descartar(db, borrador, sugerencia_id)
    except repo.SugerenciaNoEncontrada:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Sugerencia no encontrada.") from None

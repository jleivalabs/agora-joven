"""Rutas del catálogo de debates. Todas requieren sesión.

El catálogo y las categorías muestran solo debates publicados activos. El detalle también sirve
debates archivados (siguen siendo consultables, por ejemplo desde Guardados). Editar solo lo
puede hacer la cuenta autora de un debate de usuario; los editoriales no tienen autor. Archivar
lo hace únicamente la administración: directamente (aquí, con motivo) o aprobando una solicitud
del autor (`routers/solicitudes.py`).
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import ETIQUETAS_CATEGORIA, Categoria, Debate, EstadoDebate, Usuario
from app.repositorios import debates as repo_debates
from app.repositorios import solicitudes as repo_solicitudes
from app.repositorios import versiones as repo_versiones
from app.schemas import (
    AclaracionEntrada,
    AclaracionSalida,
    ArchivoDirectoEntrada,
    CambioCampo,
    CategoriaSalida,
    DebateDetalle,
    DebateResumen,
    EdicionDebate,
    SolicitudPropia,
    VersionDetalle,
    VersionResumen,
)
from app.security import AdministradorActual, UsuarioActual, usuario_actual

router = APIRouter(
    prefix="/debates", tags=["debates"], dependencies=[Depends(usuario_actual)]
)

Db = Annotated[Session, Depends(get_db)]


def resumen(debate: Debate, autor_nombre: str | None) -> DebateResumen:
    return DebateResumen.model_validate(debate).model_copy(update={"autor_nombre": autor_nombre})


def _detalle_salida(db: Session, debate_id: int, usuario: Usuario) -> DebateDetalle:
    fila = repo_debates.detalle(db, debate_id)
    if fila is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")
    debate, autor_nombre, aportes = fila
    propio = debate.autor_id is not None and debate.autor_id == usuario.id
    solicitud = (
        repo_solicitudes.ultimas_por_debate(db, usuario.id).get(debate.id) if propio else None
    )
    return DebateDetalle.model_validate(debate).model_copy(
        update={
            "autor_nombre": autor_nombre,
            "aportes": aportes,
            "es_propio": propio,
            "editable": propio and repo_debates.es_editable(debate, aportes),
            "solicitud_archivo": (
                None if solicitud is None else SolicitudPropia.model_validate(solicitud)
            ),
            "motivo_bloqueo": (
                "participacion" if debate.con_participacion or aportes
                else "historico" if debate.bloqueo_historico
                else None
            ),
            "aclaraciones": [
                AclaracionSalida(
                    id=a.id, texto=a.texto, autor_nombre=nombre, creada_en=a.creada_en
                )
                for a, nombre in repo_versiones.aclaraciones(db, debate.id)
            ],
        }
    )


@router.get("/categorias", response_model=list[CategoriaSalida])
def categorias(db: Db) -> list[CategoriaSalida]:
    """Todas las categorías, en orden fijo, con su número de debates publicados activos."""
    totales = repo_debates.contar_por_categoria(db)
    return [
        CategoriaSalida(categoria=c, etiqueta=ETIQUETAS_CATEGORIA[c], total=totales.get(c, 0))
        for c in Categoria
    ]


@router.get("", response_model=list[DebateResumen])
def listar(db: Db, categoria: Categoria | None = None) -> list[DebateResumen]:
    return [resumen(d, autor) for d, autor in repo_debates.listar(db, categoria)]


@router.get("/{debate_id}", response_model=DebateDetalle)
def detalle(debate_id: int, db: Db, usuario: UsuarioActual) -> DebateDetalle:
    return _detalle_salida(db, debate_id, usuario)


def _motivo_rechazo(db: Session, debate_id: int, usuario: Usuario) -> HTTPException:
    """Explica por qué una edición condicional no se aplicó."""
    fila = repo_debates.detalle(db, debate_id)
    if fila is None:
        return HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")
    debate, _, aportes = fila
    if debate.autor_id is None or debate.autor_id != usuario.id:
        return HTTPException(
            status.HTTP_403_FORBIDDEN, detail="Solo quien creó este debate puede modificarlo."
        )
    if debate.estado == EstadoDebate.archivado.value:
        return HTTPException(status.HTTP_409_CONFLICT, detail="Este debate está archivado.")
    if aportes or debate.con_participacion:
        return HTTPException(
            status.HTTP_409_CONFLICT,
            detail="El debate ya recibió aportes: su contenido queda bloqueado de forma permanente.",
        )
    if debate.bloqueo_historico:
        return HTTPException(
            status.HTTP_409_CONFLICT,
            detail="Debate publicado antes del historial de versiones: su contenido está protegido.",
        )
    return HTTPException(status.HTTP_409_CONFLICT, detail="No se pudo modificar el debate.")


@router.put("/{debate_id}", response_model=DebateDetalle)
def editar(
    debate_id: int, edicion: EdicionDebate, db: Db, usuario: UsuarioActual
) -> DebateDetalle:
    """Sustituye el contenido de un debate propio que nunca recibió aportes y crea la versión
    siguiente con el motivo. Si el contenido es idéntico, responde igual sin crear versión.
    Nadie más puede reescribirlo, tampoco la administración."""
    valores = edicion.model_dump(mode="json", exclude={"motivo"})
    resultado = repo_debates.editar_si_permitido(
        db, debate_id, usuario.id, valores, edicion.motivo
    )
    if resultado == repo_debates.ResultadoEdicion.rechazado:
        raise _motivo_rechazo(db, debate_id, usuario)
    return _detalle_salida(db, debate_id, usuario)


# --- Historial de versiones y aclaraciones (7B.1) -------------------------------------------


def _exigir_debate(db: Session, debate_id: int) -> Debate:
    debate = repo_debates.obtener(db, debate_id)
    if debate is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.")
    return debate


def _resumen_version(version, autor_nombre, anterior, actual: int | None) -> dict:
    cambios = repo_versiones.cambios(anterior, version)
    return {
        "numero": version.numero,
        "tipo": version.tipo,
        "creada_en": version.creada_en,
        "autor_nombre": autor_nombre,
        "motivo": version.motivo,
        "campos_cambiados": [c["campo"] for c in cambios],
        "es_actual": version.numero == actual,
        "_cambios": cambios,
    }


@router.get("/{debate_id}/versiones", response_model=list[VersionResumen])
def versiones(debate_id: int, db: Db) -> list[VersionResumen]:
    """Versiones publicadas, de la más reciente a la primera. Nunca incluye borradores."""
    debate = _exigir_debate(db, debate_id)
    filas = repo_versiones.listar(db, debate_id)
    salida = []
    for i, (version, autor) in enumerate(filas):
        anterior = filas[i + 1][0] if i + 1 < len(filas) else None
        datos = _resumen_version(version, autor, anterior, debate.version_actual)
        datos.pop("_cambios")
        salida.append(VersionResumen(**datos))
    return salida


@router.get("/{debate_id}/versiones/{numero}", response_model=VersionDetalle)
def version(debate_id: int, numero: int, db: Db) -> VersionDetalle:
    debate = _exigir_debate(db, debate_id)
    fila = repo_versiones.obtener(db, debate_id, numero)
    if fila is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Versión no encontrada.")
    actual, autor = fila
    anterior = repo_versiones.obtener(db, debate_id, numero - 1)
    datos = _resumen_version(
        actual, autor, None if anterior is None else anterior[0], debate.version_actual
    )
    cambios = datos.pop("_cambios")
    return VersionDetalle(
        **datos, **repo_versiones.contenido_de(actual), cambios=[CambioCampo(**c) for c in cambios]
    )


@router.post(
    "/{debate_id}/aclaraciones",
    response_model=AclaracionSalida,
    status_code=status.HTTP_201_CREATED,
)
def aclarar(
    debate_id: int, datos: AclaracionEntrada, db: Db, usuario: UsuarioActual
) -> AclaracionSalida:
    """Añadido fechado e inmutable del autor; no cambia el contenido ni crea versión."""
    try:
        aclaracion = repo_versiones.aclarar(db, debate_id, usuario.id, datos.texto)
    except repo_versiones.DebateNoEncontrado:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.") from None
    except repo_versiones.NoEsAutor:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, detail="Solo quien creó este debate puede aclararlo."
        ) from None
    except repo_versiones.DebateNoActivo:
        raise HTTPException(
            status.HTTP_409_CONFLICT, detail="Este debate está archivado: es de solo lectura."
        ) from None
    return AclaracionSalida(
        id=aclaracion.id,
        texto=aclaracion.texto,
        autor_nombre=usuario.nombre,
        creada_en=aclaracion.creada_en,
    )


@router.post("/{debate_id}/archivar", response_model=DebateDetalle)
def archivar(
    debate_id: int, datos: ArchivoDirectoEntrada, db: Db, administrador: AdministradorActual
) -> DebateDetalle:
    """Archivo directo por la administración, con motivo obligatorio (interno).

    Cualquier otra cuenta recibe 403, aunque sea la autora: el autor debe solicitarlo
    (`POST /debates/{id}/solicitud-archivo`). Se conservan el contenido y los aportes.
    """
    try:
        repo_solicitudes.archivar_directamente(db, debate_id, administrador.id, datos.motivo)
    except repo_solicitudes.DebateNoEncontrado:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Debate no encontrado.") from None
    except repo_solicitudes.DebateYaArchivado:
        raise HTTPException(
            status.HTTP_409_CONFLICT, detail="Este debate ya está archivado."
        ) from None
    return _detalle_salida(db, debate_id, administrador)

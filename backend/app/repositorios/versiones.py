"""Historial de versiones publicadas de un debate y aclaraciones del autor.

Las versiones y las aclaraciones solo se insertan: no hay ninguna ruta ni función que las
modifique o borre. Los borradores nunca generan versiones.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import (
    CAMPOS_VERSION,
    Aclaracion,
    Debate,
    EstadoDebate,
    Procedencia,
    TipoVersion,
    Usuario,
    VersionDebate,
)


class DebateNoEncontrado(Exception):
    pass


class NoEsAutor(Exception):
    pass


class DebateNoActivo(Exception):
    pass


def contenido_de(objeto: Debate | VersionDebate | dict) -> dict:
    """Los 7 campos de contenido, comparables entre debate, versión y valores nuevos."""
    if isinstance(objeto, dict):
        return {c: objeto.get(c) for c in CAMPOS_VERSION}
    return {c: getattr(objeto, c) for c in CAMPOS_VERSION}


def nueva_version(
    db: Session,
    debate: Debate,
    numero: int,
    tipo: TipoVersion,
    autor_id: int | None = None,
    motivo: str | None = None,
) -> VersionDebate:
    """Inserta la versión `numero` con el contenido actual de `debate` (sin hacer commit)."""
    version = VersionDebate(
        debate_id=debate.id,
        numero=numero,
        tipo=tipo.value,
        autor_id=autor_id,
        motivo=motivo,
        **contenido_de(debate),
    )
    db.add(version)
    return version


def listar(db: Session, debate_id: int) -> list[tuple[VersionDebate, str | None]]:
    """Versiones del debate con el nombre de quien hizo el cambio, de la más reciente a la primera."""
    filas = db.execute(
        select(VersionDebate, Usuario.nombre)
        .outerjoin(Usuario, VersionDebate.autor_id == Usuario.id)
        .where(VersionDebate.debate_id == debate_id)
        .order_by(VersionDebate.numero.desc())
    )
    return [(v, nombre) for v, nombre in filas]


def obtener(db: Session, debate_id: int, numero: int) -> tuple[VersionDebate, str | None] | None:
    fila = db.execute(
        select(VersionDebate, Usuario.nombre)
        .outerjoin(Usuario, VersionDebate.autor_id == Usuario.id)
        .where(VersionDebate.debate_id == debate_id, VersionDebate.numero == numero)
    ).first()
    return None if fila is None else (fila[0], fila[1])


def id_de(db: Session, debate_id: int, numero: int) -> int | None:
    return db.scalar(
        select(VersionDebate.id).where(
            VersionDebate.debate_id == debate_id, VersionDebate.numero == numero
        )
    )


def numeros_por_id(db: Session, ids: set[int]) -> dict[int, int]:
    if not ids:
        return {}
    filas = db.execute(
        select(VersionDebate.id, VersionDebate.numero).where(VersionDebate.id.in_(ids))
    )
    return {id_: numero for id_, numero in filas}


def cambios(anterior: VersionDebate | None, actual: VersionDebate) -> list[dict]:
    """Campos que cambiaron respecto a la versión anterior, con su valor antes y después."""
    if anterior is None:
        return []
    antes, despues = contenido_de(anterior), contenido_de(actual)
    return [
        {"campo": c, "antes": antes[c], "despues": despues[c]}
        for c in CAMPOS_VERSION
        if antes[c] != despues[c]
    ]


# --- Aclaraciones ---------------------------------------------------------------------------


def aclaraciones(db: Session, debate_id: int) -> list[tuple[Aclaracion, str]]:
    """Aclaraciones del debate en orden cronológico, con el nombre de quien las escribió."""
    filas = db.execute(
        select(Aclaracion, Usuario.nombre)
        .join(Usuario, Aclaracion.autor_id == Usuario.id)
        .where(Aclaracion.debate_id == debate_id)
        .order_by(Aclaracion.creada_en, Aclaracion.id)
    )
    return [(a, nombre) for a, nombre in filas]


def aclarar(db: Session, debate_id: int, autor_id: int, texto: str) -> Aclaracion:
    """Añade una aclaración a un debate propio activo. No toca el contenido ni las versiones."""
    debate = db.get(Debate, debate_id)
    if debate is None:
        raise DebateNoEncontrado
    if debate.procedencia != Procedencia.usuario.value or debate.autor_id != autor_id:
        raise NoEsAutor
    aclaracion = Aclaracion(debate_id=debate_id, autor_id=autor_id, texto=texto)
    db.add(aclaracion)
    db.flush()
    # Con el bloqueo de escritura tomado: si el debate se archivó entretanto, no se guarda.
    if db.scalar(select(Debate.estado).where(Debate.id == debate_id)) != (
        EstadoDebate.publicado.value
    ):
        db.rollback()
        raise DebateNoActivo
    db.commit()
    return aclaracion

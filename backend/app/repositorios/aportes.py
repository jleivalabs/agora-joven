"""Acceso a datos de aportes."""

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models import Aporte, Debate, EstadoDebate, Usuario, VersionDebate, ahora_utc
from app.repositorios import versiones as repo_versiones


class DebateArchivado(Exception):
    """El debate está archivado: no admite aportes nuevos ni cambios en los existentes."""


def _exigir_activo(db: Session, debate_id: int) -> None:
    """Se llama después de escribir, dentro de la misma transacción: con el bloqueo de escritura
    de SQLite tomado, ningún archivado concurrente puede confirmarse entre la comprobación y el
    commit."""
    estado = db.scalar(select(Debate.estado).where(Debate.id == debate_id))
    if estado != EstadoDebate.publicado.value:
        db.rollback()
        raise DebateArchivado


def listar(db: Session, debate_id: int) -> list[tuple[Aporte, str, int | None]]:
    """Aportes del debate con el nombre de su autor y el número de versión (None si es anterior
    al historial). Más recientes primero; desempate por id."""
    consulta = (
        select(Aporte, Usuario.nombre, VersionDebate.numero)
        .join(Usuario, Aporte.autor_id == Usuario.id)
        .outerjoin(VersionDebate, Aporte.version_id == VersionDebate.id)
        .where(Aporte.debate_id == debate_id)
        .order_by(Aporte.creado_en.desc(), Aporte.id.desc())
    )
    return [(aporte, nombre, numero) for aporte, nombre, numero in db.execute(consulta)]


def obtener(db: Session, aporte_id: int) -> Aporte | None:
    return db.get(Aporte, aporte_id)


class VersionDesactualizada(Exception):
    """La versión indicada es del debate, pero ya no es la vigente."""

    def __init__(self, version_actual: int | None):
        super().__init__(version_actual)
        self.version_actual = version_actual


class VersionInexistente(Exception):
    """La versión indicada no pertenece a este debate."""


def crear(
    db: Session, debate_id: int, autor_id: int, tipo: str, texto: str, version: int
) -> Aporte:
    """Publica un aporte sobre la versión que la persona estaba viendo.

    Primero un UPDATE condicionado marca la participación permanente **solo si** el debate sigue
    publicado y `version` es la vigente. Ese UPDATE toma el bloqueo de escritura de SQLite: una
    edición simultánea no puede cambiar la versión entre la comprobación y la inserción del aporte
    (y, una vez marcada la participación, la edición queda rechazada). Nunca se publica
    automáticamente contra otra versión.
    """
    marcado = db.execute(
        update(Debate)
        .where(
            Debate.id == debate_id,
            Debate.estado == EstadoDebate.publicado.value,
            Debate.version_actual == version,
        )
        .values(con_participacion=True)
        .execution_options(synchronize_session=False)
    )
    if marcado.rowcount != 1:
        db.rollback()
        estado, actual = db.execute(
            select(Debate.estado, Debate.version_actual).where(Debate.id == debate_id)
        ).one()
        if estado != EstadoDebate.publicado.value:
            raise DebateArchivado
        if repo_versiones.id_de(db, debate_id, version) is None:
            raise VersionInexistente
        raise VersionDesactualizada(actual)
    aporte = Aporte(
        debate_id=debate_id,
        autor_id=autor_id,
        tipo=tipo,
        texto=texto,
        version_id=repo_versiones.id_de(db, debate_id, version),
    )
    db.add(aporte)
    db.commit()
    return aporte


def actualizar(db: Session, aporte: Aporte, cambios: dict[str, str]) -> Aporte:
    """Aplica solo los valores distintos; marca la edición si algo cambió."""
    distintos = {k: v for k, v in cambios.items() if getattr(aporte, k) != v}
    for campo, valor in distintos.items():
        setattr(aporte, campo, valor)
    if distintos:
        aporte.editado_en = ahora_utc()
        db.flush()
        _exigir_activo(db, aporte.debate_id)
        db.commit()
    return aporte


def eliminar(db: Session, aporte: Aporte) -> None:
    debate_id = aporte.debate_id
    db.delete(aporte)
    db.flush()
    _exigir_activo(db, debate_id)
    db.commit()

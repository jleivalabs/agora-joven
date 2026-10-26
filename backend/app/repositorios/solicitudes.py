"""Solicitudes de archivo y archivo directo por la administración.

Las decisiones se aplican con sentencias UPDATE condicionadas al estado actual (`pendiente`,
`publicado`). En SQLite el primer UPDATE toma el bloqueo de escritura hasta el commit, así que
dos peticiones simultáneas no pueden resolver la misma solicitud ni dejar resultados incoherentes:
la segunda no encuentra filas que cumplan la condición. Nada se borra.
"""

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, aliased

from app.models import (
    Aporte,
    Debate,
    EstadoDebate,
    EstadoSolicitud,
    OrigenArchivo,
    SolicitudArchivo,
    Usuario,
    ahora_utc,
)

PENDIENTE = EstadoSolicitud.pendiente.value
PUBLICADO = EstadoDebate.publicado.value
ARCHIVADO = EstadoDebate.archivado.value

# Respuesta que ve el solicitante si la administración archiva el debate directamente mientras
# su solicitud estaba pendiente (el motivo interno del archivo no se le muestra).
RESPUESTA_ARCHIVO_DIRECTO = "La administración archivó el debate directamente."


class DebateNoEncontrado(Exception):
    pass


class NoEsAutor(Exception):
    pass


class DebateYaArchivado(Exception):
    pass


class SolicitudNoPendiente(Exception):
    """La solicitud ya se resolvió o se canceló (por ejemplo, en una petición simultánea)."""


def crear(
    db: Session, debate_id: int, solicitante_id: int, motivo: str
) -> tuple[SolicitudArchivo, bool]:
    """Crea la solicitud o devuelve la pendiente existente (sin duplicar). (solicitud, creada)."""
    debate = db.get(Debate, debate_id)
    if debate is None:
        raise DebateNoEncontrado
    if debate.autor_id is None or debate.autor_id != solicitante_id:
        raise NoEsAutor
    if debate.estado != PUBLICADO:
        raise DebateYaArchivado
    existente = pendiente_de(db, debate_id)
    if existente is not None:
        return existente, False

    solicitud = SolicitudArchivo(
        debate_id=debate_id, solicitante_id=solicitante_id, motivo=motivo, estado=PENDIENTE
    )
    db.add(solicitud)
    try:
        db.flush()
    except IntegrityError:
        # Otra petición simultánea creó la pendiente (índice único parcial): se devuelve esa.
        db.rollback()
        return pendiente_de(db, debate_id), False
    # Con el bloqueo de escritura tomado: si el debate se archivó entretanto, no se guarda.
    if db.scalar(select(Debate.estado).where(Debate.id == debate_id)) != PUBLICADO:
        db.rollback()
        raise DebateYaArchivado
    db.commit()
    return solicitud, True


def pendiente_de(db: Session, debate_id: int) -> SolicitudArchivo | None:
    return db.scalar(
        select(SolicitudArchivo).where(
            SolicitudArchivo.debate_id == debate_id, SolicitudArchivo.estado == PENDIENTE
        )
    )


def obtener(db: Session, solicitud_id: int) -> SolicitudArchivo | None:
    return db.get(SolicitudArchivo, solicitud_id)


def propias(db: Session, solicitante_id: int) -> list[tuple[SolicitudArchivo, str]]:
    """Solicitudes de la cuenta con el título del debate, de la más reciente a la más antigua."""
    filas = db.execute(
        select(SolicitudArchivo, Debate.titulo)
        .join(Debate, SolicitudArchivo.debate_id == Debate.id)
        .where(SolicitudArchivo.solicitante_id == solicitante_id)
        .order_by(SolicitudArchivo.id.desc())
    )
    return [(s, titulo) for s, titulo in filas]


def ultimas_por_debate(db: Session, solicitante_id: int) -> dict[int, SolicitudArchivo]:
    """La solicitud más reciente de la cuenta para cada uno de sus debates."""
    resultado: dict[int, SolicitudArchivo] = {}
    for solicitud in db.scalars(
        select(SolicitudArchivo)
        .where(SolicitudArchivo.solicitante_id == solicitante_id)
        .order_by(SolicitudArchivo.id.desc())
    ):
        resultado.setdefault(solicitud.debate_id, solicitud)
    return resultado


def cancelar(db: Session, solicitud: SolicitudArchivo) -> SolicitudArchivo:
    """Cancela una pendiente propia. Repetir sobre una ya cancelada no cambia nada."""
    resultado = db.execute(
        update(SolicitudArchivo)
        .where(SolicitudArchivo.id == solicitud.id, SolicitudArchivo.estado == PENDIENTE)
        .values(estado=EstadoSolicitud.cancelada.value, resuelta_en=ahora_utc())
        .execution_options(synchronize_session=False)
    )
    db.commit()
    db.refresh(solicitud)
    if resultado.rowcount != 1 and solicitud.estado != EstadoSolicitud.cancelada.value:
        raise SolicitudNoPendiente
    return solicitud


def resolver(
    db: Session, solicitud_id: int, revisor_id: int, aprobar: bool, justificacion: str
) -> None:
    """Aprueba (archiva el debate) o rechaza (el debate sigue activo) en una transacción."""
    resultado = db.execute(
        update(SolicitudArchivo)
        .where(SolicitudArchivo.id == solicitud_id, SolicitudArchivo.estado == PENDIENTE)
        .values(
            estado=(EstadoSolicitud.aprobada if aprobar else EstadoSolicitud.rechazada).value,
            revisor_id=revisor_id,
            justificacion=justificacion,
            resuelta_en=ahora_utc(),
        )
        .execution_options(synchronize_session=False)
    )
    if resultado.rowcount != 1:
        db.rollback()
        raise SolicitudNoPendiente
    if aprobar:
        debate_id, motivo = db.execute(
            select(SolicitudArchivo.debate_id, SolicitudArchivo.motivo).where(
                SolicitudArchivo.id == solicitud_id
            )
        ).one()
        if not _archivar(db, debate_id, revisor_id, motivo, OrigenArchivo.solicitud):
            # No debería ocurrir (el archivo directo cierra las pendientes), pero si el debate ya
            # no está publicado no se deja una aprobación sin efecto.
            db.rollback()
            raise DebateYaArchivado
    db.commit()


def archivar_directamente(db: Session, debate_id: int, admin_id: int, motivo: str) -> None:
    """Archivo directo de un debate activo; cierra como aprobada la solicitud pendiente, si hay."""
    if not _archivar(db, debate_id, admin_id, motivo, OrigenArchivo.administracion):
        db.rollback()
        if db.get(Debate, debate_id) is None:
            raise DebateNoEncontrado
        raise DebateYaArchivado
    db.execute(
        update(SolicitudArchivo)
        .where(SolicitudArchivo.debate_id == debate_id, SolicitudArchivo.estado == PENDIENTE)
        .values(
            estado=EstadoSolicitud.aprobada.value,
            revisor_id=admin_id,
            justificacion=RESPUESTA_ARCHIVO_DIRECTO,
            resuelta_en=ahora_utc(),
        )
        .execution_options(synchronize_session=False)
    )
    db.commit()


def _archivar(
    db: Session, debate_id: int, admin_id: int, motivo: str, origen: OrigenArchivo
) -> bool:
    resultado = db.execute(
        update(Debate)
        .where(Debate.id == debate_id, Debate.estado == PUBLICADO)
        .values(
            estado=ARCHIVADO,
            archivado_en=ahora_utc(),
            archivo_origen=origen.value,
            archivado_por_id=admin_id,
            motivo_archivo=motivo,
        )
        .execution_options(synchronize_session=False)
    )
    return resultado.rowcount == 1


def para_administracion(
    db: Session, estado: EstadoSolicitud | None = None, solicitud_id: int | None = None
) -> list[tuple]:
    """Solicitudes con nombres (nunca correos) y datos del debate. Pendientes: más antiguas
    primero (orden de llegada); resto: más recientes primero."""
    solicitante = aliased(Usuario)
    revisor = aliased(Usuario)
    aportes = (
        select(func.count(Aporte.id)).where(Aporte.debate_id == Debate.id).scalar_subquery()
    )
    consulta = (
        select(SolicitudArchivo, solicitante.nombre, revisor.nombre, Debate, aportes)
        .join(Debate, SolicitudArchivo.debate_id == Debate.id)
        .join(solicitante, SolicitudArchivo.solicitante_id == solicitante.id)
        .outerjoin(revisor, SolicitudArchivo.revisor_id == revisor.id)
    )
    if solicitud_id is not None:
        consulta = consulta.where(SolicitudArchivo.id == solicitud_id)
    if estado is not None:
        consulta = consulta.where(SolicitudArchivo.estado == estado.value)
    orden = (
        SolicitudArchivo.id.asc() if estado == EstadoSolicitud.pendiente
        else SolicitudArchivo.id.desc()
    )
    return [tuple(fila) for fila in db.execute(consulta.order_by(orden))]

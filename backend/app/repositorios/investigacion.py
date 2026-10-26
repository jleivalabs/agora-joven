"""Referencias, redacción pendiente y procedencia de sugerencias aceptadas en un borrador propio.

Las columnas JSON se reasignan completas (copias nuevas) para que SQLAlchemy detecte el cambio.
Solo se guarda lo seleccionado o aceptado: los resultados de búsqueda y las sugerencias
descartadas no se conservan.
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.investigacion import huella_contenido, nueva_redaccion
from app.models import Borrador, ahora_utc

MAX_REFERENCIAS_BORRADOR = 8
MAX_CONTEXTO = 3000
MAX_PERSPECTIVAS = 5


class LimiteReferencias(Exception):
    pass


class SugerenciaNoEncontrada(Exception):
    pass


class CampoCambiado(Exception):
    """El campo ya no tiene el valor que la persona vio al confirmar el cambio."""


class SinEspacio(Exception):
    """El cambio superaría los límites del campo (longitud o número de perspectivas)."""


def _guardar(db: Session, borrador: Borrador, **campos) -> Borrador:
    for campo, valor in campos.items():
        setattr(borrador, campo, valor)
    borrador.actualizado_en = ahora_utc()
    db.commit()
    return borrador


def agregar_referencia(db: Session, borrador: Borrador, referencia: dict) -> Borrador:
    actuales = list(borrador.referencias or [])
    if any(r["doi"] == referencia["doi"] for r in actuales):
        return borrador  # ya estaba: no se duplica
    if len(actuales) >= MAX_REFERENCIAS_BORRADOR:
        raise LimiteReferencias
    dois = {r["doi"] for r in actuales} | {referencia["doi"]}
    nuevas = []
    for r in [*actuales, referencia]:
        relacionadas = {x["doi"] for x in r.get("relacionadas", [])}
        nuevas.append({**r, "misma_obra_que": sorted((relacionadas & dois) - {r["doi"]})})
    return _guardar(db, borrador, referencias=nuevas)


def quitar_referencia(db: Session, borrador: Borrador, doi: str) -> Borrador:
    """Quita la referencia; las afirmaciones aceptadas que la citaban quedan por revisar."""
    referencias = [r for r in borrador.referencias or [] if r["doi"] != doi]
    evidencias = []
    for e in borrador.evidencias or []:
        if doi in e.get("referencias", []):
            e = {**e, "referencias": [d for d in e["referencias"] if d != doi], "requiere_revision": True}
        evidencias.append(e)
    return _guardar(db, borrador, referencias=referencias, evidencias=evidencias)


def guardar_redaccion(
    db: Session, borrador: Borrador, sugerencias: list[dict], limitaciones: list[str]
) -> Borrador:
    """Sustituye las sugerencias pendientes anteriores por las nuevas (solo la última consulta)."""
    return _guardar(db, borrador, redaccion=nueva_redaccion(borrador, sugerencias, limitaciones))


def _sugerencia(borrador: Borrador, sugerencia_id: str) -> dict:
    for s in (borrador.redaccion or {}).get("sugerencias", []):
        if s["id"] == sugerencia_id and s["estado"] == "pendiente":
            return s
    raise SugerenciaNoEncontrada


def _sin_pendientes(redaccion: dict) -> dict | None:
    return redaccion if any(s["estado"] == "pendiente" for s in redaccion["sugerencias"]) else None


def aceptar(
    db: Session,
    borrador: Borrador,
    sugerencia_id: str,
    *,
    modo: str,
    valor_anterior: str | None,
    texto: str | None,
    titulo: str | None,
    descripcion: str | None,
) -> Borrador:
    """Aplica una sugerencia (editada o no) y registra su procedencia. Las demás pendientes se
    conservan. Nada se aplica sin esta acción explícita."""
    sugerencia = _sugerencia(borrador, sugerencia_id)
    cambios: dict = {}
    if sugerencia["tipo"] in ("contexto", "afirmacion"):
        aceptado = (texto or sugerencia["texto"]).strip()
        actual = borrador.contexto or ""
        if (valor_anterior or "") != actual:
            raise CampoCambiado
        nuevo = aceptado if modo == "sustituir" or not actual else f"{actual}\n\n{aceptado}"
        if len(nuevo) > MAX_CONTEXTO:
            raise SinEspacio
        cambios["contexto"] = nuevo
        campo, original = "contexto", sugerencia["texto"]
    elif sugerencia["tipo"] == "perspectiva":
        perspectivas = list(borrador.perspectivas or [])
        if len([p for p in perspectivas if p.get("titulo") or p.get("descripcion")]) >= MAX_PERSPECTIVAS:
            raise SinEspacio
        t = (titulo or sugerencia["titulo"]).strip()[:80]
        d = (descripcion or sugerencia["descripcion"]).strip()[:600]
        vacias = [i for i, p in enumerate(perspectivas) if not p.get("titulo") and not p.get("descripcion")]
        if vacias:
            perspectivas[vacias[0]] = {"titulo": t, "descripcion": d}
        else:
            perspectivas.append({"titulo": t, "descripcion": d})
        cambios["perspectivas"] = perspectivas
        campo, aceptado = "perspectivas", f"{t}: {d}"
        original = f"{sugerencia['titulo']}: {sugerencia['descripcion']}"
    else:  # pregunta: nota privada del borrador, no cambia campos públicos
        aceptado = (texto or sugerencia["texto"]).strip()
        campo, original = "preguntas", sugerencia["texto"]

    editada = aceptado != original
    evidencia = {
        "id": uuid4().hex[:12],
        "tipo": sugerencia["tipo"],
        "campo": campo,
        "procedencia": "sugerencia_ia",
        "texto_sugerido": original,
        "texto_aceptado": aceptado,
        "editada": editada,
        "referencias": list(sugerencia.get("referencias", [])),
        # Si se modifica una afirmación ligada a fuentes, la relación necesita revisión.
        "requiere_revision": editada and bool(sugerencia.get("referencias")),
        "aceptada_en": datetime.now(timezone.utc).isoformat(),
    }
    redaccion = {
        **borrador.redaccion,
        "sugerencias": [
            {**s, "estado": "aceptada"} if s["id"] == sugerencia_id else s
            for s in borrador.redaccion["sugerencias"]
        ],
    }
    return _guardar(
        db,
        borrador,
        **cambios,
        evidencias=[*(borrador.evidencias or []), evidencia],
        redaccion=_sin_pendientes(redaccion),
    )


def descartar(db: Session, borrador: Borrador, sugerencia_id: str) -> Borrador:
    """Quita solo esa sugerencia (no se guarda lo descartado); las demás siguen pendientes."""
    _sugerencia(borrador, sugerencia_id)
    redaccion = {
        **borrador.redaccion,
        "sugerencias": [s for s in borrador.redaccion["sugerencias"] if s["id"] != sugerencia_id],
    }
    return _guardar(db, borrador, redaccion=_sin_pendientes(redaccion))


def redaccion_vigente(borrador: Borrador) -> dict | None:
    """Redacción pendiente con la marca de si el borrador cambió después de pedirla."""
    if not borrador.redaccion:
        return None
    return {**borrador.redaccion, "desactualizada": borrador.redaccion["base"] != huella_contenido(borrador)}


def evidencias_publicas(borrador: Borrador, debate_contexto: str, perspectivas: list[dict]) -> list[dict]:
    """Procedencia que se publica: solo lo que afecta a campos públicos (contexto, perspectivas).
    Indica si el texto aceptado seguía tal cual al publicar."""
    publicas = []
    for e in borrador.evidencias or []:
        if e["campo"] == "contexto":
            presente = e["texto_aceptado"] in (debate_contexto or "")
        elif e["campo"] == "perspectivas":
            presente = e["texto_aceptado"] in {
                f"{p.get('titulo')}: {p.get('descripcion')}" for p in perspectivas
            }
        else:
            continue
        publicas.append({**e, "presente_al_publicar": presente})
    return publicas

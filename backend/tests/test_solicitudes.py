"""Roles y solicitudes de archivo: autor, cuenta ajena y administración."""

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.admin import cambiar_rol, ejecutar
from app.config import JWT_ALGORITMO
from app.models import Rol, SolicitudArchivo, Usuario
from app.repositorios import solicitudes as repo
from tests.conftest import PASSWORD
from tests.test_borradores import _publicado

MOTIVO = {"motivo": "El debate quedó desactualizado tras el cambio de horario."}
JUSTIFICACION = {"justificacion": "Se comprobó que el debate ya no aplica."}


@pytest.fixture
def ana(auth):
    return auth


@pytest.fixture
def beto(sesion_de):
    return sesion_de("beto@example.com", "Beto")


@pytest.fixture
def debate(client, ana):
    return _publicado(client, ana)[1]


def _solicitar(client, cabecera, debate_id, cuerpo=MOTIVO):
    return client.post(f"/debates/{debate_id}/solicitud-archivo", json=cuerpo, headers=cabecera)


def _aportar(client, cabecera, debate_id):
    return client.post(
        f"/debates/{debate_id}/aportes",
        json={"tipo": "argumento", "texto": "Un argumento con texto suficiente.", "version": 1},
        headers=cabecera,
    )


# --- Roles ------------------------------------------------------------------------------------


def test_el_registro_crea_usuarios_y_rechaza_asignar_rol(client, registrar):
    for extra in ({"rol": "administrador"}, {"rol": "usuario"}, {"es_admin": True}):
        r = client.post(
            "/auth/registro",
            json={
                "nombre": "Eva",
                "email": "eva@example.com",
                "password": PASSWORD,
                "confirma_mayoria_edad": True,
                **extra,
            },
        )
        assert r.status_code == 422
    assert registrar(email="eva@example.com", nombre="Eva")["rol"] == "usuario"


def test_no_hay_edicion_de_perfil_que_cambie_el_rol(client, ana):
    for metodo in ("patch", "put"):
        r = client.request(metodo, "/auth/me", json={"rol": "administrador"}, headers=ana)
        assert r.status_code == 405
    assert client.get("/auth/me", headers=ana).json()["rol"] == "usuario"


def test_un_rol_en_el_token_o_en_la_peticion_no_da_permisos(client, ana, settings):
    usuario_id = client.get("/auth/me", headers=ana).json()["id"]
    ahora = datetime.now(timezone.utc)
    # Token válido (misma firma) con un rol añadido: el servidor lo ignora.
    falso = jwt.encode(
        {"sub": str(usuario_id), "iat": ahora, "exp": ahora + timedelta(minutes=5),
         "rol": "administrador"},
        settings.jwt_secret.get_secret_value(),
        algorithm=JWT_ALGORITMO,
    )
    cabecera = {"Authorization": f"Bearer {falso}", "X-Rol": "administrador"}
    assert client.get("/admin/solicitudes-archivo", headers=cabecera).status_code == 403
    assert client.get(
        "/admin/solicitudes-archivo", params={"rol": "administrador"}, headers=ana
    ).status_code == 403


def test_el_rol_se_comprueba_en_cada_peticion(client, admin):
    assert client.get("/admin/solicitudes-archivo", headers=admin).status_code == 200
    with client.app.state.fabrica_sesiones() as db:
        cambiar_rol(db, client.get("/auth/me", headers=admin).json()["id"], Rol.usuario)
    # Mismo token, rol retirado en la base: efecto inmediato.
    assert client.get("/admin/solicitudes-archivo", headers=admin).status_code == 403


def test_rutas_de_administracion_rechazan_usuarios_normales(client, ana, beto, debate):
    sid = _solicitar(client, ana, debate["id"]).json()["id"]
    for cabecera in (ana, beto):  # ni la autora ni una cuenta ajena
        assert client.get("/admin/solicitudes-archivo", headers=cabecera).status_code == 403
        assert client.get(f"/admin/solicitudes-archivo/{sid}", headers=cabecera).status_code == 403
        for accion in ("aprobar", "rechazar"):
            r = client.post(
                f"/admin/solicitudes-archivo/{sid}/{accion}", json=JUSTIFICACION, headers=cabecera
            )
            assert r.status_code == 403
        # El 403 llega antes de validar el cuerpo.
        assert client.post(f"/debates/{debate['id']}/archivar", headers=cabecera).status_code == 403
    assert client.get("/admin/solicitudes-archivo").status_code == 401


# --- Solicitud del autor ----------------------------------------------------------------------


def test_solicitar_no_duplica_ni_archiva_ni_bloquea(client, ana, beto, debate):
    r = _solicitar(client, ana, debate["id"])
    assert r.status_code == 201
    solicitud = r.json()
    assert solicitud["estado"] == "pendiente" and solicitud["respuesta"] is None
    assert set(solicitud) == {
        "id", "debate_id", "motivo", "estado", "creada_en", "resuelta_en", "respuesta"
    }

    otra = _solicitar(client, ana, debate["id"], {"motivo": "Otro motivo distinto y largo."})
    assert otra.status_code == 200 and otra.json()["id"] == solicitud["id"]
    with client.app.state.fabrica_sesiones() as db:
        assert len(db.scalars(select(SolicitudArchivo)).all()) == 1

    # El debate sigue activo, en el catálogo, editable mientras no tenga aportes y abierto.
    detalle = client.get(f"/debates/{debate['id']}", headers=ana).json()
    assert detalle["estado"] == "publicado" and detalle["editable"] is True
    assert detalle["solicitud_archivo"]["estado"] == "pendiente"
    assert debate["id"] in [d["id"] for d in client.get("/debates", headers=beto).json()]
    assert _aportar(client, beto, debate["id"]).status_code == 201


def test_solo_el_autor_solicita_sobre_su_debate_activo(client, ana, beto, admin, debate):
    assert _solicitar(client, beto, debate["id"]).status_code == 403
    assert _solicitar(client, admin, debate["id"]).status_code == 403
    assert _solicitar(client, ana, 1).status_code == 403  # editorial: sin autor
    assert _solicitar(client, ana, 9999).status_code == 404
    for cuerpo in ({}, {"motivo": "corto"}, {**MOTIVO, "estado": "aprobada"}, {**MOTIVO, "solicitante_id": 2}):
        assert _solicitar(client, ana, debate["id"], cuerpo).status_code == 422
    client.post(f"/debates/{debate['id']}/archivar", json=MOTIVO, headers=admin)
    assert _solicitar(client, ana, debate["id"]).status_code == 409


def test_cancelar_solo_la_propia_y_mientras_esta_pendiente(client, ana, beto, admin, debate):
    sid = _solicitar(client, ana, debate["id"]).json()["id"]
    assert client.get(f"/solicitudes-archivo/{sid}", headers=beto).status_code == 404
    assert client.post(f"/solicitudes-archivo/{sid}/cancelar", headers=beto).status_code == 404
    assert client.get("/solicitudes-archivo", headers=beto).json() == []

    r = client.post(f"/solicitudes-archivo/{sid}/cancelar", headers=ana)
    assert r.status_code == 200 and r.json()["estado"] == "cancelada"
    assert client.post(f"/solicitudes-archivo/{sid}/cancelar", headers=ana).status_code == 200
    # Cancelada no se puede resolver; se puede volver a solicitar (nueva fila, sin borrar la otra).
    assert client.post(
        f"/admin/solicitudes-archivo/{sid}/aprobar", json=JUSTIFICACION, headers=admin
    ).status_code == 409
    nueva = _solicitar(client, ana, debate["id"])
    assert nueva.status_code == 201 and nueva.json()["id"] != sid
    assert [s["estado"] for s in client.get("/solicitudes-archivo", headers=ana).json()] == [
        "pendiente", "cancelada"
    ]


# --- Revisión ---------------------------------------------------------------------------------


def test_aprobar_archiva_conservando_aportes(client, ana, beto, admin, debate):
    aporte = _aportar(client, beto, debate["id"]).json()
    sid = _solicitar(client, ana, debate["id"]).json()["id"]

    pendientes = client.get("/admin/solicitudes-archivo", headers=admin)
    assert [s["id"] for s in pendientes.json()] == [sid]
    assert "@" not in pendientes.text  # nombres, nunca correos
    vista = client.get(f"/admin/solicitudes-archivo/{sid}", headers=admin).json()
    assert vista["solicitante_nombre"] == "Ana" and vista["debate_aportes"] == 1

    r = client.post(f"/admin/solicitudes-archivo/{sid}/aprobar", json=JUSTIFICACION, headers=admin)
    assert r.status_code == 200
    registro = r.json()
    assert registro["estado"] == "aprobada" and registro["revisor_nombre"] == "Revisora"
    assert registro["justificacion"] == JUSTIFICACION["justificacion"] and registro["resuelta_en"]
    assert registro["motivo"] == MOTIVO["motivo"]

    detalle = client.get(f"/debates/{debate['id']}", headers=beto).json()
    assert detalle["estado"] == "archivado" and detalle["archivo_origen"] == "solicitud"
    assert [a["id"] for a in client.get(f"/debates/{debate['id']}/aportes", headers=beto).json()] == [
        aporte["id"]
    ]
    assert _aportar(client, beto, debate["id"]).status_code == 409
    assert client.get("/admin/solicitudes-archivo", headers=admin).json() == []
    # Sin dobles resoluciones ni cancelación tardía.
    for accion in ("aprobar", "rechazar"):
        assert client.post(
            f"/admin/solicitudes-archivo/{sid}/{accion}", json=JUSTIFICACION, headers=admin
        ).status_code == 409
    assert client.post(f"/solicitudes-archivo/{sid}/cancelar", headers=ana).status_code == 409


def test_rechazar_mantiene_el_debate_activo(client, ana, beto, admin, debate):
    sid = _solicitar(client, ana, debate["id"]).json()["id"]
    assert client.post(
        f"/admin/solicitudes-archivo/{sid}/rechazar", json={"justificacion": "x"}, headers=admin
    ).status_code == 422  # justificación obligatoria
    r = client.post(f"/admin/solicitudes-archivo/{sid}/rechazar", json=JUSTIFICACION, headers=admin)
    assert r.status_code == 200 and r.json()["estado"] == "rechazada"

    assert client.get(f"/debates/{debate['id']}", headers=beto).json()["estado"] == "publicado"
    assert _aportar(client, beto, debate["id"]).status_code == 201
    # La autora consulta la resolución sin datos del revisor.
    propia = client.get(f"/solicitudes-archivo/{sid}", headers=ana).json()
    assert propia["estado"] == "rechazada" and propia["respuesta"] == JUSTIFICACION["justificacion"]
    assert "revisor" not in client.get(f"/debates/{debate['id']}", headers=ana).text
    mis = client.get("/mis-debates", headers=ana).json()
    assert mis["publicados"][0]["solicitud_archivo"]["estado"] == "rechazada"


def test_detalles_de_revision_privados_para_otras_cuentas(client, ana, beto, admin, debate):
    sid = _solicitar(client, ana, debate["id"]).json()["id"]
    client.post(f"/admin/solicitudes-archivo/{sid}/aprobar", json=JUSTIFICACION, headers=admin)

    texto = client.get(f"/debates/{debate['id']}", headers=beto).text
    for privado in (MOTIVO["motivo"], JUSTIFICACION["justificacion"], "Revisora"):
        assert privado not in texto
    assert client.get(f"/debates/{debate['id']}", headers=beto).json()["solicitud_archivo"] is None
    assert client.get("/solicitudes-archivo", headers=beto).json() == []


def test_archivo_directo_de_la_administracion(client, ana, beto, admin, debate):
    ruta = f"/debates/{debate['id']}/archivar"
    sid = _solicitar(client, ana, debate["id"]).json()["id"]
    _aportar(client, beto, debate["id"])
    assert client.post(ruta, json={}, headers=admin).status_code == 422  # motivo obligatorio
    assert client.post(ruta, json={"motivo": "corto"}, headers=admin).status_code == 422

    r = client.post(ruta, json={"motivo": "Contenido que incumple las normas."}, headers=admin)
    assert r.status_code == 200 and r.json()["archivo_origen"] == "administracion"
    assert r.json()["aportes"] == 1
    # La solicitud pendiente queda cerrada de forma coherente (no se puede volver a resolver).
    propia = client.get(f"/solicitudes-archivo/{sid}", headers=ana).json()
    assert propia["estado"] == "aprobada" and propia["respuesta"] == repo.RESPUESTA_ARCHIVO_DIRECTO
    assert client.post(
        f"/admin/solicitudes-archivo/{sid}/rechazar", json=JUSTIFICACION, headers=admin
    ).status_code == 409
    # También un debate editorial activo; nunca uno inexistente.
    assert client.post("/debates/2/archivar", json=MOTIVO, headers=admin).status_code == 200
    assert client.post("/debates/9999/archivar", json=MOTIVO, headers=admin).status_code == 404
    with client.app.state.fabrica_sesiones() as db:
        filas = db.execute(
            select(SolicitudArchivo.revisor_id, SolicitudArchivo.resuelta_en)
        ).all()
    assert all(revisor and resuelta for revisor, resuelta in filas)


# --- Concurrencia -----------------------------------------------------------------------------


def test_resoluciones_simultaneas_solo_aplican_una(client, ana, admin, debate):
    sid = _solicitar(client, ana, debate["id"]).json()["id"]

    def resolver(i: int) -> int:
        accion = "aprobar" if i % 2 else "rechazar"
        return client.post(
            f"/admin/solicitudes-archivo/{sid}/{accion}", json=JUSTIFICACION, headers=admin
        ).status_code

    with ThreadPoolExecutor(max_workers=6) as hilos:
        codigos = list(hilos.map(resolver, range(6)))

    assert sorted(codigos) == [200] + [409] * 5
    final = client.get(f"/admin/solicitudes-archivo/{sid}", headers=admin).json()
    estado_debate = client.get(f"/debates/{debate['id']}", headers=ana).json()["estado"]
    # Coherencia: aprobada ⇔ archivado; rechazada ⇔ publicado.
    assert (final["estado"], estado_debate) in {
        ("aprobada", "archivado"), ("rechazada", "publicado")
    }


def test_solicitudes_simultaneas_dejan_una_pendiente(client, ana, debate):
    with ThreadPoolExecutor(max_workers=6) as hilos:
        respuestas = list(hilos.map(lambda _: _solicitar(client, ana, debate["id"]), range(6)))

    assert len({r.json()["id"] for r in respuestas}) == 1
    assert sorted(r.status_code for r in respuestas) == [200] * 5 + [201]


def test_resolucion_con_datos_desactualizados_no_se_aplica(client, ana, admin, debate):
    """Una revisión que leyó la solicitud como pendiente antes de que otra la resolviera."""
    sid = _solicitar(client, ana, debate["id"]).json()["id"]
    fabrica = client.app.state.fabrica_sesiones
    with fabrica() as lenta, fabrica() as rapida:
        assert lenta.get(SolicitudArchivo, sid).estado == "pendiente"
        repo.resolver(rapida, sid, 1, False, "Rechazada primero.")
        with pytest.raises(repo.SolicitudNoPendiente):
            repo.resolver(lenta, sid, 1, True, "Aprobación tardía.")
    assert client.get(f"/debates/{debate['id']}", headers=ana).json()["estado"] == "publicado"


def test_la_base_impide_dos_pendientes_del_mismo_debate(client, ana, debate):
    _solicitar(client, ana, debate["id"])
    with client.app.state.fabrica_sesiones() as db:
        db.add(SolicitudArchivo(debate_id=debate["id"], solicitante_id=1, motivo="m", estado="pendiente"))
        with pytest.raises(IntegrityError):
            db.commit()


# --- Comando local de promoción ---------------------------------------------------------------


def test_comando_admin_pide_confirmacion_y_no_muestra_correos(client, ana, beto):
    salida: list[str] = []
    with client.app.state.fabrica_sesiones() as db:
        beto_id = db.scalar(select(Usuario.id).where(Usuario.nombre == "Beto"))

        assert ejecutar(db, ["listar"], salida=salida.append) == 0
        assert ejecutar(db, ["promover", "999"], salida=salida.append) == 1
        # Confirmación incorrecta o vacía: no cambia nada.
        assert ejecutar(db, ["promover", str(beto_id)], entrada=lambda _: "s", salida=salida.append) == 1
        assert db.get(Usuario, beto_id).rol == "usuario"
        assert ejecutar(
            db, ["promover", str(beto_id)], entrada=lambda _: str(beto_id), salida=salida.append
        ) == 0
        db.expire_all()
        assert db.get(Usuario, beto_id).rol == "administrador"
        assert ejecutar(
            db, ["retirar", str(beto_id)], entrada=lambda _: str(beto_id), salida=salida.append
        ) == 0

    texto = "\n".join(salida)
    assert "@" not in texto and PASSWORD not in texto and "argon" not in texto.lower()
    assert client.get("/auth/me", headers=beto).json()["rol"] == "usuario"

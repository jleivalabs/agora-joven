"""Bloque 7C: declaración de mayoría de edad (18 años o más). No es una verificación de edad."""

import pytest
from sqlalchemy import update

from app.models import Usuario
from tests.conftest import PASSWORD

BASE = {"nombre": "Eva", "email": "eva@example.com", "password": PASSWORD}


@pytest.mark.parametrize("valor", [False, "true", 1, "1", None, "sí"])
def test_registro_exige_un_true_estricto(client, valor):
    r = client.post("/auth/registro", json={**BASE, "confirma_mayoria_edad": valor})
    assert r.status_code == 422


def test_registro_sin_confirmacion_no_crea_la_cuenta(client):
    assert client.post("/auth/registro", json=BASE).status_code == 422
    r = client.post("/auth/login", json={"email": BASE["email"], "password": PASSWORD})
    assert r.status_code == 401


def test_registro_con_confirmacion_guarda_la_declaracion(client):
    r = client.post("/auth/registro", json={**BASE, "confirma_mayoria_edad": True})
    assert r.status_code == 201 and r.json()["edad_confirmada"] is True
    for clave in ("fecha_nacimiento", "documento", "edad"):
        assert clave not in r.json()


def _pendiente(client, cabecera):
    """Simula una cuenta anterior a 7C (sin declaración), como deja la migración 0005."""
    with client.app.state.fabrica_sesiones() as db:
        db.execute(update(Usuario).values(mayoria_edad_declarada_en=None))
        db.commit()


def test_cuenta_pendiente_solo_consulta_y_confirma(client, auth, admin):
    _pendiente(client, auth)

    assert client.get("/health").status_code == 200
    me = client.get("/auth/me", headers=auth)
    assert me.status_code == 200 and me.json()["edad_confirmada"] is False
    for ruta in ("/debates", "/debates/1", "/estadisticas/mias", "/mis-debates", "/borradores"):
        r = client.get(ruta, headers=auth)
        assert r.status_code == 403 and r.json()["detail"]["codigo"] == "edad_no_confirmada"
    # También las cuentas administradoras quedan pendientes.
    r = client.get("/admin/solicitudes-archivo", headers=admin)
    assert r.status_code == 403 and r.json()["detail"]["codigo"] == "edad_no_confirmada"
    # Iniciar sesión sigue funcionando para poder confirmar.
    login = client.post("/auth/login", json={"email": "ana@example.com", "password": PASSWORD})
    assert login.status_code == 200


def test_confirmar_edad_es_explicito_e_idempotente(client, auth):
    _pendiente(client, auth)
    for cuerpo in ({}, {"confirma_mayoria_edad": False}, {"confirma_mayoria_edad": "true"},
                   {"confirma_mayoria_edad": True, "fecha_nacimiento": "2000-01-01"}):
        assert client.post("/auth/confirmar-edad", json=cuerpo, headers=auth).status_code == 422
    assert client.get("/debates", headers=auth).status_code == 403

    r = client.post("/auth/confirmar-edad", json={"confirma_mayoria_edad": True}, headers=auth)
    assert r.status_code == 200 and r.json()["edad_confirmada"] is True
    with client.app.state.fabrica_sesiones() as db:
        primera = db.get(Usuario, 1).mayoria_edad_declarada_en
    client.post("/auth/confirmar-edad", json={"confirma_mayoria_edad": True}, headers=auth)
    with client.app.state.fabrica_sesiones() as db:
        assert db.get(Usuario, 1).mayoria_edad_declarada_en == primera
    assert client.get("/debates", headers=auth).status_code == 200
    assert client.post("/auth/confirmar-edad", json={"confirma_mayoria_edad": True}).status_code == 401

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.main import create_app
from tests.conftest import PASSWORD

CAMPOS_APORTE = {
    "id",
    "debate_id",
    "tipo",
    "texto",
    "autor_nombre",
    "creado_en",
    "editado_en",
    "es_propio",
    "version",
}
TEXTO = "Propongo horarios acordados entre estudiantes y docentes."


@pytest.fixture
def ana(auth):
    return auth


@pytest.fixture
def beto(sesion_de):
    return sesion_de("beto@example.com", "Beto")


def _crear(client, cabecera, debate_id=1, tipo="propuesta", texto=TEXTO):
    return client.post(
        f"/debates/{debate_id}/aportes", json={"tipo": tipo, "texto": texto, "version": 1}, headers=cabecera
    )


def _aportes(client, cabecera, debate_id=1):
    return client.get(f"/debates/{debate_id}/aportes", headers=cabecera).json()


# --- Colaboración y autorización -----------------------------------------------------


def test_a_crea_y_b_ve_el_mismo_aporte(client, ana, beto):
    creado = _crear(client, ana)

    assert creado.status_code == 201
    cuerpo = creado.json()
    assert set(cuerpo) == CAMPOS_APORTE
    assert cuerpo["autor_nombre"] == "Ana"
    assert cuerpo["es_propio"] is True
    assert cuerpo["editado_en"] is None

    visto_por_b = _aportes(client, beto)
    assert [a["id"] for a in visto_por_b] == [cuerpo["id"]]
    assert visto_por_b[0]["texto"] == TEXTO
    assert visto_por_b[0]["autor_nombre"] == "Ana"
    assert visto_por_b[0]["es_propio"] is False


def test_b_no_puede_editar_ni_eliminar_el_aporte_de_a(client, ana, beto):
    aporte = _crear(client, ana).json()

    editar = client.patch(
        f"/aportes/{aporte['id']}", json={"texto": "Texto cambiado por otra persona."}, headers=beto
    )
    borrar = client.delete(f"/aportes/{aporte['id']}", headers=beto)

    assert editar.status_code == 403
    assert borrar.status_code == 403
    intacto = _aportes(client, ana)
    assert len(intacto) == 1
    assert intacto[0]["texto"] == TEXTO
    assert intacto[0]["editado_en"] is None


def test_a_edita_parcialmente_y_elimina_su_aporte(client, ana, beto):
    aporte = _crear(client, ana).json()

    solo_tipo = client.patch(f"/aportes/{aporte['id']}", json={"tipo": "argumento"}, headers=ana)
    assert solo_tipo.status_code == 200
    assert solo_tipo.json()["tipo"] == "argumento"
    assert solo_tipo.json()["texto"] == TEXTO
    assert solo_tipo.json()["editado_en"] is not None

    solo_texto = client.patch(
        f"/aportes/{aporte['id']}", json={"texto": "  Texto revisado por la autora.  "}, headers=ana
    )
    assert solo_texto.json()["texto"] == "Texto revisado por la autora."
    assert _aportes(client, beto)[0]["texto"] == "Texto revisado por la autora."

    borrar = client.delete(f"/aportes/{aporte['id']}", headers=ana)
    assert borrar.status_code == 204
    assert borrar.content == b""
    assert _aportes(client, beto) == []


def test_patch_sin_cambios_reales_no_marca_edicion(client, ana):
    aporte = _crear(client, ana).json()

    respuesta = client.patch(
        f"/aportes/{aporte['id']}", json={"tipo": "propuesta", "texto": TEXTO}, headers=ana
    )

    assert respuesta.status_code == 200
    assert respuesta.json()["editado_en"] is None


def test_el_autor_sale_del_token_y_no_del_cuerpo(client, ana, beto):
    for extra in ({"autor_id": 2}, {"debate_id": 2}, {"id": 99}, {"es_propio": True}):
        respuesta = client.post(
            "/debates/1/aportes", json={"tipo": "pregunta", "texto": TEXTO, "version": 1, **extra}, headers=ana
        )
        assert respuesta.status_code == 422, extra

    aporte = _crear(client, ana).json()
    for extra in ({"autor_id": 2}, {"debate_id": 3}):
        respuesta = client.patch(f"/aportes/{aporte['id']}", json=extra, headers=ana)
        assert respuesta.status_code == 422, extra
    assert _aportes(client, beto)[0]["autor_nombre"] == "Ana"
    assert _aportes(client, ana, debate_id=3) == []


# --- Autenticación y recursos inexistentes --------------------------------------------


@pytest.mark.parametrize("cabecera", [None, {"Authorization": "Bearer no.es.valido"}])
def test_sin_token_valido_todo_responde_401(client, ana, cabecera):
    aporte = _crear(client, ana).json()
    peticiones = [
        ("get", "/debates/1/aportes", None),
        ("post", "/debates/1/aportes", {"tipo": "pregunta", "texto": TEXTO, "version": 1}),
        ("patch", f"/aportes/{aporte['id']}", {"texto": "Otro texto suficiente."}),
        ("delete", f"/aportes/{aporte['id']}", None),
    ]
    for metodo, ruta, cuerpo in peticiones:
        opciones = {"headers": cabecera or {}}
        if cuerpo is not None:
            opciones["json"] = cuerpo
        assert client.request(metodo, ruta, **opciones).status_code == 401, (metodo, ruta)
    assert len(_aportes(client, ana)) == 1


def test_debate_o_aporte_inexistente_responde_404(client, ana):
    assert client.get("/debates/999/aportes", headers=ana).status_code == 404
    assert _crear(client, ana, debate_id=999).status_code == 404
    assert client.patch("/aportes/999", json={"tipo": "pregunta"}, headers=ana).status_code == 404
    assert client.delete("/aportes/999", headers=ana).status_code == 404


# --- Validación -----------------------------------------------------------------------


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"tipo": "opinion", "texto": TEXTO, "version": 1},
        {"tipo": "pregunta", "texto": "corto", "version": 1},
        {"tipo": "pregunta", "texto": "   nueve   ", "version": 1},  # 5 caracteres tras quitar espacios
        {"tipo": "pregunta", "texto": "x" * 1001, "version": 1},
        {"tipo": "pregunta", "version": 1},
        {"tipo": "pregunta", "texto": TEXTO},  # sin versión (7B.1)
        {"tipo": "pregunta", "texto": TEXTO, "version": 0},
        {"texto": TEXTO},
        {"tipo": None, "texto": TEXTO},
    ],
)
def test_post_invalido_responde_422(client, ana, cuerpo):
    assert client.post("/debates/1/aportes", json=cuerpo, headers=ana).status_code == 422


def test_limites_de_longitud_tras_quitar_espacios(client, ana):
    diez = _crear(client, ana, texto="   " + "a" * 10 + "   ")
    mil = _crear(client, ana, texto="b" * 1000)

    assert diez.status_code == 201
    assert diez.json()["texto"] == "a" * 10
    assert mil.status_code == 201


@pytest.mark.parametrize(
    "cuerpo",
    [{}, {"texto": None}, {"tipo": None}, {"texto": "corto"}, {"tipo": "otro"}, {"extra": 1}],
)
def test_patch_invalido_responde_422_y_no_cambia_nada(client, ana, cuerpo):
    aporte = _crear(client, ana).json()

    respuesta = client.patch(f"/aportes/{aporte['id']}", json=cuerpo, headers=ana)

    assert respuesta.status_code == 422
    assert _aportes(client, ana)[0]["texto"] == TEXTO


# --- Orden, privacidad y persistencia --------------------------------------------------


def test_orden_mas_recientes_primero_y_estable(client, ana, beto):
    ids = [_crear(client, ana if i % 2 else beto, texto=f"{TEXTO} {i}").json()["id"] for i in range(5)]

    primera = [a["id"] for a in _aportes(client, ana)]
    segunda = [a["id"] for a in _aportes(client, beto)]

    assert primera == list(reversed(ids))
    assert primera == segunda


def test_desempate_por_id_con_la_misma_fecha(client, ana):
    a = _crear(client, ana).json()["id"]
    b = _crear(client, ana).json()["id"]
    with client.app.state.fabrica_sesiones() as db:
        db.execute(text("UPDATE aportes SET creado_en = '2026-01-01 00:00:00.000000'"))
        db.commit()

    assert [x["id"] for x in _aportes(client, ana)] == [b, a]


def test_respuestas_sin_datos_privados(client, ana, beto):
    _crear(client, ana)

    for respuesta in (_crear(client, beto), client.get("/debates/1/aportes", headers=beto)):
        cuerpo = respuesta.text
        assert "example.com" not in cuerpo
        assert PASSWORD not in cuerpo
        assert "argon2" not in cuerpo
        assert "autor_id" not in cuerpo
        assert "Bearer" not in cuerpo


def test_aportes_persisten_al_reabrir_la_base(settings, client, ana):
    creado = _crear(client, ana).json()

    with TestClient(create_app(settings)) as reabierto:
        login = reabierto.post(
            "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
        ).json()
        cabecera = {"Authorization": f"Bearer {login['access_token']}"}
        aportes = reabierto.get("/debates/1/aportes", headers=cabecera).json()

    assert [a["id"] for a in aportes] == [creado["id"]]
    assert aportes[0]["es_propio"] is True


def test_claves_foraneas_rechazan_aportes_huerfanos(client):
    with client.app.state.fabrica_sesiones() as db:
        with pytest.raises(Exception, match="FOREIGN KEY"):
            db.execute(
                text(
                    "INSERT INTO aportes (debate_id, autor_id, tipo, texto, creado_en) "
                    "VALUES (999, 999, 'pregunta', 'texto huérfano', '2026-01-01')"
                )
            )
            db.commit()

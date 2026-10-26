import pytest
from sqlalchemy import text

from app.repositorios.estadisticas import LIMITE_RECIENTES, LIMITE_SIN_APORTES
from tests.conftest import PASSWORD

TEXTO = "Aporte de prueba con longitud suficiente."


@pytest.fixture
def ana(auth):
    return auth


@pytest.fixture
def beto(sesion_de):
    return sesion_de("beto@example.com", "Beto")


def _aportar(client, cabecera, debate_id, tipo="pregunta", texto=TEXTO):
    r = client.post(
        f"/debates/{debate_id}/aportes", json={"tipo": tipo, "texto": texto, "version": 1}, headers=cabecera
    )
    assert r.status_code == 201
    return r.json()


def _comunidad(client, cabecera):
    r = client.get("/estadisticas/comunidad", headers=cabecera)
    assert r.status_code == 200
    return r.json()


def _mias(client, cabecera):
    r = client.get("/estadisticas/mias", headers=cabecera)
    assert r.status_code == 200
    return r.json()


def _fijar_fechas(client, fechas: dict[int, str]):
    """Fija creado_en por id de aporte para probar el orden de forma determinista."""
    with client.app.state.fabrica_sesiones() as db:
        for aporte_id, fecha in fechas.items():
            db.execute(
                text("UPDATE aportes SET creado_en = :f WHERE id = :i"), {"f": fecha, "i": aporte_id}
            )
        db.commit()


# --- Autenticación y privacidad -----------------------------------------------------------


@pytest.mark.parametrize("ruta", ["/estadisticas/comunidad", "/estadisticas/mias"])
@pytest.mark.parametrize("cabecera", [{}, {"Authorization": "Bearer no.valido"}])
def test_requieren_token(client, ruta, cabecera):
    assert client.get(ruta, headers=cabecera).status_code == 401


def test_mias_ignora_identificadores_en_la_consulta(client, ana, beto):
    _aportar(client, beto, 1)

    r = client.get("/estadisticas/mias", params={"usuario_id": 2, "autor_id": 2}, headers=ana)

    assert r.status_code == 200
    assert r.json()["total_aportes"] == 0  # siempre la cuenta del token


def test_respuestas_sin_identidades_ni_datos_privados(client, ana, beto):
    _aportar(client, ana, 1)
    _aportar(client, beto, 2)

    for cuerpo in (
        client.get("/estadisticas/comunidad", headers=ana).text,
        client.get("/estadisticas/mias", headers=ana).text,
    ):
        for prohibido in ("example.com", "Beto", "Ana", "autor", PASSWORD, "Bearer", "argon2"):
            assert prohibido not in cuerpo


# --- Datos vacíos ------------------------------------------------------------------------


def test_sin_aportes(client, ana):
    comunidad = _comunidad(client, ana)
    mias = _mias(client, ana)

    assert comunidad["total_debates"] == 20
    assert sum(c["total"] for c in comunidad["por_categoria"]) == 20
    assert len(comunidad["por_categoria"]) == 8
    assert comunidad["total_aportes"] == 0
    assert comunidad["participantes"] == 0
    assert comunidad["sin_aportes"]["total"] == 20
    assert comunidad["actividad_reciente"] == []
    assert mias == {
        "total_aportes": 0,
        "por_tipo": {"pregunta": 0, "argumento": 0, "propuesta": 0},
        "debates_participados": 0,
        "aportes_recientes": [],
        "mis_debates": {"borradores": 0, "publicados": 0, "archivados": 0},
    }
    assert comunidad["debates_archivados"] == 0


# --- Recuentos exactos -------------------------------------------------------------------


def test_recuentos_con_dos_cuentas_y_varios_debates(client, ana, beto, registrar):
    registrar(email="carla@example.com", nombre="Carla")  # cuenta sin aportes
    # Ana: 3 aportes en el debate 1 (cuenta una vez) y 1 en el debate 2.
    _aportar(client, ana, 1, "pregunta")
    _aportar(client, ana, 1, "argumento")
    _aportar(client, ana, 1, "argumento")
    _aportar(client, ana, 2, "propuesta")
    # Beto: 1 aporte en el debate 2 y 1 en el debate 3.
    _aportar(client, beto, 2, "pregunta")
    _aportar(client, beto, 3, "argumento")

    comunidad = _comunidad(client, ana)
    assert comunidad["total_aportes"] == 6
    assert comunidad["participantes"] == 2  # 3 cuentas registradas, 2 con aportes
    assert comunidad["sin_aportes"]["total"] == 17
    assert {d["debate"]["id"]: d["aportes"] for d in comunidad["actividad_reciente"]} == {
        1: 3,
        2: 2,
        3: 1,
    }

    mias_ana = _mias(client, ana)
    assert mias_ana["total_aportes"] == 4
    assert mias_ana["por_tipo"] == {"pregunta": 1, "argumento": 2, "propuesta": 1}
    assert mias_ana["debates_participados"] == 2

    mias_beto = _mias(client, beto)
    assert mias_beto["total_aportes"] == 2
    assert mias_beto["por_tipo"] == {"pregunta": 1, "argumento": 1, "propuesta": 0}
    assert mias_beto["debates_participados"] == 2
    assert {a["debate"]["id"] for a in mias_beto["aportes_recientes"]} == {2, 3}


def test_las_cifras_bajan_al_eliminar_un_aporte(client, ana):
    aporte = _aportar(client, ana, 1)
    assert _comunidad(client, ana)["total_aportes"] == 1

    client.delete(f"/aportes/{aporte['id']}", headers=ana)

    comunidad = _comunidad(client, ana)
    assert comunidad["total_aportes"] == 0
    assert comunidad["participantes"] == 0
    assert comunidad["sin_aportes"]["total"] == 20
    assert _mias(client, ana)["debates_participados"] == 0


# --- Orden y límites ---------------------------------------------------------------------


def test_actividad_reciente_por_ultimo_aporte_y_limite(client, ana):
    ids = {d: _aportar(client, ana, d)["id"] for d in range(1, 8)}
    fechas = {ids[d]: f"2026-10-0{d} 10:00:00.000000" for d in range(1, 8)}
    fechas[ids[2]] = "2026-10-09 10:00:00.000000"  # el debate 2 pasa a ser el más reciente
    _fijar_fechas(client, fechas)

    actividad = _comunidad(client, ana)["actividad_reciente"]

    assert len(actividad) == LIMITE_RECIENTES
    assert [a["debate"]["id"] for a in actividad] == [2, 7, 6, 5, 4]


def test_empate_de_fechas_se_resuelve_por_id(client, ana):
    a = _aportar(client, ana, 4)["id"]
    b = _aportar(client, ana, 9)["id"]
    _fijar_fechas(client, {a: "2026-10-01 10:00:00.000000", b: "2026-10-01 10:00:00.000000"})

    actividad = _comunidad(client, ana)["actividad_reciente"]
    recientes = _mias(client, ana)["aportes_recientes"]

    assert [x["debate"]["id"] for x in actividad] == [9, 4]
    assert [x["id"] for x in recientes] == [b, a]


def test_sin_aportes_en_orden_del_catalogo_con_limite(client, ana):
    _aportar(client, ana, 1)

    sin = _comunidad(client, ana)["sin_aportes"]

    assert sin["total"] == 19
    assert [d["id"] for d in sin["debates"]] == list(range(2, 2 + LIMITE_SIN_APORTES))
    assert set(sin["debates"][0]) == {"id", "titulo", "categoria"}


def test_mis_aportes_recientes_orden_limite_y_debate(client, ana):
    ids = [_aportar(client, ana, (i % 3) + 1, texto=f"{TEXTO} {i}")["id"] for i in range(7)]

    recientes = _mias(client, ana)["aportes_recientes"]

    assert len(recientes) == LIMITE_RECIENTES
    assert [r["id"] for r in recientes] == list(reversed(ids))[:LIMITE_RECIENTES]
    primero = recientes[0]
    assert set(primero) == {"id", "tipo", "texto", "creado_en", "editado_en", "debate"}
    assert primero["debate"]["id"] == (6 % 3) + 1
    assert primero["debate"]["titulo"]

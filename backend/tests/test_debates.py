import pytest

from app.models import ORIGEN_EDITORIAL, Categoria


@pytest.mark.parametrize("ruta", ["/debates", "/debates/categorias", "/debates/1"])
def test_catalogo_requiere_token(client, ruta):
    respuesta = client.get(ruta)

    assert respuesta.status_code == 401
    assert respuesta.headers["www-authenticate"] == "Bearer"


def test_lista_tiene_20_debates_en_orden_estable(client, auth):
    primera = client.get("/debates", headers=auth).json()
    segunda = client.get("/debates", headers=auth).json()

    assert len(primera) == 20
    assert [d["id"] for d in primera] == sorted(d["id"] for d in primera)
    assert primera == segunda
    assert all(d["origen"] == ORIGEN_EDITORIAL for d in primera)
    assert set(primera[0]) == {
        "id", "titulo", "categoria", "resumen", "origen", "procedencia", "estado", "autor_nombre"
    }
    assert {d["procedencia"] for d in primera} == {"editorial"}
    assert {d["estado"] for d in primera} == {"publicado"}


def test_filtrar_por_categoria(client, auth):
    respuesta = client.get("/debates", params={"categoria": "movilidad"}, headers=auth)

    assert respuesta.status_code == 200
    assert respuesta.json()
    assert {d["categoria"] for d in respuesta.json()} == {"movilidad"}


def test_categoria_invalida_responde_422(client, auth):
    respuesta = client.get("/debates", params={"categoria": "deportes"}, headers=auth)

    assert respuesta.status_code == 422


def test_categorias_en_orden_fijo_con_totales(client, auth):
    categorias = client.get("/debates/categorias", headers=auth).json()

    assert [c["categoria"] for c in categorias] == [c.value for c in Categoria]
    assert sum(c["total"] for c in categorias) == 20
    assert all(c["etiqueta"] for c in categorias)


def test_detalle_incluye_contexto_y_perspectivas(client, auth):
    debate_id = client.get("/debates", headers=auth).json()[0]["id"]

    respuesta = client.get(f"/debates/{debate_id}", headers=auth)

    assert respuesta.status_code == 200
    detalle = respuesta.json()
    assert detalle["contexto"]
    assert len(detalle["perspectivas"]) >= 2
    assert detalle["origen"] == ORIGEN_EDITORIAL


def test_detalle_inexistente_responde_404(client, auth):
    respuesta = client.get("/debates/99999", headers=auth)

    assert respuesta.status_code == 404
    assert respuesta.json()["detail"] == "Debate no encontrado."


def test_detalle_con_id_no_numerico_responde_422(client, auth):
    assert client.get("/debates/abc", headers=auth).status_code == 422

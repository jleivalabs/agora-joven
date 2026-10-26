"""Bloque 7B: borradores privados, publicación, edición, archivo y efectos en catálogo y cifras."""

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.models import ORIGEN_USUARIO
from tests.conftest import PASSWORD

CONTENIDO = {
    "categoria": "movilidad",
    "ambito": "Estudiantes de la ciudad",
    "titulo": "¿Debería ampliarse el horario del bus universitario?",
    "resumen": "Quienes estudian de noche tienen pocas opciones para volver a casa con seguridad.",
    "contexto": (
        "El servicio termina antes que algunas clases nocturnas. Hay quienes caminan largas "
        "distancias o pagan transporte privado. Se discute si ampliar el horario compensa su costo."
    ),
    "perspectivas": [
        {"titulo": "Ampliar el horario", "descripcion": "Mejora la seguridad de quienes estudian de noche."},
        {"titulo": "Mantenerlo", "descripcion": "Los recursos podrían usarse en otras rutas diurnas."},
    ],
    "objetivo": "Aclarar si conviene ampliar el horario y con qué condiciones.",
}


@pytest.fixture
def ana(auth):
    return auth


@pytest.fixture
def beto(sesion_de):
    return sesion_de("beto@example.com", "Beto")


def _crear(client, cabecera, cuerpo=None):
    r = client.post("/borradores", json=cuerpo or {}, headers=cabecera)
    assert r.status_code == 201, r.text
    return r.json()


def _publicado(client, cabecera, **cambios):
    borrador = _crear(client, cabecera, {**CONTENIDO, **cambios})
    r = client.post(f"/borradores/{borrador['id']}/publicar", headers=cabecera)
    assert r.status_code == 201, r.text
    return borrador, r.json()


def _catalogo(client, cabecera):
    return client.get("/debates", headers=cabecera).json()


# --- Borradores incompletos, guardado y recuperación -------------------------------------


def test_borrador_vacio_e_incompleto_se_guarda_y_se_recupera(client, ana):
    vacio = _crear(client, ana)
    assert vacio["titulo"] is None and vacio["paso"] == 1 and vacio["debate_id"] is None

    r = client.patch(
        f"/borradores/{vacio['id']}",
        json={"categoria": "salud", "titulo": "  Pregunta a medias  ", "paso": 3},
        headers=ana,
    )
    assert r.status_code == 200
    assert r.json()["titulo"] == "Pregunta a medias"

    recuperado = client.get(f"/borradores/{vacio['id']}", headers=ana).json()
    assert (recuperado["categoria"], recuperado["paso"]) == ("salud", 3)
    assert [b["id"] for b in client.get("/borradores", headers=ana).json()] == [vacio["id"]]


def test_null_vacia_un_campo(client, ana):
    b = _crear(client, ana, {"titulo": "Algo escrito"})
    r = client.patch(f"/borradores/{b['id']}", json={"titulo": None}, headers=ana)
    assert r.json()["titulo"] is None


def test_borrador_persiste_al_reabrir(settings, client, ana):
    b = _crear(client, ana, {"ambito": "Barrio norte", "paso": 2})

    with TestClient(create_app(settings)) as reabierto:
        token = reabierto.post(
            "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
        ).json()["access_token"]
        recuperado = reabierto.get(
            f"/borradores/{b['id']}", headers={"Authorization": f"Bearer {token}"}
        ).json()
    assert (recuperado["ambito"], recuperado["paso"]) == ("Barrio norte", 2)


@pytest.mark.parametrize(
    "cuerpo",
    [
        {"autor_id": 2},
        {"debate_id": 1},
        {"estado": "publicado"},
        {"procedencia": "editorial"},
        {"categoria": "deportes"},
        {"paso": 7},
        {"titulo": "x" * 161},
        {"perspectivas": [{"titulo": "a", "descripcion": "b"}] * 6},
    ],
)
def test_campos_internos_o_fuera_de_limites_se_rechazan(client, ana, cuerpo):
    assert client.post("/borradores", json=cuerpo, headers=ana).status_code == 422


# --- Aislamiento entre cuentas -------------------------------------------------------------


def test_nadie_lista_lee_ni_modifica_borradores_ajenos(client, ana, beto):
    b = _crear(client, ana, {"titulo": "Borrador privado de Ana"})
    ruta = f"/borradores/{b['id']}"

    assert client.get("/borradores", headers=beto).json() == []
    assert client.get(ruta, headers=beto).status_code == 404
    assert client.patch(ruta, json={"titulo": "Cambio ajeno"}, headers=beto).status_code == 404
    assert client.delete(ruta, headers=beto).status_code == 404
    assert client.post(f"{ruta}/publicar", headers=beto).status_code == 404
    assert client.get("/mis-debates", headers=beto).json()["borradores"] == []
    assert client.get(ruta, headers=ana).json()["titulo"] == "Borrador privado de Ana"


@pytest.mark.parametrize(
    "metodo,ruta",
    [("get", "/borradores"), ("post", "/borradores"), ("get", "/mis-debates")],
)
def test_requieren_token(client, metodo, ruta):
    assert client.request(metodo, ruta, json={}).status_code == 401


def test_eliminar_borrador_propio(client, ana):
    b = _crear(client, ana)
    assert client.delete(f"/borradores/{b['id']}", headers=ana).status_code == 204
    assert client.get(f"/borradores/{b['id']}", headers=ana).status_code == 404


# --- Publicación ---------------------------------------------------------------------------


def test_publicar_incompleto_indica_los_campos(client, ana):
    b = _crear(client, ana, {"categoria": "salud", "titulo": "Corto"})

    r = client.post(f"/borradores/{b['id']}/publicar", headers=ana)

    assert r.status_code == 422
    campos = {e["loc"][-1] if e["loc"][-1] != 0 else e["loc"][-2] for e in r.json()["detail"]}
    assert {"ambito", "titulo", "resumen", "contexto", "perspectivas", "objetivo"} <= campos
    assert len(_catalogo(client, ana)) == 20


@pytest.mark.parametrize(
    "cambio",
    [
        {"perspectivas": CONTENIDO["perspectivas"][:1]},
        {"perspectivas": [CONTENIDO["perspectivas"][0]] * 2},  # títulos repetidos
        {"objetivo": "Corto"},
    ],
)
def test_publicar_invalido(client, ana, cambio):
    b = _crear(client, ana, {**CONTENIDO, **cambio})
    assert client.post(f"/borradores/{b['id']}/publicar", headers=ana).status_code == 422


def test_publicar_valido_y_repetido_sin_duplicar(client, ana, beto):
    borrador, debate = _publicado(client, ana)

    assert debate["procedencia"] == "usuario"
    assert debate["estado"] == "publicado"
    assert debate["autor_nombre"] == "Ana"
    assert debate["origen"] == ORIGEN_USUARIO
    repetido = client.post(f"/borradores/{borrador['id']}/publicar", headers=ana)
    assert repetido.status_code == 200
    assert repetido.json()["id"] == debate["id"]

    catalogo = _catalogo(client, beto)
    assert len(catalogo) == 21
    assert sum(d["id"] == debate["id"] for d in catalogo) == 1
    assert client.get("/borradores", headers=ana).json() == []  # ya no es un borrador pendiente
    assert client.patch(
        f"/borradores/{borrador['id']}", json={"titulo": "x"}, headers=ana
    ).status_code == 409
    assert client.delete(f"/borradores/{borrador['id']}", headers=ana).status_code == 409


def test_detalle_de_debate_de_usuario_sin_correo(client, ana, beto):
    _, debate = _publicado(client, ana)

    r = client.get(f"/debates/{debate['id']}", headers=beto)

    detalle = r.json()
    assert detalle["autor_nombre"] == "Ana"
    assert detalle["ambito"] == CONTENIDO["ambito"]
    assert detalle["objetivo"] == CONTENIDO["objetivo"]
    assert detalle["es_propio"] is False and detalle["editable"] is False
    assert "example.com" not in r.text
    assert client.get(f"/debates/{debate['id']}", headers=ana).json()["editable"] is True


def test_otras_cuentas_aportan_y_la_autora_no_controla_aportes_ajenos(client, ana, beto):
    _, debate = _publicado(client, ana)
    aporte = client.post(
        f"/debates/{debate['id']}/aportes",
        json={"tipo": "pregunta", "texto": "¿Cuánto costaría ampliar el horario?"},
        headers=beto,
    ).json()

    assert client.patch(
        f"/aportes/{aporte['id']}", json={"texto": "Texto cambiado por la autora."}, headers=ana
    ).status_code == 403
    assert client.delete(f"/aportes/{aporte['id']}", headers=ana).status_code == 403


# --- Edición --------------------------------------------------------------------------------


def test_editar_propio_sin_aportes_y_bloqueo_con_aportes(client, ana, beto):
    _, debate = _publicado(client, ana)
    ruta = f"/debates/{debate['id']}"
    nuevo = {**CONTENIDO, "titulo": "¿Debería ampliarse el horario del bus en época de exámenes?"}

    assert client.put(ruta, json=nuevo, headers=beto).status_code == 403
    r = client.put(ruta, json=nuevo, headers=ana)
    assert r.status_code == 200
    assert r.json()["titulo"] == nuevo["titulo"]

    client.post(
        f"{ruta}/aportes", json={"tipo": "argumento", "texto": "Ya hay un aporte aquí."}, headers=beto
    )
    bloqueado = client.put(ruta, json=CONTENIDO, headers=ana)
    assert bloqueado.status_code == 409
    assert "bloqueado" in bloqueado.json()["detail"]
    assert client.get(ruta, headers=ana).json()["titulo"] == nuevo["titulo"]


def test_edicion_rechaza_campos_internos_e_invalidos(client, ana):
    _, debate = _publicado(client, ana)
    ruta = f"/debates/{debate['id']}"
    for extra in ({"autor_id": 2}, {"estado": "archivado"}, {"procedencia": "editorial"}):
        assert client.put(ruta, json={**CONTENIDO, **extra}, headers=ana).status_code == 422
    assert client.put(ruta, json={**CONTENIDO, "resumen": "corto"}, headers=ana).status_code == 422


def test_nadie_edita_ni_archiva_debates_editoriales(client, ana):
    assert client.put("/debates/1", json=CONTENIDO, headers=ana).status_code == 403
    motivo = {"motivo": "Motivo suficientemente largo."}
    assert client.post("/debates/1/archivar", json=motivo, headers=ana).status_code == 403
    assert client.put("/debates/999", json=CONTENIDO, headers=ana).status_code == 404


# --- Archivo --------------------------------------------------------------------------------


def test_archivar_conserva_contenido_y_bloquea_cambios(client, ana, beto, admin):
    _, debate = _publicado(client, ana)
    ruta = f"/debates/{debate['id']}"
    aporte = client.post(
        f"{ruta}/aportes", json={"tipo": "propuesta", "texto": "Propuesta antes del archivo."},
        headers=beto,
    ).json()

    motivo = {"motivo": "Contenido duplicado de otro debate."}
    # Ni una cuenta ajena ni la autora pueden archivar directamente (política de revisión).
    assert client.post(f"{ruta}/archivar", json=motivo, headers=beto).status_code == 403
    assert client.post(f"{ruta}/archivar", json=motivo, headers=ana).status_code == 403
    r = client.post(f"{ruta}/archivar", json=motivo, headers=admin)
    assert r.status_code == 200
    assert r.json()["estado"] == "archivado" and r.json()["archivado_en"]
    assert r.json()["archivo_origen"] == "administracion"
    assert client.post(f"{ruta}/archivar", json=motivo, headers=admin).status_code == 409

    # Sigue consultable (por ejemplo, desde Guardados) con sus aportes.
    detalle = client.get(ruta, headers=beto).json()
    assert detalle["estado"] == "archivado" and detalle["titulo"] == CONTENIDO["titulo"]
    assert [a["id"] for a in client.get(f"{ruta}/aportes", headers=beto).json()] == [aporte["id"]]
    # Sin cambios nuevos.
    nuevo = {"tipo": "pregunta", "texto": "Aporte después del archivo."}
    assert client.post(f"{ruta}/aportes", json=nuevo, headers=beto).status_code == 409
    assert client.patch(
        f"/aportes/{aporte['id']}", json={"texto": "Edición tras el archivo."}, headers=beto
    ).status_code == 409
    assert client.delete(f"/aportes/{aporte['id']}", headers=beto).status_code == 409
    assert client.put(ruta, json=CONTENIDO, headers=ana).status_code == 409
    # Fuera del catálogo.
    assert debate["id"] not in [d["id"] for d in _catalogo(client, beto)]


# --- Catálogo y estadísticas ----------------------------------------------------------------


def test_borradores_fuera_del_catalogo_y_de_las_cifras(client, ana, beto):
    _crear(client, ana, {**CONTENIDO, "titulo": "Borrador secreto que no debe filtrarse"})

    textos = [
        client.get("/debates", headers=beto).text,
        client.get("/debates/categorias", headers=beto).text,
        client.get("/estadisticas/comunidad", headers=beto).text,
        client.get("/estadisticas/mias", headers=beto).text,
    ]
    assert all("Borrador secreto" not in t for t in textos)
    comunidad = client.get("/estadisticas/comunidad", headers=beto).json()
    assert comunidad["total_debates"] == 20
    assert sum(c["total"] for c in comunidad["por_categoria"]) == 20
    assert client.get("/estadisticas/mias", headers=ana).json()["mis_debates"] == {
        "borradores": 1,
        "publicados": 0,
        "archivados": 0,
    }


def test_cifras_tras_publicar_y_archivar(client, ana, beto, admin):
    _, debate = _publicado(client, ana)
    client.post(
        f"/debates/{debate['id']}/aportes",
        json={"tipo": "pregunta", "texto": "Aporte en el debate de Ana."},
        headers=beto,
    )
    comunidad = client.get("/estadisticas/comunidad", headers=beto).json()
    movilidad = {c["categoria"]: c["total"] for c in comunidad["por_categoria"]}["movilidad"]
    assert comunidad["total_debates"] == 21

    r = client.post(
        f"/debates/{debate['id']}/archivar", json={"motivo": "Archivo de prueba."}, headers=admin
    )
    assert r.status_code == 200

    despues = client.get("/estadisticas/comunidad", headers=beto).json()
    assert despues["total_debates"] == 20
    assert despues["debates_archivados"] == 1
    assert {c["categoria"]: c["total"] for c in despues["por_categoria"]}["movilidad"] == movilidad - 1
    assert despues["total_aportes"] == 1  # los aportes del archivado se conservan
    assert debate["id"] not in [a["debate"]["id"] for a in despues["actividad_reciente"]]
    assert debate["id"] not in [d["id"] for d in despues["sin_aportes"]["debates"]]
    mis = client.get("/mis-debates", headers=ana).json()
    assert [d["id"] for d in mis["archivados"]] == [debate["id"]]
    assert mis["publicados"] == [] and mis["archivados"][0]["aportes"] == 1
    assert client.get("/estadisticas/mias", headers=ana).json()["mis_debates"] == {
        "borradores": 0,
        "publicados": 0,
        "archivados": 1,
    }

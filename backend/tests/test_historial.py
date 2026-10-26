"""Bloque 7B.1: versiones publicadas, bloqueo permanente, aportes por versión y aclaraciones."""

import json
from concurrent.futures import ThreadPoolExecutor

import pytest
from sqlalchemy import func, select

from app.catalogo import ARCHIVO_CATALOGO, cargar_catalogo
from app.models import Debate, VersionDebate
from tests.test_borradores import CONTENIDO, MOTIVO_EDICION, _crear, _publicado

MOTIVO = {"motivo": "Archivo de prueba de la administración."}


@pytest.fixture
def ana(auth):
    return auth


@pytest.fixture
def beto(sesion_de):
    return sesion_de("beto@example.com", "Beto")


def _editar(client, cabecera, debate_id, **cambios):
    cuerpo = {**CONTENIDO, "motivo": MOTIVO_EDICION, **cambios}
    return client.put(f"/debates/{debate_id}", json=cuerpo, headers=cabecera)


def _aportar(client, cabecera, debate_id, version, texto="Aporte con texto suficiente."):
    return client.post(
        f"/debates/{debate_id}/aportes",
        json={"tipo": "argumento", "texto": texto, "version": version},
        headers=cabecera,
    )


def _versiones(client, cabecera, debate_id):
    return client.get(f"/debates/{debate_id}/versiones", headers=cabecera).json()


def _filas_versiones(client):
    with client.app.state.fabrica_sesiones() as db:
        return db.scalar(select(func.count()).select_from(VersionDebate))


# --- Versiones --------------------------------------------------------------------------------


def test_publicar_crea_la_version_1_y_los_borradores_no_crean_versiones(client, ana, beto):
    antes = _filas_versiones(client)
    borrador = _crear(client, ana, {"titulo": "Pregunta en borrador nunca publicada"})
    for i in range(3):
        client.patch(f"/borradores/{borrador['id']}", json={"ambito": f"Ámbito {i}"}, headers=ana)
    assert _filas_versiones(client) == antes  # guardar un borrador no crea versiones

    _, debate = _publicado(client, ana)
    versiones = _versiones(client, beto, debate["id"])
    assert len(versiones) == 1
    v1 = versiones[0]
    assert v1["numero"] == 1 and v1["tipo"] == "publicacion" and v1["es_actual"]
    assert v1["autor_nombre"] == "Ana" and v1["motivo"] is None and v1["campos_cambiados"] == []
    detalle = client.get(f"/debates/{debate['id']}", headers=ana).json()
    assert detalle["version_actual"] == 1 and detalle["editable"] is True
    assert detalle["motivo_bloqueo"] is None
    # El borrador nunca publicado no aparece en ningún historial ni catálogo.
    assert "nunca publicada" not in client.get("/debates", headers=beto).text


def test_edicion_valida_crea_version_con_motivo_y_diferencias(client, ana, beto):
    _, debate = _publicado(client, ana)
    nuevo_titulo = "¿Debería ampliarse el horario del bus en época de exámenes?"

    r = _editar(client, ana, debate["id"], titulo=nuevo_titulo)
    assert r.status_code == 200 and r.json()["version_actual"] == 2

    versiones = _versiones(client, beto, debate["id"])
    assert [v["numero"] for v in versiones] == [2, 1]
    v2 = versiones[0]
    assert v2["tipo"] == "edicion" and v2["motivo"] == MOTIVO_EDICION and v2["autor_nombre"] == "Ana"
    assert v2["campos_cambiados"] == ["titulo"] and v2["es_actual"]
    assert versiones[1]["es_actual"] is False

    detalle = client.get(f"/debates/{debate['id']}/versiones/2", headers=beto).json()
    assert detalle["cambios"] == [
        {"campo": "titulo", "antes": CONTENIDO["titulo"], "despues": nuevo_titulo}
    ]
    original = client.get(f"/debates/{debate['id']}/versiones/1", headers=beto).json()
    assert original["titulo"] == CONTENIDO["titulo"] and original["cambios"] == []
    assert original["perspectivas"] == CONTENIDO["perspectivas"]
    assert original["ambito"] == CONTENIDO["ambito"] and original["objetivo"] == CONTENIDO["objetivo"]


def test_motivo_obligatorio_y_guardar_sin_cambios_no_crea_version(client, ana):
    _, debate = _publicado(client, ana)
    ruta = f"/debates/{debate['id']}"
    assert client.put(ruta, json=CONTENIDO, headers=ana).status_code == 422
    assert _editar(client, ana, debate["id"], motivo="corto").status_code == 422

    r = _editar(client, ana, debate["id"])  # mismo contenido que la versión 1
    assert r.status_code == 200 and r.json()["version_actual"] == 1
    assert len(_versiones(client, ana, debate["id"])) == 1
    # Espacios exteriores se normalizan: tampoco cuenta como cambio.
    assert _editar(client, ana, debate["id"], titulo=f"  {CONTENIDO['titulo']}  ").json()[
        "version_actual"
    ] == 1


def test_historial_inmutable_y_permisos(client, ana, beto, admin):
    _, debate = _publicado(client, ana)
    _editar(client, ana, debate["id"], resumen="Un resumen distinto con longitud suficiente.")
    ruta = f"/debates/{debate['id']}/versiones"
    v1 = client.get(f"{ruta}/1", headers=ana).json()

    # Nadie más reescribe el contenido: ni otra cuenta ni la administración.
    assert _editar(client, beto, debate["id"], titulo="Título ajeno con longitud").status_code == 403
    assert _editar(client, admin, debate["id"], titulo="Título de la administración").status_code == 403
    # No hay rutas para modificar o borrar versiones.
    for metodo in ("put", "patch", "delete"):
        assert client.request(metodo, f"{ruta}/1", headers=ana).status_code == 405
    assert client.get(f"{ruta}/1", headers=ana).json() == v1
    # Consultable por cualquier cuenta autenticada; nunca sin sesión.
    assert client.get(ruta, headers=beto).status_code == 200
    assert client.get(ruta).status_code == 401
    assert client.get(f"{ruta}/9", headers=beto).status_code == 404
    assert client.get("/debates/9999/versiones", headers=beto).status_code == 404


def test_archivar_no_altera_el_historial(client, ana, admin):
    _, debate = _publicado(client, ana)
    antes = _versiones(client, ana, debate["id"])
    client.post(f"/debates/{debate['id']}/archivar", json=MOTIVO, headers=admin)
    despues = _versiones(client, ana, debate["id"])
    assert [(v["numero"], v["creada_en"]) for v in despues] == [
        (v["numero"], v["creada_en"]) for v in antes
    ]
    assert all(v["es_actual"] == w["es_actual"] for v, w in zip(antes, despues))


# --- Bloqueo permanente tras participación -------------------------------------------------


def test_bloqueo_permanente_incluso_si_se_eliminan_los_aportes(client, ana, beto):
    _, debate = _publicado(client, ana)
    aporte = _aportar(client, beto, debate["id"], 1).json()
    assert _editar(client, ana, debate["id"], titulo="Intento de cambio con aportes").status_code == 409

    assert client.delete(f"/aportes/{aporte['id']}", headers=beto).status_code == 204
    r = _editar(client, ana, debate["id"], titulo="Intento de cambio sin aportes")
    assert r.status_code == 409 and "permanente" in r.json()["detail"]
    detalle = client.get(f"/debates/{debate['id']}", headers=ana).json()
    assert detalle["editable"] is False and detalle["motivo_bloqueo"] == "participacion"
    assert detalle["aportes"] == 0 and detalle["version_actual"] == 1
    mis = client.get("/mis-debates", headers=ana).json()["publicados"]
    assert mis[0]["editable"] is False


# --- Aportes vinculados a una versión -----------------------------------------------------


def test_aportar_sobre_version_desactualizada_es_un_conflicto_controlado(client, ana, beto):
    _, debate = _publicado(client, ana)
    _editar(client, ana, debate["id"], titulo="¿Debería ampliarse el horario durante exámenes?")

    r = _aportar(client, beto, debate["id"], 1)  # beto redactaba sobre la versión 1
    assert r.status_code == 409
    assert r.json()["detail"]["codigo"] == "version_desactualizada"
    assert r.json()["detail"]["version_actual"] == 2
    assert client.get(f"/debates/{debate['id']}/aportes", headers=beto).json() == []
    # Sin participación registrada: el conflicto no bloquea al autor.
    assert client.get(f"/debates/{debate['id']}", headers=ana).json()["editable"] is True

    assert _aportar(client, beto, debate["id"], 99).status_code == 422  # no es del debate
    ok = _aportar(client, beto, debate["id"], 2)
    assert ok.status_code == 201 and ok.json()["version"] == 2


def test_editar_un_aporte_no_cambia_su_version(client, ana, beto):
    _, debate = _publicado(client, ana)
    aporte = _aportar(client, beto, debate["id"], 1).json()
    r = client.patch(
        f"/aportes/{aporte['id']}", json={"texto": "Texto corregido y más claro."}, headers=beto
    )
    assert r.status_code == 200 and r.json()["version"] == 1
    assert client.get(f"/debates/{debate['id']}/aportes", headers=ana).json()[0]["version"] == 1


def test_carreras_entre_edicion_y_aporte_dan_resultados_coherentes(client, ana, beto):
    """Edición y aporte simultáneos sobre la versión 1: nunca ganan los dos."""
    resultados = set()
    for i in range(8):
        _, debate = _publicado(client, ana)
        d = debate["id"]
        with ThreadPoolExecutor(max_workers=2) as hilos:
            edicion = hilos.submit(_editar, client, ana, d, titulo=f"¿Pregunta reformulada número {i}?")
            aporte = hilos.submit(_aportar, client, beto, d, 1)
            e, a = edicion.result().status_code, aporte.result().status_code
        assert (e, a) in {(200, 409), (409, 201)}, (e, a)
        resultados.add((e, a))
        detalle = client.get(f"/debates/{d}", headers=ana).json()
        if a == 201:  # ganó el aporte: contenido intacto y protegido para siempre
            assert detalle["version_actual"] == 1 and detalle["motivo_bloqueo"] == "participacion"
            assert client.get(f"/debates/{d}/aportes", headers=ana).json()[0]["version"] == 1
        else:  # ganó la edición: el aporte no se publicó contra la versión nueva
            assert detalle["version_actual"] == 2 and detalle["aportes"] == 0
    assert resultados  # al menos se ejerció un orden


# --- Aclaraciones -------------------------------------------------------------------------


def test_aclaraciones_del_autor_sin_tocar_el_contenido(client, ana, beto, admin):
    _, debate = _publicado(client, ana)
    _aportar(client, beto, debate["id"], 1)  # también con el contenido bloqueado
    ruta = f"/debates/{debate['id']}/aclaraciones"

    r = client.post(ruta, json={"texto": "El horario se refiere a días lectivos."}, headers=ana)
    assert r.status_code == 201 and r.json()["autor_nombre"] == "Ana" and r.json()["creada_en"]
    client.post(ruta, json={"texto": "Rectifico: también incluye sábados."}, headers=ana)

    for cabecera in (beto, admin):
        assert client.post(ruta, json={"texto": "Aclaración ajena al debate."}, headers=cabecera).status_code == 403
    for cuerpo in ({"texto": "corta"}, {"texto": "x" * 1001}, {}, {"texto": "Texto válido aquí.", "autor_id": 2}):
        assert client.post(ruta, json=cuerpo, headers=ana).status_code == 422
    assert client.post("/debates/1/aclaraciones", json={"texto": "Aclaración sobre editorial."}, headers=ana).status_code == 403
    assert client.post("/debates/9999/aclaraciones", json={"texto": "Debate que no existe."}, headers=ana).status_code == 404

    detalle = client.get(f"/debates/{debate['id']}", headers=beto).json()
    assert [a["texto"] for a in detalle["aclaraciones"]] == [
        "El horario se refiere a días lectivos.", "Rectifico: también incluye sábados."
    ]
    assert detalle["titulo"] == CONTENIDO["titulo"] and detalle["version_actual"] == 1
    assert len(_versiones(client, ana, debate["id"])) == 1
    aclaracion_id = r.json()["id"]
    for metodo in ("put", "patch", "delete"):
        assert client.request(metodo, f"{ruta}/{aclaracion_id}", headers=ana).status_code in (404, 405)


def test_debate_archivado_de_solo_lectura(client, ana, beto, admin):
    _, debate = _publicado(client, ana)
    client.post(f"/debates/{debate['id']}/archivar", json=MOTIVO, headers=admin)
    r = client.post(
        f"/debates/{debate['id']}/aclaraciones", json={"texto": "Aclaración tardía."}, headers=ana
    )
    assert r.status_code == 409
    assert _editar(client, ana, debate["id"], titulo="Cambio tras el archivo").status_code == 409
    assert _aportar(client, beto, debate["id"], 1).status_code == 409
    assert client.get(f"/debates/{debate['id']}/versiones", headers=beto).status_code == 200


# --- Semilla editorial --------------------------------------------------------------------


def test_la_semilla_no_reescribe_contenido_protegido_y_versiona_los_cambios(client, ana, tmp_path):
    datos = json.loads(ARCHIVO_CATALOGO.read_text(encoding="utf-8"))
    datos[0]["resumen"] = datos[0]["resumen"] + " Con una precisión editorial nueva."
    datos[1]["resumen"] = datos[1]["resumen"] + " Con otra precisión editorial nueva."
    archivo = tmp_path / "debates.json"
    archivo.write_text(json.dumps(datos, ensure_ascii=False), encoding="utf-8")
    assert _aportar(client, ana, 2, 1).status_code == 201  # el debate 2 recibe participación

    with client.app.state.fabrica_sesiones() as db:
        r = cargar_catalogo(db, archivo)
        assert (r.insertados, r.actualizados, r.protegidos) == (0, 1, 1)
        d1, d2 = db.get(Debate, 1), db.get(Debate, 2)
        assert d1.version_actual == 2 and d1.resumen == datos[0]["resumen"]
        assert d2.version_actual == 1 and d2.resumen != datos[1]["resumen"]
        # Segunda ejecución: idempotente.
        r = cargar_catalogo(db, archivo)
        assert (r.insertados, r.actualizados, r.protegidos) == (0, 0, 1)
    versiones = _versiones(client, ana, 1)
    assert [(v["numero"], v["tipo"]) for v in versiones] == [(2, "catalogo"), (1, "catalogo")]
    assert versiones[0]["campos_cambiados"] == ["resumen"]


def test_ordenes_deterministas_de_la_carrera(client, ana, beto):
    """Las dos intercalaciones posibles, forzadas con sesiones separadas del repositorio."""
    from app.repositorios import aportes as repo_aportes
    from app.repositorios import debates as repo_debates

    fabrica = client.app.state.fabrica_sesiones
    nuevo = {**CONTENIDO, "titulo": "¿Pregunta reformulada para la prueba?"}

    # 1) La edición se confirma primero: el aporte redactado sobre la versión 1 no se publica.
    _, d1 = _publicado(client, ana)
    with fabrica() as lectora, fabrica() as editora:
        assert lectora.get(Debate, d1["id"]).version_actual == 1  # lo que veía quien aporta
        assert repo_debates.editar_si_permitido(editora, d1["id"], 1, nuevo, MOTIVO_EDICION) == (
            repo_debates.ResultadoEdicion.editado
        )
        with pytest.raises(repo_aportes.VersionDesactualizada) as error:
            repo_aportes.crear(lectora, d1["id"], 2, "argumento", "Aporte sobre la versión 1.", 1)
        assert error.value.version_actual == 2

    # 2) El aporte se confirma primero: la edición, aunque se preparara antes, queda rechazada.
    _, d2 = _publicado(client, ana)
    with fabrica() as editora, fabrica() as aportante:
        assert editora.get(Debate, d2["id"]).con_participacion is False  # comprobación previa
        repo_aportes.crear(aportante, d2["id"], 2, "argumento", "Aporte que llega primero.", 1)
        assert repo_debates.editar_si_permitido(editora, d2["id"], 1, nuevo, MOTIVO_EDICION) == (
            repo_debates.ResultadoEdicion.rechazado
        )
    assert client.get(f"/debates/{d2['id']}", headers=ana).json()["titulo"] == CONTENIDO["titulo"]

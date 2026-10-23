import json

from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.catalogo import ARCHIVO_CATALOGO, cargar_catalogo, leer_catalogo
from app.main import create_app
from app.models import ORIGEN_EDITORIAL, Debate, Usuario


def _contar(db, modelo) -> int:
    return db.scalar(select(func.count()).select_from(modelo))


def test_archivo_editorial_es_valido():
    debates = leer_catalogo()

    assert len(debates) == 20
    assert all(d.origen == ORIGEN_EDITORIAL for d in debates)
    assert all(len(d.perspectivas) >= 2 for d in debates)
    assert len({d.categoria for d in debates}) >= 5


def test_carga_es_idempotente_y_no_toca_usuarios(client, registrar):
    registrar()

    with client.app.state.fabrica_sesiones() as db:
        ids_antes = list(db.scalars(select(Debate.id).order_by(Debate.id)))
        resultado = cargar_catalogo(db)
        resultado_bis = cargar_catalogo(db)
        ids_despues = list(db.scalars(select(Debate.id).order_by(Debate.id)))
        usuarios = _contar(db, Usuario)

    assert len(ids_antes) == 20
    assert ids_antes == ids_despues
    assert (resultado.insertados, resultado.actualizados) == (0, 0)
    assert (resultado_bis.insertados, resultado_bis.actualizados) == (0, 0)
    assert usuarios == 1


def test_carga_actualiza_cambios_editoriales_sin_duplicar(client, tmp_path):
    datos = json.loads(ARCHIVO_CATALOGO.read_text(encoding="utf-8"))
    datos[0]["titulo"] = "Título editorial revisado para la prueba"
    archivo = tmp_path / "debates.json"
    archivo.write_text(json.dumps(datos, ensure_ascii=False), encoding="utf-8")

    with client.app.state.fabrica_sesiones() as db:
        resultado = cargar_catalogo(db, archivo)
        total = _contar(db, Debate)
        titulo = db.scalar(select(Debate.titulo).where(Debate.slug == datos[0]["slug"]))

    assert (resultado.insertados, resultado.actualizados) == (0, 1)
    assert total == 20
    assert titulo == "Título editorial revisado para la prueba"


def test_catalogo_y_usuarios_persisten_al_reabrir(settings, registrar):
    registrar()

    with TestClient(create_app(settings)) as reabierto:
        with reabierto.app.state.fabrica_sesiones() as db:
            assert _contar(db, Debate) == 20
            assert _contar(db, Usuario) == 1


def test_claves_foraneas_activadas(client):
    with client.app.state.fabrica_sesiones() as db:
        assert db.execute(text("PRAGMA foreign_keys")).scalar() == 1

"""Migración versionada desde una base representativa de v1.0.0/7A (tests/datos/base_v1_7a.sql)."""

import sqlite3
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select, text

from app.catalogo import cargar_catalogo
from app.db import crear_motor
from app.main import create_app
from app.migrar import aplicar_migraciones, revision_actual
from app.models import Debate

BASE_ANTERIOR = Path(__file__).parent / "datos" / "base_v1_7a.sql"


def _base_anterior(tmp_path) -> Path:
    ruta = tmp_path / "anterior.db"
    with sqlite3.connect(ruta) as c:
        c.executescript(BASE_ANTERIOR.read_text(encoding="utf-8"))
    return ruta


def _filas(ruta: Path, consulta: str) -> list[tuple]:
    with sqlite3.connect(ruta) as c:
        return c.execute(consulta).fetchall()


def test_migra_conservando_ids_cuentas_hashes_debates_y_aportes(tmp_path, settings):
    ruta = _base_anterior(tmp_path)
    usuarios_antes = _filas(ruta, "SELECT id, nombre, email, password_hash FROM usuarios ORDER BY id")
    aportes_antes = _filas(ruta, "SELECT * FROM aportes ORDER BY id")
    slugs_antes = _filas(ruta, "SELECT id, slug FROM debates ORDER BY id")

    config = settings.model_copy(update={"database_url": f"sqlite:///{ruta.as_posix()}"})
    with TestClient(create_app(config)):  # el arranque migra y carga el catálogo
        pass

    assert _filas(ruta, "SELECT version_num FROM alembic_version") == [("0003",)]
    assert _filas(ruta, "SELECT id, nombre, email, password_hash FROM usuarios ORDER BY id") == (
        usuarios_antes
    )
    assert _filas(ruta, "SELECT * FROM aportes ORDER BY id") == aportes_antes
    # Los debates anteriores conservan id y slug, y quedan como editoriales publicados.
    assert _filas(
        ruta, "SELECT id, slug FROM debates WHERE id IN (1, 2, 5) ORDER BY id"
    ) == slugs_antes
    assert _filas(ruta, "SELECT DISTINCT procedencia, estado, autor_id FROM debates") == [
        ("editorial", "publicado", None)
    ]
    # La semilla completa el catálogo sin duplicar: 20 debates editoriales.
    assert _filas(ruta, "SELECT COUNT(*), COUNT(DISTINCT slug) FROM debates") == [(20, 20)]
    assert _filas(ruta, "SELECT COUNT(*) FROM borradores") == [(0,)]
    # 0003: todas las cuentas existentes quedan como usuarios normales; sin solicitudes.
    assert _filas(ruta, "SELECT DISTINCT rol FROM usuarios") == [("usuario",)]
    assert _filas(ruta, "SELECT COUNT(*) FROM solicitudes_archivo") == [(0,)]


def test_nuevas_columnas_y_claves_foraneas(tmp_path):
    ruta = _base_anterior(tmp_path)
    motor = crear_motor(f"sqlite:///{ruta.as_posix()}")
    aplicar_migraciones(motor)
    motor.dispose()

    columnas = {fila[1] for fila in _filas(ruta, "PRAGMA table_info(debates)")}
    assert {"procedencia", "estado", "autor_id", "ambito", "objetivo", "publicado_en"} <= columnas
    assert ("usuarios", "autor_id", "id") in [
        (f[2], f[3], f[4]) for f in _filas(ruta, "PRAGMA foreign_key_list(debates)")
    ]
    claves_borradores = {(f[2], f[3]) for f in _filas(ruta, "PRAGMA foreign_key_list(borradores)")}
    assert claves_borradores == {("usuarios", "autor_id"), ("debates", "debate_id")}
    assert _filas(ruta, "PRAGMA integrity_check") == [("ok",)]


def test_aplicar_dos_veces_no_cambia_nada(tmp_path):
    ruta = _base_anterior(tmp_path)
    motor = crear_motor(f"sqlite:///{ruta.as_posix()}")
    aplicar_migraciones(motor)
    esquema = _filas(ruta, "SELECT sql FROM sqlite_master ORDER BY name")
    aplicar_migraciones(motor)

    assert revision_actual(motor) == "0003"
    assert _filas(ruta, "SELECT sql FROM sqlite_master ORDER BY name") == esquema
    motor.dispose()


def test_base_nueva_desde_cero(tmp_path):
    motor = crear_motor(f"sqlite:///{(tmp_path / 'nueva.db').as_posix()}")
    aplicar_migraciones(motor)

    assert revision_actual(motor) == "0003"
    motor.dispose()


def test_la_semilla_no_sobrescribe_debates_de_usuarios(client):
    with client.app.state.fabrica_sesiones() as db:
        # Simula un debate de usuario cuyo slug coincidiera con uno editorial.
        db.execute(
            text(
                "UPDATE debates SET procedencia = 'usuario', titulo = 'Título de una persona' "
                "WHERE slug = 'celulares-en-el-aula'"
            )
        )
        db.commit()
        cargar_catalogo(db)
        titulo = db.scalar(select(Debate.titulo).where(Debate.slug == "celulares-en-el-aula"))
    assert titulo == "Título de una persona"


def test_0003_conserva_los_archivados_previos_como_archivo_anterior(tmp_path):
    """Una base en 0002 con debates de usuario archivados por su autor (política anterior)."""
    ruta = _base_anterior(tmp_path)
    motor = crear_motor(f"sqlite:///{ruta.as_posix()}")
    aplicar_migraciones(motor, destino="0002")
    with motor.begin() as c:
        for id_, estado, archivado in ((50, "archivado", "2026-10-24 10:00:00"), (51, "publicado", None)):
            c.execute(
                text(
                    "INSERT INTO debates (id, slug, titulo, categoria, resumen, contexto, "
                    "perspectivas, origen, actualizado_en, procedencia, estado, autor_id, "
                    "publicado_en, archivado_en) VALUES (:id, :slug, 'Debate de usuario', "
                    "'salud', 'Resumen', 'Contexto', '[]', 'x', '2026-10-24 09:00:00', "
                    "'usuario', :estado, 1, '2026-10-24 09:00:00', :archivado)"
                ),
                {"id": id_, "slug": f"u-{id_}", "estado": estado, "archivado": archivado},
            )
    antes = _filas(ruta, "SELECT id, estado, archivado_en, autor_id FROM debates WHERE id >= 50")

    aplicar_migraciones(motor)
    motor.dispose()

    # No se reabren ni cambian de fecha o autor; no se atribuyen a ningún administrador.
    assert _filas(ruta, "SELECT id, estado, archivado_en, autor_id FROM debates WHERE id >= 50") == antes
    assert _filas(
        ruta,
        "SELECT id, archivo_origen, archivado_por_id, motivo_archivo FROM debates "
        "WHERE id >= 50 ORDER BY id",
    ) == [(50, "anterior", None, None), (51, None, None, None)]
    assert _filas(ruta, "SELECT COUNT(*) FROM debates WHERE archivo_origen IS NOT NULL") == [(1,)]
    assert ("usuarios", "archivado_por_id", "id") in [
        (f[2], f[3], f[4]) for f in _filas(ruta, "PRAGMA foreign_key_list(debates)")
    ]
    assert _filas(ruta, "PRAGMA integrity_check") == [("ok",)]
    assert _filas(ruta, "PRAGMA foreign_key_check") == []

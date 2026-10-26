"""Migración versionada desde una base representativa de v1.0.0/7A (tests/datos/base_v1_7a.sql)."""

import json
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
COLUMNAS_APORTE = "id, debate_id, autor_id, tipo, texto, creado_en, editado_en"


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
    aportes_antes = _filas(ruta, f"SELECT {COLUMNAS_APORTE} FROM aportes ORDER BY id")
    slugs_antes = _filas(ruta, "SELECT id, slug FROM debates ORDER BY id")

    config = settings.model_copy(update={"database_url": f"sqlite:///{ruta.as_posix()}"})
    with TestClient(create_app(config)):  # el arranque migra y carga el catálogo
        pass

    assert _filas(ruta, "SELECT version_num FROM alembic_version") == [("0005",)]
    assert _filas(ruta, "SELECT id, nombre, email, password_hash FROM usuarios ORDER BY id") == (
        usuarios_antes
    )
    assert _filas(ruta, f"SELECT {COLUMNAS_APORTE} FROM aportes ORDER BY id") == aportes_antes
    # 0004: los aportes anteriores no reciben una versión original inventada.
    assert _filas(ruta, "SELECT DISTINCT version_id FROM aportes") == [(None,)]
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

    assert revision_actual(motor) == "0005"
    assert _filas(ruta, "SELECT sql FROM sqlite_master ORDER BY name") == esquema
    motor.dispose()


def test_base_nueva_desde_cero(tmp_path):
    motor = crear_motor(f"sqlite:///{(tmp_path / 'nueva.db').as_posix()}")
    aplicar_migraciones(motor)

    assert revision_actual(motor) == "0005"
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


def _base_en_0003(tmp_path) -> tuple[Path, object]:
    """Base 7B representativa: debates de usuario con y sin aportes, archivado, borrador,
    solicitud de archivo y una cuenta administradora."""
    ruta = _base_anterior(tmp_path)
    motor = crear_motor(f"sqlite:///{ruta.as_posix()}")
    aplicar_migraciones(motor, destino="0003")
    perspectivas = '[{"titulo": "A favor", "descripcion": "Descripción a favor del debate."}]'
    with motor.begin() as c:
        for id_, estado, origen in ((50, "publicado", None), (51, "publicado", None), (52, "archivado", "anterior")):
            c.execute(
                text(
                    "INSERT INTO debates (id, slug, titulo, categoria, resumen, contexto, "
                    "perspectivas, origen, actualizado_en, procedencia, estado, autor_id, ambito, "
                    "objetivo, publicado_en, archivo_origen) VALUES (:id, :slug, :titulo, 'salud', "
                    "'Resumen de usuario', 'Contexto de usuario', :p, 'x', '2026-10-24 09:00:00', "
                    "'usuario', :estado, 1, 'Barrio', 'Objetivo del debate', "
                    "'2026-10-24 09:00:00', :origen)"
                ),
                {"id": id_, "slug": f"u-{id_}", "titulo": f"Debate de usuario {id_}",
                 "p": perspectivas, "estado": estado, "origen": origen},
            )
        c.execute(text(
            "INSERT INTO aportes (id, debate_id, autor_id, tipo, texto, creado_en) VALUES "
            "(20, 50, 2, 'pregunta', 'Aporte en debate de usuario.', '2026-10-24 10:00:00')"
        ))
        c.execute(text(
            "INSERT INTO borradores (id, autor_id, titulo, paso, creado_en, actualizado_en) "
            "VALUES (5, 1, 'Borrador pendiente', 2, '2026-10-24 08:00:00', '2026-10-24 08:00:00')"
        ))
        c.execute(text(
            "INSERT INTO solicitudes_archivo (id, debate_id, solicitante_id, motivo, estado, "
            "creada_en) VALUES (3, 51, 1, 'Motivo de la solicitud.', 'pendiente', "
            "'2026-10-24 11:00:00')"
        ))
        c.execute(text("UPDATE usuarios SET rol = 'administrador' WHERE id = 7"))
    return ruta, motor


def test_0004_registra_instantanea_inicial_sin_inventar_historia(tmp_path):
    ruta, motor = _base_en_0003(tmp_path)
    consultas = {
        "usuarios": "SELECT id, nombre, email, password_hash, rol FROM usuarios ORDER BY id",
        "debates": "SELECT id, slug, titulo, resumen, contexto, perspectivas, estado, autor_id, "
        "archivo_origen FROM debates ORDER BY id",
        "aportes": f"SELECT {COLUMNAS_APORTE} FROM aportes ORDER BY id",
        "borradores": "SELECT * FROM borradores ORDER BY id",
        "solicitudes": "SELECT * FROM solicitudes_archivo ORDER BY id",
    }
    antes = {k: _filas(ruta, q) for k, q in consultas.items()}

    aplicar_migraciones(motor, destino="0004")

    assert revision_actual(motor) == "0004"
    assert {k: _filas(ruta, q) for k, q in consultas.items()} == antes
    # Una única versión por debate existente, del tipo registro inicial, sin autor ni motivo.
    n_debates = _filas(ruta, "SELECT COUNT(*) FROM debates")[0][0]
    assert _filas(
        ruta,
        "SELECT COUNT(*), COUNT(DISTINCT debate_id), MIN(numero), MAX(numero), "
        "COUNT(autor_id), COUNT(motivo) FROM versiones_debate",
    ) == [(n_debates, n_debates, 1, 1, 0, 0)]
    assert _filas(ruta, "SELECT DISTINCT tipo FROM versiones_debate") == [("registro_inicial",)]
    # La instantánea copia el contenido tal cual (perspectivas comparadas como JSON).
    campos = "categoria, ambito, titulo, resumen, contexto, perspectivas, objetivo"
    for id_ in (1, 50, 52):
        (debate,) = _filas(ruta, f"SELECT {campos} FROM debates WHERE id = {id_}")
        (version,) = _filas(ruta, f"SELECT {campos} FROM versiones_debate WHERE debate_id = {id_}")
        assert version[:5] + version[6:] == debate[:5] + debate[6:]
        assert json.loads(version[5]) == json.loads(debate[5])
    # Indicadores: participación solo donde hay aportes; bloqueo conservador en todos.
    assert _filas(
        ruta,
        "SELECT id, version_actual, con_participacion, bloqueo_historico FROM debates "
        "WHERE id IN (1, 2, 5, 50, 51, 52) ORDER BY id",
    ) == [(1, 1, 1, 1), (2, 1, 0, 1), (5, 1, 1, 1), (50, 1, 1, 1), (51, 1, 0, 1), (52, 1, 0, 1)]
    # Aportes anteriores: versión original desconocida (no se les atribuye la instantánea).
    assert _filas(ruta, "SELECT DISTINCT version_id FROM aportes") == [(None,)]
    assert _filas(ruta, "SELECT COUNT(*) FROM aclaraciones") == [(0,)]
    assert _filas(ruta, "PRAGMA integrity_check") == [("ok",)]
    assert _filas(ruta, "PRAGMA foreign_key_check") == []
    motor.dispose()


def test_0004_bloquea_lo_anterior_y_deja_editables_borradores_y_lo_nuevo(tmp_path):
    from app.db import crear_fabrica_sesiones
    from app.repositorios import borradores as repo_borradores
    from app.repositorios import debates as repo_debates
    from app.schemas import ContenidoDebate
    from tests.test_borradores import CONTENIDO

    ruta, motor = _base_en_0003(tmp_path)
    aplicar_migraciones(motor)
    with crear_fabrica_sesiones(motor)() as db:
        # Debate anterior sin aportes: bloqueo conservador (no se puede probar que nunca los tuvo).
        assert repo_debates.editar_si_permitido(db, 51, 1, CONTENIDO, "Motivo de prueba.") == (
            repo_debates.ResultadoEdicion.rechazado
        )
        # El borrador sigue editable y, al publicarse, usa el indicador permanente.
        borrador = repo_borradores.obtener_propio(db, 5, 1)
        repo_borradores.actualizar(db, borrador, {k: v for k, v in CONTENIDO.items()})
        debate, creado = repo_borradores.publicar(db, borrador, ContenidoDebate.model_validate(CONTENIDO))
        assert creado and debate.version_actual == 1
        assert debate.bloqueo_historico is False and debate.con_participacion is False
        assert repo_debates.editar_si_permitido(
            db, debate.id, 1, {**CONTENIDO, "titulo": "¿Pregunta nueva tras la migración?"}, "Motivo."
        ) == repo_debates.ResultadoEdicion.editado
    assert _filas(
        ruta, "SELECT numero, tipo FROM versiones_debate WHERE debate_id = "
        "(SELECT debate_id FROM borradores WHERE id = 5) ORDER BY numero",
    ) == [(1, "publicacion"), (2, "edicion")]
    motor.dispose()


def test_0005_deja_la_edad_pendiente_y_sin_fuentes_retroactivas(tmp_path):
    ruta, motor = _base_en_0003(tmp_path)
    aplicar_migraciones(motor, destino="0004")
    consultas = {
        "usuarios": "SELECT id, nombre, email, password_hash, rol FROM usuarios ORDER BY id",
        "debates": "SELECT id, titulo, contexto, estado, version_actual, con_participacion FROM debates",
        "versiones": "SELECT debate_id, numero, tipo, titulo FROM versiones_debate ORDER BY id",
        "aportes": f"SELECT {COLUMNAS_APORTE}, version_id FROM aportes ORDER BY id",
        "borradores": "SELECT id, autor_id, titulo, paso FROM borradores ORDER BY id",
        "solicitudes": "SELECT * FROM solicitudes_archivo ORDER BY id",
    }
    antes = {k: _filas(ruta, q) for k, q in consultas.items()}

    aplicar_migraciones(motor)

    assert revision_actual(motor) == "0005"
    assert {k: _filas(ruta, q) for k, q in consultas.items()} == antes
    # Ninguna cuenta queda confirmada automáticamente, tampoco la administradora (id 7).
    assert _filas(ruta, "SELECT rol, COUNT(*), COUNT(mayoria_edad_declarada_en) FROM usuarios "
                        "GROUP BY rol ORDER BY rol") == [("administrador", 1, 0), ("usuario", 2, 0)]
    for tabla, columnas in (
        ("debates", "referencias, evidencias"),
        ("versiones_debate", "referencias, evidencias"),
        ("borradores", "referencias, evidencias, redaccion"),
    ):
        assert _filas(ruta, f"SELECT DISTINCT {columnas} FROM {tabla}") == [
            tuple(None for _ in columnas.split(","))
        ]
    assert _filas(ruta, "PRAGMA integrity_check") == [("ok",)]
    assert _filas(ruta, "PRAGMA foreign_key_check") == []
    motor.dispose()

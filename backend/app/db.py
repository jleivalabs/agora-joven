"""Motor SQLite, sesiones y dependencia de FastAPI para obtener una sesión."""

from collections.abc import Iterator
from pathlib import Path

from fastapi import Request
from sqlalchemy import Engine, create_engine, event
from sqlalchemy.engine import make_url
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
    pass


def crear_motor(database_url: str) -> Engine:
    url = make_url(database_url)
    if url.get_backend_name() != "sqlite":
        raise ValueError("Ágora Joven solo admite SQLite.")
    if url.database and url.database != ":memory:":
        Path(url.database).parent.mkdir(parents=True, exist_ok=True)

    motor = create_engine(database_url, connect_args={"check_same_thread": False})

    @event.listens_for(motor, "connect")
    def _activar_claves_foraneas(conexion_dbapi, _registro):
        cursor = conexion_dbapi.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    return motor


def crear_fabrica_sesiones(motor: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=motor, expire_on_commit=False)


def get_db(request: Request) -> Iterator[Session]:
    with request.app.state.fabrica_sesiones() as sesion:
        yield sesion

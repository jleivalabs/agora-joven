"""Fixtures con base SQLite temporal y secreto sintético generado en cada ejecución."""

import secrets
from collections.abc import Callable, Iterator

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

PASSWORD = "clave-de-prueba-123"


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(
        _env_file=None,
        jwt_secret=secrets.token_urlsafe(48),
        jwt_expira_minutos=5,
        database_url=f"sqlite:///{(tmp_path / 'agora-test.db').as_posix()}",
    )


@pytest.fixture
def client(settings) -> Iterator[TestClient]:
    with TestClient(create_app(settings)) as cliente:
        yield cliente


@pytest.fixture
def registrar(client) -> Callable[..., dict]:
    def _registrar(email: str = "ana@example.com", nombre: str = "Ana") -> dict:
        respuesta = client.post(
            "/auth/registro", json={"nombre": nombre, "email": email, "password": PASSWORD}
        )
        assert respuesta.status_code == 201, respuesta.text
        return respuesta.json()

    return _registrar


@pytest.fixture
def auth(client, registrar) -> dict[str, str]:
    """Cabecera Authorization de un usuario recién registrado."""
    registrar()
    respuesta = client.post(
        "/auth/login", json={"email": "ana@example.com", "password": PASSWORD}
    )
    return {"Authorization": f"Bearer {respuesta.json()['access_token']}"}

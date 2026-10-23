import secrets
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr, ValidationError
from sqlalchemy import select, text

from app.config import Settings
from app.main import create_app
from app.models import Usuario
from app.security import crear_token
from tests.conftest import PASSWORD

CAMPOS_USUARIO = {"id", "nombre", "email", "creado_en"}


def _login(client, email="ana@example.com", password=PASSWORD):
    return client.post("/auth/login", json={"email": email, "password": password})


# --- Registro ---------------------------------------------------------------


def test_registro_correcto_devuelve_solo_datos_publicos(client):
    respuesta = client.post(
        "/auth/registro",
        json={"nombre": "  Ana   Pérez ", "email": " Ana@Example.COM ", "password": PASSWORD},
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.json()
    assert set(cuerpo) == CAMPOS_USUARIO
    assert cuerpo["email"] == "ana@example.com"
    assert cuerpo["nombre"] == "Ana Pérez"
    assert PASSWORD not in respuesta.text
    assert "argon2" not in respuesta.text


def test_registro_con_correo_duplicado_aunque_cambien_mayusculas(client, registrar):
    registrar(email="ana@example.com")

    respuesta = client.post(
        "/auth/registro",
        json={"nombre": "Otra", "email": "ANA@example.com", "password": PASSWORD},
    )

    assert respuesta.status_code == 400
    assert respuesta.json()["detail"] == "Ya existe una cuenta con ese correo."


@pytest.mark.parametrize(
    "datos",
    [
        {"nombre": "Ana", "email": "no-es-correo", "password": PASSWORD},
        {"nombre": "Ana", "email": "ana@example.com", "password": "corta"},
        {"nombre": " ", "email": "ana@example.com", "password": PASSWORD},
        {"email": "ana@example.com", "password": PASSWORD},
    ],
)
def test_registro_invalido_responde_422(client, datos):
    assert client.post("/auth/registro", json=datos).status_code == 422


def test_password_se_guarda_como_hash_argon2(client, registrar):
    registrar()

    with client.app.state.fabrica_sesiones() as db:
        usuario = db.scalar(select(Usuario))
    assert usuario.password_hash != PASSWORD
    assert usuario.password_hash.startswith("$argon2id$")


def test_unicidad_del_correo_garantizada_por_la_base(client, registrar):
    registrar()
    with client.app.state.fabrica_sesiones() as db:
        indices = db.execute(text("PRAGMA index_list('usuarios')")).all()
    assert any(fila.unique for fila in indices)


# --- Login --------------------------------------------------------------------


def test_login_valido_devuelve_token_bearer(client, registrar, settings):
    registrar()

    respuesta = _login(client, email="  ANA@example.com")

    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["token_type"] == "bearer"
    assert cuerpo["expira_en"] == settings.jwt_expira_minutos * 60
    cabecera = jwt.get_unverified_header(cuerpo["access_token"])
    assert cabecera["alg"] == "HS256"


@pytest.mark.parametrize(
    "email,password",
    [("ana@example.com", "otra-clave-123"), ("nadie@example.com", PASSWORD)],
)
def test_login_invalido_responde_401_con_mensaje_generico(client, registrar, email, password):
    registrar()

    respuesta = _login(client, email=email, password=password)

    assert respuesta.status_code == 401
    assert respuesta.json()["detail"] == "Correo o contraseña incorrectos."


# --- /auth/me -------------------------------------------------------------------


def test_me_con_token_valido(client, auth):
    respuesta = client.get("/auth/me", headers=auth)

    assert respuesta.status_code == 200
    assert set(respuesta.json()) == CAMPOS_USUARIO
    assert respuesta.json()["email"] == "ana@example.com"


def test_me_sin_token(client):
    respuesta = client.get("/auth/me")

    assert respuesta.status_code == 401
    assert respuesta.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize(
    "cabecera",
    ["Bearer no.es.un.jwt", "Bearer ", "Basic dXN1YXJpbzpjbGF2ZQ==", "token-sin-esquema"],
)
def test_me_con_token_mal_formado(client, cabecera):
    assert client.get("/auth/me", headers={"Authorization": cabecera}).status_code == 401


def test_me_con_token_manipulado(client, auth):
    token = auth["Authorization"].removeprefix("Bearer ")
    cabecera, carga, firma = token.split(".")
    otra_firma = firma[:-2] + ("AA" if not firma.endswith("AA") else "BB")

    for alterado in (f"{cabecera}.{carga}.{otra_firma}", f"{cabecera}.{carga}x.{firma}"):
        respuesta = client.get("/auth/me", headers={"Authorization": f"Bearer {alterado}"})
        assert respuesta.status_code == 401


def test_me_con_token_firmado_con_otro_secreto(client, registrar, settings):
    usuario = registrar()
    otro = settings.model_copy(update={"jwt_secret": SecretStr(secrets.token_urlsafe(48))})

    token = crear_token(usuario["id"], otro)

    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_me_con_token_sin_algoritmo(client, registrar):
    usuario = registrar()
    token = jwt.encode(
        {"sub": str(usuario["id"]), "iat": 0, "exp": 9999999999}, key=None, algorithm="none"
    )

    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_me_con_token_caducado(client, registrar, settings):
    usuario = registrar()
    hace_un_rato = datetime.now(timezone.utc) - timedelta(minutes=settings.jwt_expira_minutos + 1)

    token = crear_token(usuario["id"], settings, ahora=hace_un_rato)

    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_me_con_token_de_usuario_inexistente(client, settings):
    token = crear_token(9999, settings)

    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


# --- Configuración y persistencia ----------------------------------------------


@pytest.mark.parametrize("secreto", [None, "demasiado-corto"])
def test_sin_secreto_valido_la_configuracion_falla(monkeypatch, secreto):
    monkeypatch.delenv("JWT_SECRET", raising=False)
    datos = {} if secreto is None else {"jwt_secret": secreto}

    with pytest.raises(ValidationError):
        Settings(_env_file=None, **datos)


def test_usuario_persiste_al_reabrir_la_base(settings):
    with TestClient(create_app(settings)) as primero:
        assert primero.post(
            "/auth/registro",
            json={"nombre": "Ana", "email": "ana@example.com", "password": PASSWORD},
        ).status_code == 201

    with TestClient(create_app(settings)) as segundo:
        respuesta = _login(segundo)

    assert respuesta.status_code == 200

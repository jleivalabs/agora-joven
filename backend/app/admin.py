"""Comando administrativo local: ver cuentas y conceder o retirar el rol de administración.

No hay administradores predeterminados ni contraseñas nuevas: se promueve una cuenta que ya
existe, indicada por su id, tras confirmarlo escribiendo de nuevo ese id. Solo muestra id, nombre
y rol (nunca correos, contraseñas ni hashes). Requiere acceso local a la base: en Docker,

    docker compose exec api python -m app.admin listar
    docker compose exec api python -m app.admin promover <id>
    docker compose exec api python -m app.admin retirar <id>

No aplica migraciones: si la base no está en la última revisión, se detiene.
"""

import argparse
import sys
from collections.abc import Callable

from alembic.script import ScriptDirectory
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Rol, Usuario


class CuentaNoEncontrada(Exception):
    pass


def listar(db: Session) -> list[tuple[int, str, str]]:
    return [(u.id, u.nombre, u.rol) for u in db.scalars(select(Usuario).order_by(Usuario.id))]


def cambiar_rol(db: Session, usuario_id: int, rol: Rol) -> Usuario:
    usuario = db.get(Usuario, usuario_id)
    if usuario is None:
        raise CuentaNoEncontrada
    usuario.rol = rol.value
    db.commit()
    return usuario


def ejecutar(
    db: Session,
    argumentos: list[str],
    entrada: Callable[[str], str] = input,
    salida: Callable[[str], None] = print,
) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.admin", description=__doc__.splitlines()[0])
    ordenes = parser.add_subparsers(dest="orden", required=True)
    ordenes.add_parser("listar", help="Lista id, nombre y rol de las cuentas.")
    for nombre, ayuda in (
        ("promover", "Concede el rol de administración a una cuenta existente."),
        ("retirar", "Devuelve una cuenta al rol de usuario."),
    ):
        orden = ordenes.add_parser(nombre, help=ayuda)
        orden.add_argument("id", type=int, help="Id de la cuenta (ver 'listar').")
    args = parser.parse_args(argumentos)

    if args.orden == "listar":
        for id_, nombre, rol in listar(db):
            salida(f"{id_:>5}  {rol:<14} {nombre}")
        return 0

    usuario = db.get(Usuario, args.id)
    if usuario is None:
        salida(f"No existe ninguna cuenta con id {args.id}. No se cambió nada.")
        return 1
    nuevo = Rol.administrador if args.orden == "promover" else Rol.usuario
    if usuario.rol == nuevo.value:
        salida(f"La cuenta {usuario.id} ({usuario.nombre}) ya tiene el rol '{nuevo.value}'.")
        return 0
    salida(f"Cuenta {usuario.id}: {usuario.nombre} · rol actual '{usuario.rol}' → '{nuevo.value}'.")
    try:
        confirmacion = entrada(f"Escribe {usuario.id} para confirmar (otra cosa cancela): ")
    except EOFError:
        confirmacion = ""
    if confirmacion.strip() != str(usuario.id):
        salida("Cancelado. No se cambió nada.")
        return 1
    cambiar_rol(db, usuario.id, nuevo)
    salida(f"Hecho: la cuenta {usuario.id} tiene ahora el rol '{nuevo.value}'.")
    return 0


def main() -> None:
    from app.config import Settings
    from app.db import crear_fabrica_sesiones, crear_motor
    from app.migrar import _configuracion, revision_actual

    motor = crear_motor(Settings().database_url)
    try:
        ultima = ScriptDirectory.from_config(_configuracion()).get_current_head()
        if revision_actual(motor) != ultima:
            print("La base no está en la última revisión. Arranca la API para migrarla primero.")
            sys.exit(1)
        with crear_fabrica_sesiones(motor)() as db:
            codigo = ejecutar(db, sys.argv[1:])
    finally:
        motor.dispose()
    sys.exit(codigo)


if __name__ == "__main__":
    main()

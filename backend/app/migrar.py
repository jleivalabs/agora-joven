"""Migraciones versionadas del esquema (Alembic, en app/migraciones/).

- Base nueva: aplica todas las revisiones desde cero.
- Base creada antes de 7B sin Alembic (tablas de v1.0.0/7A y sin `alembic_version`): se marca
  como revisión 0001 y se aplican las siguientes.
- Base ya versionada: aplica solo las revisiones pendientes.

Se ejecuta al arrancar la API. Uso manual: python -m app.migrar
"""

from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from sqlalchemy import Engine, inspect

CARPETA = Path(__file__).parent / "migraciones"
TABLAS_V1 = {"usuarios", "debates", "aportes"}


def _configuracion() -> Config:
    config = Config()
    config.set_main_option("script_location", str(CARPETA))
    return config


def revision_actual(motor: Engine) -> str | None:
    with motor.connect() as conexion:
        return MigrationContext.configure(conexion).get_current_revision()


def aplicar_migraciones(motor: Engine, destino: str = "head") -> None:
    """[destino] permite a las pruebas detenerse en una revisión intermedia."""
    config = _configuracion()
    with motor.begin() as conexion:
        config.attributes["connection"] = conexion
        tablas = set(inspect(conexion).get_table_names())
        if "alembic_version" not in tablas and TABLAS_V1 <= tablas:
            command.stamp(config, "0001")
        command.upgrade(config, destino)


def main() -> None:
    from app.config import Settings
    from app.db import crear_motor

    motor = crear_motor(Settings().database_url)
    aplicar_migraciones(motor)
    print(f"Esquema en la revisión {revision_actual(motor)}.")
    motor.dispose()


if __name__ == "__main__":
    main()

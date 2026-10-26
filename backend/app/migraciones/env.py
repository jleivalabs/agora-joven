"""Entorno de Alembic. Se ejecuta solo desde app/migrar.py, que entrega la conexión.

`render_as_batch` permite, si alguna migración futura lo necesita, cambiar tablas en SQLite
recreándolas; las migraciones actuales solo añaden columnas y tablas.
"""

from alembic import context

conexion = context.config.attributes.get("connection")
if conexion is None:
    raise RuntimeError("Ejecuta las migraciones con: python -m app.migrar")

context.configure(connection=conexion, target_metadata=None, render_as_batch=True)

with context.begin_transaction():
    context.run_migrations()

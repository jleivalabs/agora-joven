"""Bloque 7C: declaración de mayoría de edad y referencias bibliográficas.

- `usuarios.mayoria_edad_declarada_en`: nula en **todas** las cuentas existentes, incluidas las
  administradoras. Deben confirmar antes de seguir usando la plataforma; no se da por aceptada.
- `borradores.referencias`, `borradores.evidencias`, `borradores.redaccion`: nulas.
- `debates.referencias`, `debates.evidencias` y las mismas en `versiones_debate`: nulas. Los
  debates y versiones anteriores quedan sin fuentes; no se les atribuye investigación.

Solo añade columnas: no recrea ni vacía tablas existentes.

Revision ID: 0005
"""

import sqlalchemy as sa
from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None

COLUMNAS = {
    "borradores": ("referencias", "evidencias", "redaccion"),
    "debates": ("referencias", "evidencias"),
    "versiones_debate": ("referencias", "evidencias"),
}


def upgrade() -> None:
    op.add_column(
        "usuarios",
        sa.Column("mayoria_edad_declarada_en", sa.DateTime(timezone=True), nullable=True),
    )
    for tabla, columnas in COLUMNAS.items():
        for columna in columnas:
            op.add_column(tabla, sa.Column(columna, sa.JSON(), nullable=True))


def downgrade() -> None:
    for tabla, columnas in COLUMNAS.items():
        with op.batch_alter_table(tabla) as t:
            for columna in columnas:
                t.drop_column(columna)
    with op.batch_alter_table("usuarios") as t:
        t.drop_column("mayoria_edad_declarada_en")

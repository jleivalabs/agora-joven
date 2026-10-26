"""Bloque 7B.1: historial de versiones, participación permanente, aportes por versión y aclaraciones.

Datos existentes (sin inventar historia):
- Cada debate existente (publicado o archivado) recibe una única versión 1 de tipo
  `registro_inicial`: el "Estado registrado al incorporar el historial", fechada en el momento de
  la migración, sin autor del cambio ni motivo. No se crean versiones anteriores.
- `con_participacion` se marca en los debates que tienen aportes.
- `bloqueo_historico` se marca en **todos** los debates existentes: no se puede demostrar que los
  que hoy no tienen aportes nunca los tuvieron (pudieron eliminarse), así que no se reescriben.
- Los aportes existentes conservan `version_id` nulo: su versión original es desconocida.
- Borradores, cuentas, roles, aportes y solicitudes no cambian.

Solo añade columnas y tablas: no recrea ni vacía tablas existentes.

Revision ID: 0004
"""

from datetime import datetime, timezone

import sqlalchemy as sa
from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None

CAMPOS = ("categoria", "ambito", "titulo", "resumen", "contexto", "perspectivas", "objetivo")


def upgrade() -> None:
    op.create_table(
        "versiones_debate",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("debate_id", sa.Integer(), nullable=False),
        sa.Column("numero", sa.Integer(), nullable=False),
        sa.Column("tipo", sa.String(20), nullable=False),
        sa.Column("categoria", sa.String(30), nullable=False),
        sa.Column("ambito", sa.Text(), nullable=True),
        sa.Column("titulo", sa.String(160), nullable=False),
        sa.Column("resumen", sa.Text(), nullable=False),
        sa.Column("contexto", sa.Text(), nullable=False),
        sa.Column("perspectivas", sa.JSON(), nullable=False),
        sa.Column("objetivo", sa.Text(), nullable=True),
        sa.Column("creada_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("autor_id", sa.Integer(), nullable=True),
        sa.Column("motivo", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["debate_id"], ["debates.id"]),
        sa.ForeignKeyConstraint(["autor_id"], ["usuarios.id"]),
        sa.UniqueConstraint("debate_id", "numero", name="uq_versiones_debate_numero"),
    )
    op.create_index("ix_versiones_debate_debate_id", "versiones_debate", ["debate_id"])

    op.create_table(
        "aclaraciones",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("debate_id", sa.Integer(), nullable=False),
        sa.Column("autor_id", sa.Integer(), nullable=False),
        sa.Column("texto", sa.Text(), nullable=False),
        sa.Column("creada_en", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["debate_id"], ["debates.id"]),
        sa.ForeignKeyConstraint(["autor_id"], ["usuarios.id"]),
    )
    op.create_index("ix_aclaraciones_debate_id", "aclaraciones", ["debate_id"])

    op.add_column("debates", sa.Column("version_actual", sa.Integer(), nullable=True))
    op.add_column(
        "debates",
        sa.Column("con_participacion", sa.Boolean(), nullable=False, server_default=sa.text("0")),
    )
    op.add_column(
        "debates",
        sa.Column("bloqueo_historico", sa.Boolean(), nullable=False, server_default=sa.text("0")),
    )
    # Igual que en 0002 y 0003: ADD COLUMN con REFERENCES directo para no recrear la tabla.
    op.execute("ALTER TABLE aportes ADD COLUMN version_id INTEGER REFERENCES versiones_debate (id)")

    # Instantánea inicial de cada debate existente (tipos explícitos para leer el JSON y escribir
    # la fecha igual que la aplicación).
    debates = sa.table(
        "debates",
        sa.column("id", sa.Integer()),
        *(sa.column(c, sa.JSON() if c == "perspectivas" else sa.Text()) for c in CAMPOS),
    )
    versiones = sa.table(
        "versiones_debate",
        sa.column("debate_id", sa.Integer()),
        sa.column("numero", sa.Integer()),
        sa.column("tipo", sa.String()),
        *(sa.column(c, sa.JSON() if c == "perspectivas" else sa.Text()) for c in CAMPOS),
        sa.column("creada_en", sa.DateTime(timezone=True)),
    )
    ahora = datetime.now(timezone.utc)
    filas = [
        {"debate_id": fila.id, "numero": 1, "tipo": "registro_inicial", "creada_en": ahora,
         **{c: getattr(fila, c) for c in CAMPOS}}
        for fila in op.get_bind().execute(sa.select(debates).order_by(debates.c.id))
    ]
    if filas:
        op.bulk_insert(versiones, filas)
    op.execute(
        "UPDATE debates SET version_actual = 1, bloqueo_historico = 1, "
        "con_participacion = EXISTS (SELECT 1 FROM aportes WHERE aportes.debate_id = debates.id)"
    )


def downgrade() -> None:
    with op.batch_alter_table("aportes") as tabla:
        tabla.drop_column("version_id")
    with op.batch_alter_table("debates") as tabla:
        for columna in ("bloqueo_historico", "con_participacion", "version_actual"):
            tabla.drop_column(columna)
    op.drop_index("ix_aclaraciones_debate_id", table_name="aclaraciones")
    op.drop_table("aclaraciones")
    op.drop_index("ix_versiones_debate_debate_id", table_name="versiones_debate")
    op.drop_table("versiones_debate")

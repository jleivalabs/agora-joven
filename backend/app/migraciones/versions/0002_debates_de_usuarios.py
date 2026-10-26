"""Bloque 7B: debates creados por usuarios, estados y borradores privados.

Solo añade columnas (ALTER TABLE ADD COLUMN) y una tabla nueva: no recrea ni vacía tablas, así que
se conservan ids, cuentas, contraseñas cifradas, debates y aportes. Los debates existentes quedan
como editoriales publicados por los valores por defecto.

Revision ID: 0002
"""

import sqlalchemy as sa
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "debates",
        sa.Column("procedencia", sa.String(20), nullable=False, server_default="editorial"),
    )
    op.add_column(
        "debates",
        sa.Column("estado", sa.String(20), nullable=False, server_default="publicado"),
    )
    # SQLite admite ADD COLUMN con REFERENCES si el valor por defecto es NULL; Alembic solo lo
    # permite en modo batch (que recrearía la tabla), así que se usa la sentencia directa.
    op.execute("ALTER TABLE debates ADD COLUMN autor_id INTEGER REFERENCES usuarios (id)")
    op.add_column("debates", sa.Column("ambito", sa.Text(), nullable=True))
    op.add_column("debates", sa.Column("objetivo", sa.Text(), nullable=True))
    op.add_column("debates", sa.Column("publicado_en", sa.DateTime(timezone=True), nullable=True))
    op.add_column("debates", sa.Column("archivado_en", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_debates_estado", "debates", ["estado"])
    op.create_index("ix_debates_autor_id", "debates", ["autor_id"])

    op.create_table(
        "borradores",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("autor_id", sa.Integer(), nullable=False),
        sa.Column("categoria", sa.String(30), nullable=True),
        sa.Column("ambito", sa.Text(), nullable=True),
        sa.Column("titulo", sa.Text(), nullable=True),
        sa.Column("resumen", sa.Text(), nullable=True),
        sa.Column("contexto", sa.Text(), nullable=True),
        sa.Column("perspectivas", sa.JSON(), nullable=True),
        sa.Column("objetivo", sa.Text(), nullable=True),
        sa.Column("paso", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("debate_id", sa.Integer(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["autor_id"], ["usuarios.id"]),
        sa.ForeignKeyConstraint(["debate_id"], ["debates.id"]),
        sa.UniqueConstraint("debate_id"),
    )
    op.create_index("ix_borradores_autor_id", "borradores", ["autor_id"])


def downgrade() -> None:
    op.drop_index("ix_borradores_autor_id", table_name="borradores")
    op.drop_table("borradores")
    op.drop_index("ix_debates_autor_id", table_name="debates")
    op.drop_index("ix_debates_estado", table_name="debates")
    with op.batch_alter_table("debates") as tabla:
        for columna in (
            "archivado_en",
            "publicado_en",
            "objetivo",
            "ambito",
            "autor_id",
            "estado",
            "procedencia",
        ):
            tabla.drop_column(columna)

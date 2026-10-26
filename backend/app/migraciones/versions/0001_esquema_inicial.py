"""Esquema de v1.0.0 y del Bloque 7A (usuarios, debates y aportes).

Reproduce exactamente las tablas que creaba `create_all` hasta 7A. Las bases existentes, creadas
sin Alembic, se marcan con esta revisión (stamp) en lugar de ejecutarla.

Revision ID: 0001
"""

import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "usuarios",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("nombre", sa.String(60), nullable=False),
        sa.Column("email", sa.String(254), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_usuarios_email", "usuarios", ["email"], unique=True)

    op.create_table(
        "debates",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("slug", sa.String(80), nullable=False),
        sa.Column("titulo", sa.String(160), nullable=False),
        sa.Column("categoria", sa.String(30), nullable=False),
        sa.Column("resumen", sa.Text(), nullable=False),
        sa.Column("contexto", sa.Text(), nullable=False),
        sa.Column("perspectivas", sa.JSON(), nullable=False),
        sa.Column("origen", sa.String(80), nullable=False),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )
    op.create_index("ix_debates_categoria", "debates", ["categoria"])

    op.create_table(
        "aportes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("debate_id", sa.Integer(), nullable=False),
        sa.Column("autor_id", sa.Integer(), nullable=False),
        sa.Column("tipo", sa.String(20), nullable=False),
        sa.Column("texto", sa.Text(), nullable=False),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("editado_en", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["debate_id"], ["debates.id"]),
        sa.ForeignKeyConstraint(["autor_id"], ["usuarios.id"]),
    )
    op.create_index("ix_aportes_autor_id", "aportes", ["autor_id"])
    op.create_index("ix_aportes_debate_orden", "aportes", ["debate_id", "creado_en", "id"])


def downgrade() -> None:
    op.drop_table("aportes")
    op.drop_table("debates")
    op.drop_table("usuarios")

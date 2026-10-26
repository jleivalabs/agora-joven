"""Bloque 7B (ajuste): roles y solicitudes de archivo revisadas por la administración.

- `usuarios.rol`: todas las cuentas existentes quedan como `usuario`. No se crea ningún
  administrador: se promueve una cuenta existente con `python -m app.admin`.
- `debates.archivo_origen`, `archivado_por_id`, `motivo_archivo`. Los debates que ya estaban
  archivados (por su autor, con la política anterior) se marcan como `anterior`, sin revisor ni
  motivo: no se reabren ni se atribuyen a un administrador.
- Tabla `solicitudes_archivo` con un índice único parcial: una sola solicitud pendiente por
  debate, también ante peticiones simultáneas.

Solo añade columnas y una tabla: no recrea ni vacía tablas existentes.

Revision ID: 0003
"""

import sqlalchemy as sa
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "usuarios",
        sa.Column("rol", sa.String(20), nullable=False, server_default="usuario"),
    )
    op.add_column("debates", sa.Column("archivo_origen", sa.String(20), nullable=True))
    # Igual que en 0002: ADD COLUMN con REFERENCES directo para no recrear la tabla.
    op.execute("ALTER TABLE debates ADD COLUMN archivado_por_id INTEGER REFERENCES usuarios (id)")
    op.add_column("debates", sa.Column("motivo_archivo", sa.Text(), nullable=True))
    op.execute(
        "UPDATE debates SET archivo_origen = 'anterior' "
        "WHERE estado = 'archivado' AND archivo_origen IS NULL"
    )

    op.create_table(
        "solicitudes_archivo",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("debate_id", sa.Integer(), nullable=False),
        sa.Column("solicitante_id", sa.Integer(), nullable=False),
        sa.Column("motivo", sa.Text(), nullable=False),
        sa.Column("estado", sa.String(20), nullable=False),
        sa.Column("creada_en", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revisor_id", sa.Integer(), nullable=True),
        sa.Column("justificacion", sa.Text(), nullable=True),
        sa.Column("resuelta_en", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["debate_id"], ["debates.id"]),
        sa.ForeignKeyConstraint(["solicitante_id"], ["usuarios.id"]),
        sa.ForeignKeyConstraint(["revisor_id"], ["usuarios.id"]),
    )
    op.create_index("ix_solicitudes_archivo_debate_id", "solicitudes_archivo", ["debate_id"])
    op.create_index(
        "ix_solicitudes_archivo_solicitante_id", "solicitudes_archivo", ["solicitante_id"]
    )
    op.create_index("ix_solicitudes_archivo_estado", "solicitudes_archivo", ["estado"])
    op.create_index(
        "ux_solicitudes_archivo_pendiente",
        "solicitudes_archivo",
        ["debate_id"],
        unique=True,
        sqlite_where=sa.text("estado = 'pendiente'"),
    )


def downgrade() -> None:
    op.drop_index("ux_solicitudes_archivo_pendiente", table_name="solicitudes_archivo")
    op.drop_index("ix_solicitudes_archivo_estado", table_name="solicitudes_archivo")
    op.drop_index("ix_solicitudes_archivo_solicitante_id", table_name="solicitudes_archivo")
    op.drop_index("ix_solicitudes_archivo_debate_id", table_name="solicitudes_archivo")
    op.drop_table("solicitudes_archivo")
    with op.batch_alter_table("debates") as tabla:
        for columna in ("motivo_archivo", "archivado_por_id", "archivo_origen"):
            tabla.drop_column(columna)
    with op.batch_alter_table("usuarios") as tabla:
        tabla.drop_column("rol")

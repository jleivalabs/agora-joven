-- Base representativa de v1.0.0 / Bloque 7A, antes de la migración 0002.
-- Esquema exacto generado por create_all con el código de 7A (commit c53367f).
-- Datos sintéticos: sin cuentas, correos ni contraseñas reales.
CREATE TABLE aportes (
	id INTEGER NOT NULL,
	debate_id INTEGER NOT NULL,
	autor_id INTEGER NOT NULL,
	tipo VARCHAR(20) NOT NULL,
	texto TEXT NOT NULL,
	creado_en DATETIME NOT NULL,
	editado_en DATETIME,
	PRIMARY KEY (id),
	FOREIGN KEY(debate_id) REFERENCES debates (id),
	FOREIGN KEY(autor_id) REFERENCES usuarios (id)
);
CREATE TABLE debates (
	id INTEGER NOT NULL,
	slug VARCHAR(80) NOT NULL,
	titulo VARCHAR(160) NOT NULL,
	categoria VARCHAR(30) NOT NULL,
	resumen TEXT NOT NULL,
	contexto TEXT NOT NULL,
	perspectivas JSON NOT NULL,
	origen VARCHAR(80) NOT NULL,
	actualizado_en DATETIME NOT NULL,
	PRIMARY KEY (id),
	UNIQUE (slug)
);
CREATE TABLE usuarios (
	id INTEGER NOT NULL,
	nombre VARCHAR(60) NOT NULL,
	email VARCHAR(254) NOT NULL,
	password_hash VARCHAR(255) NOT NULL,
	creado_en DATETIME NOT NULL,
	PRIMARY KEY (id)
);
CREATE INDEX ix_aportes_autor_id ON aportes (autor_id);
CREATE INDEX ix_aportes_debate_orden ON aportes (debate_id, creado_en, id);
CREATE INDEX ix_debates_categoria ON debates (categoria);
CREATE UNIQUE INDEX ix_usuarios_email ON usuarios (email);
INSERT INTO usuarios (id, nombre, email, password_hash, creado_en) VALUES
 (1, 'Ana', 'ana@example.com', '$argon2id$sintetico$ana', '2026-10-20 10:00:00.000000'),
 (2, 'Beto', 'beto@example.com', '$argon2id$sintetico$beto', '2026-10-20 11:00:00.000000'),
 (7, 'Carla', 'carla@example.com', '$argon2id$sintetico$carla', '2026-10-21 09:00:00.000000');
INSERT INTO debates (id, slug, titulo, categoria, resumen, contexto, perspectivas, origen, actualizado_en) VALUES
 (1, 'celulares-en-el-aula', 'Título anterior 1', 'educacion', 'Resumen anterior 1', 'Contexto anterior 1', '[{"titulo": "A", "descripcion": "Descripción A"}, {"titulo": "B", "descripcion": "Descripción B"}]', 'Material editorial de demostración', '2026-10-20 10:00:00.000000'),
 (2, 'educacion-financiera-escolar', 'Título anterior 2', 'educacion', 'Resumen anterior 2', 'Contexto anterior 2', '[{"titulo": "A", "descripcion": "Descripción A"}, {"titulo": "B", "descripcion": "Descripción B"}]', 'Material editorial de demostración', '2026-10-20 10:00:00.000000'),
 (5, 'huertos-urbanos-comunitarios', 'Título anterior 5', 'ambiente', 'Resumen anterior 5', 'Contexto anterior 5', '[{"titulo": "A", "descripcion": "Descripción A"}, {"titulo": "B", "descripcion": "Descripción B"}]', 'Material editorial de demostración', '2026-10-20 10:00:00.000000');
INSERT INTO aportes (id, debate_id, autor_id, tipo, texto, creado_en, editado_en) VALUES
 (1, 1, 1, 'pregunta', 'Aporte sintético uno de la versión anterior.', '2026-10-21 10:00:00.000000', NULL),
 (2, 1, 2, 'argumento', 'Aporte sintético dos de la versión anterior.', '2026-10-21 11:00:00.000000', '2026-10-21 12:00:00.000000'),
 (9, 5, 7, 'propuesta', 'Aporte sintético nueve de la versión anterior.', '2026-10-22 10:00:00.000000', NULL);

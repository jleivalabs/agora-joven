class Categoria {
  const Categoria({
    required this.codigo,
    required this.etiqueta,
    required this.total,
  });

  final String codigo;
  final String etiqueta;
  final int total;

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
    codigo: json['categoria'] as String,
    etiqueta: json['etiqueta'] as String,
    total: json['total'] as int,
  );
}

class DebateResumen {
  const DebateResumen({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.resumen,
    required this.origen,
  });

  final int id;
  final String titulo;
  final String categoria;
  final String resumen;

  /// Procedencia del contenido; en el catálogo inicial, "Material editorial de demostración".
  final String origen;

  factory DebateResumen.fromJson(Map<String, dynamic> json) => DebateResumen(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    categoria: json['categoria'] as String,
    resumen: json['resumen'] as String,
    origen: json['origen'] as String,
  );
}

class Perspectiva {
  const Perspectiva({required this.titulo, required this.descripcion});

  final String titulo;
  final String descripcion;

  factory Perspectiva.fromJson(Map<String, dynamic> json) => Perspectiva(
    titulo: json['titulo'] as String,
    descripcion: json['descripcion'] as String,
  );
}

class DebateDetalle extends DebateResumen {
  const DebateDetalle({
    required super.id,
    required super.titulo,
    required super.categoria,
    required super.resumen,
    required super.origen,
    required this.contexto,
    required this.perspectivas,
  });

  final String contexto;
  final List<Perspectiva> perspectivas;

  factory DebateDetalle.fromJson(Map<String, dynamic> json) => DebateDetalle(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    categoria: json['categoria'] as String,
    resumen: json['resumen'] as String,
    origen: json['origen'] as String,
    contexto: json['contexto'] as String,
    perspectivas: [
      for (final p in json['perspectivas'] as List)
        Perspectiva.fromJson(p as Map<String, dynamic>),
    ],
  );
}

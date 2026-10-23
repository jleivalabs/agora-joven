enum TipoAporte {
  pregunta('Pregunta'),
  argumento('Argumento'),
  propuesta('Propuesta');

  const TipoAporte(this.etiqueta);

  final String etiqueta;

  static TipoAporte desdeCodigo(String codigo) => values.firstWhere(
    (t) => t.name == codigo,
    orElse: () => throw FormatException('Tipo de aporte desconocido: $codigo'),
  );
}

/// Aporte público de un debate. [esPropio] lo calcula el servidor para quien consulta.
class Aporte {
  const Aporte({
    required this.id,
    required this.debateId,
    required this.tipo,
    required this.texto,
    required this.autorNombre,
    required this.creadoEn,
    required this.editadoEn,
    required this.esPropio,
  });

  final int id;
  final int debateId;
  final TipoAporte tipo;
  final String texto;
  final String autorNombre;
  final DateTime creadoEn;
  final DateTime? editadoEn;
  final bool esPropio;

  bool get editado => editadoEn != null;

  factory Aporte.fromJson(Map<String, dynamic> json) => Aporte(
    id: json['id'] as int,
    debateId: json['debate_id'] as int,
    tipo: TipoAporte.desdeCodigo(json['tipo'] as String),
    texto: json['texto'] as String,
    autorNombre: json['autor_nombre'] as String,
    creadoEn: DateTime.parse(json['creado_en'] as String),
    editadoEn: json['editado_en'] == null
        ? null
        : DateTime.parse(json['editado_en'] as String),
    esPropio: json['es_propio'] as bool,
  );
}

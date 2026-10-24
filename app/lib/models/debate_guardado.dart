/// Datos editoriales mínimos de un debate guardado en el dispositivo.
///
/// No incluye tokens, credenciales ni aportes: solo lo necesario para identificar el debate y
/// mostrarlo en la lista de guardados. El detalle se vuelve a pedir al backend.
class DebateGuardado {
  const DebateGuardado({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.etiquetaCategoria,
    required this.guardadoEn,
  });

  final int id;
  final String titulo;
  final String categoria;
  final String etiquetaCategoria;
  final DateTime guardadoEn;

  Map<String, Object> aMapa() => {
    'id': id,
    'titulo': titulo,
    'categoria': categoria,
    'etiqueta_categoria': etiquetaCategoria,
    'guardado_en': guardadoEn.toUtc().toIso8601String(),
  };

  /// Lanza [FormatException] si el registro no tiene la forma esperada.
  factory DebateGuardado.desdeMapa(Map<dynamic, dynamic> mapa) {
    try {
      return DebateGuardado(
        id: mapa['id'] as int,
        titulo: mapa['titulo'] as String,
        categoria: mapa['categoria'] as String,
        etiquetaCategoria: mapa['etiqueta_categoria'] as String,
        guardadoEn: DateTime.parse(mapa['guardado_en'] as String),
      );
    } on TypeError {
      throw const FormatException('Registro de guardado con forma inesperada');
    }
  }
}

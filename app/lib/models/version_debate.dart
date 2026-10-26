import 'borrador.dart';
import 'debate.dart';

/// Límites de una aclaración (iguales en el backend).
class LimitesAclaracion {
  LimitesAclaracion._();

  static const minimo = 10;
  static const maximo = 1000;
}

/// Tipo de versión publicada. `registroInicial`: instantánea tomada al incorporar el historial;
/// no se conservó quién ni por qué se hicieron cambios anteriores.
enum TipoVersion { publicacion, edicion, catalogo, registroInicial }

TipoVersion _tipo(Object? codigo) => switch (codigo) {
  'publicacion' => TipoVersion.publicacion,
  'edicion' => TipoVersion.edicion,
  'catalogo' => TipoVersion.catalogo,
  _ => TipoVersion.registroInicial,
};

String etiquetaTipoVersion(TipoVersion tipo) => switch (tipo) {
  TipoVersion.publicacion => 'Publicación',
  TipoVersion.edicion => 'Edición',
  TipoVersion.catalogo => 'Catálogo editorial',
  TipoVersion.registroInicial => 'Estado registrado al incorporar el historial',
};

/// Nombre legible de cada campo de contenido.
String etiquetaCampo(String campo) => switch (campo) {
  'categoria' => 'Categoría',
  'ambito' => 'Ámbito',
  'titulo' => 'Pregunta',
  'resumen' => 'Resumen',
  'contexto' => 'Contexto',
  'perspectivas' => 'Perspectivas',
  'objetivo' => 'Objetivo',
  _ => campo,
};

class VersionResumen {
  const VersionResumen({
    required this.numero,
    required this.tipo,
    required this.creadaEn,
    required this.camposCambiados,
    required this.esActual,
    this.autorNombre,
    this.motivo,
  });

  final int numero;
  final TipoVersion tipo;
  final DateTime creadaEn;

  /// Quién hizo el cambio y por qué; nulos si no se conservó.
  final String? autorNombre;
  final String? motivo;
  final List<String> camposCambiados;
  final bool esActual;

  factory VersionResumen.fromJson(Map<String, dynamic> json) => VersionResumen(
    numero: json['numero'] as int,
    tipo: _tipo(json['tipo']),
    creadaEn: DateTime.parse(json['creada_en'] as String),
    autorNombre: json['autor_nombre'] as String?,
    motivo: json['motivo'] as String?,
    camposCambiados: [
      for (final c in json['campos_cambiados'] as List) c as String,
    ],
    esActual: json['es_actual'] as bool,
  );
}

/// Diferencia de un campo respecto a la versión anterior.
class CambioCampo {
  const CambioCampo({
    required this.campo,
    required this.antes,
    required this.despues,
  });

  final String campo;
  final String antes;
  final String despues;

  /// Texto legible de un valor (las perspectivas se muestran una por línea).
  static String _legible(Object? valor) {
    if (valor == null) return '(vacío)';
    if (valor is List) {
      return [
        for (final p in valor)
          if (p is Map) '• ${p['titulo']}: ${p['descripcion']}' else '• $p',
      ].join('\n');
    }
    return valor.toString();
  }

  factory CambioCampo.fromJson(Map<String, dynamic> json) {
    final campo = json['campo'] as String;
    String valor(Object? v) =>
        campo == 'categoria' ? etiquetaCategoria('$v') : _legible(v);
    return CambioCampo(
      campo: campo,
      antes: valor(json['antes']),
      despues: valor(json['despues']),
    );
  }
}

class VersionDetalle extends VersionResumen {
  const VersionDetalle({
    required super.numero,
    required super.tipo,
    required super.creadaEn,
    required super.camposCambiados,
    required super.esActual,
    super.autorNombre,
    super.motivo,
    required this.categoria,
    required this.titulo,
    required this.resumen,
    required this.contexto,
    required this.perspectivas,
    required this.cambios,
    this.ambito,
    this.objetivo,
  });

  final String categoria;
  final String? ambito;
  final String titulo;
  final String resumen;
  final String contexto;
  final List<Perspectiva> perspectivas;
  final String? objetivo;
  final List<CambioCampo> cambios;

  factory VersionDetalle.fromJson(Map<String, dynamic> json) {
    final r = VersionResumen.fromJson(json);
    return VersionDetalle(
      numero: r.numero,
      tipo: r.tipo,
      creadaEn: r.creadaEn,
      autorNombre: r.autorNombre,
      motivo: r.motivo,
      camposCambiados: r.camposCambiados,
      esActual: r.esActual,
      categoria: json['categoria'] as String,
      ambito: json['ambito'] as String?,
      titulo: json['titulo'] as String,
      resumen: json['resumen'] as String,
      contexto: json['contexto'] as String,
      perspectivas: [
        for (final p in json['perspectivas'] as List)
          Perspectiva.fromJson(p as Map<String, dynamic>),
      ],
      objetivo: json['objetivo'] as String?,
      cambios: [
        for (final c in json['cambios'] as List)
          CambioCampo.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

/// Aclaración fechada e inmutable del autor de un debate.
class Aclaracion {
  const Aclaracion({
    required this.id,
    required this.texto,
    required this.autorNombre,
    required this.creadaEn,
  });

  final int id;
  final String texto;
  final String autorNombre;
  final DateTime creadaEn;

  factory Aclaracion.fromJson(Map<String, dynamic> json) => Aclaracion(
    id: json['id'] as int,
    texto: json['texto'] as String,
    autorNombre: json['autor_nombre'] as String,
    creadaEn: DateTime.parse(json['creada_en'] as String),
  );
}

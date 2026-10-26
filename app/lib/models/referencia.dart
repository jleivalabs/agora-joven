/// Bloque 7C: referencias bibliográficas (metadatos de Crossref), procedencia de sugerencias de
/// IA aceptadas y redacción pendiente de revisar. Son datos no confiables: se muestran como texto
/// plano y los enlaces se construyen desde el DOI.
library;

final _patronDoi = RegExp(r'^10\.\d{4,9}/[-._;()/:A-Za-z0-9]+$');

/// Enlace seguro de una referencia: solo HTTPS a doi.org desde un DOI válido; si no, null.
Uri? enlaceDoi(String doi) {
  if (!_patronDoi.hasMatch(doi)) return null;
  return Uri(scheme: 'https', host: 'doi.org', path: '/$doi');
}

/// Tipo declarado por el editor en Crossref. No es una valoración de calidad.
String etiquetaTipoReferencia(String tipo) => switch (tipo) {
  'articulo' => 'Artículo',
  'articulo_congreso' => 'Artículo de congreso',
  'capitulo' => 'Capítulo de libro',
  'libro' => 'Libro',
  'informe' => 'Informe',
  'conjunto_datos' => 'Conjunto de datos',
  'preprint' => 'Preprint (sin revisión por pares declarada)',
  'tesis' => 'Tesis',
  _ => 'Tipo no determinado',
};

List<String> _textos(Object? valor) => [
  for (final x in (valor as List?) ?? const []) x as String,
];

class Referencia {
  const Referencia({
    required this.doi,
    required this.titulo,
    required this.tipo,
    required this.consultadaEn,
    this.autores = const [],
    this.fechaPublicacion,
    this.publicacion,
    this.editorial,
    this.mismaObraQue = const [],
  });

  final String doi;
  final String titulo;
  final List<String> autores;
  final String? fechaPublicacion;
  final String tipo;
  final String? publicacion;
  final String? editorial;

  /// DOI de versiones de la misma obra (preprint/artículo): no son corroboraciones independientes.
  final List<String> mismaObraQue;

  /// Fecha en que el servidor consultó Crossref.
  final DateTime consultadaEn;

  /// Siempre construido aquí desde el DOI; nunca se usa un enlace recibido.
  Uri? get enlace => enlaceDoi(doi);

  factory Referencia.fromJson(Map<String, dynamic> json) => Referencia(
    doi: json['doi'] as String,
    titulo: json['titulo'] as String,
    autores: _textos(json['autores']),
    fechaPublicacion: json['fecha_publicacion'] as String?,
    tipo: (json['tipo'] as String?) ?? 'no_determinado',
    publicacion: json['publicacion'] as String?,
    editorial: json['editorial'] as String?,
    mismaObraQue: _textos(json['misma_obra_que']),
    consultadaEn:
        DateTime.tryParse(json['consultada_en'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Procedencia de un texto aceptado a partir de una sugerencia de IA.
class Evidencia {
  const Evidencia({
    required this.id,
    required this.tipo,
    required this.campo,
    required this.textoAceptado,
    required this.editada,
    this.referencias = const [],
    this.requiereRevision = false,
    this.presenteAlPublicar,
  });

  final String id;
  final String tipo;
  final String campo;
  final String textoAceptado;
  final bool editada;
  final List<String> referencias;

  /// Se modificó un texto ligado a fuentes: la relación con la fuente necesita revisión.
  final bool requiereRevision;
  final bool? presenteAlPublicar;

  factory Evidencia.fromJson(Map<String, dynamic> json) => Evidencia(
    id: json['id'] as String,
    tipo: json['tipo'] as String,
    campo: json['campo'] as String,
    textoAceptado: json['texto_aceptado'] as String,
    editada: json['editada'] as bool,
    referencias: _textos(json['referencias']),
    requiereRevision: (json['requiere_revision'] as bool?) ?? false,
    presenteAlPublicar: json['presente_al_publicar'] as bool?,
  );
}

enum TipoSugerencia { contexto, perspectiva, pregunta, afirmacion }

class SugerenciaIA {
  const SugerenciaIA({
    required this.id,
    required this.tipo,
    required this.pendiente,
    required this.aviso,
    this.texto,
    this.titulo,
    this.descripcion,
    this.referencias = const [],
  });

  final String id;
  final TipoSugerencia tipo;
  final bool pendiente;

  /// Aviso del servidor ("pendiente de revisión"): nunca "verificado".
  final String aviso;
  final String? texto;
  final String? titulo;
  final String? descripcion;
  final List<String> referencias;

  factory SugerenciaIA.fromJson(Map<String, dynamic> json) => SugerenciaIA(
    id: json['id'] as String,
    tipo: TipoSugerencia.values.firstWhere(
      (t) => t.name == json['tipo'],
      orElse: () => TipoSugerencia.pregunta,
    ),
    pendiente: json['estado'] == 'pendiente',
    aviso: json['aviso'] as String,
    texto: json['texto'] as String?,
    titulo: json['titulo'] as String?,
    descripcion: json['descripcion'] as String?,
    referencias: _textos(json['referencias']),
  );
}

class Redaccion {
  const Redaccion({
    required this.sugerencias,
    required this.limitaciones,
    required this.desactualizada,
  });

  final List<SugerenciaIA> sugerencias;
  final List<String> limitaciones;

  /// El borrador cambió después de pedirla: está basada en el texto anterior.
  final bool desactualizada;

  List<SugerenciaIA> get pendientes =>
      sugerencias.where((s) => s.pendiente).toList();

  static Redaccion? fromJsonONulo(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return Redaccion(
      sugerencias: [
        for (final s in json['sugerencias'] as List)
          SugerenciaIA.fromJson(s as Map<String, dynamic>),
      ],
      limitaciones: _textos(json['limitaciones']),
      desactualizada: (json['desactualizada'] as bool?) ?? false,
    );
  }
}

class BusquedaReferencias {
  const BusquedaReferencias({
    required this.consulta,
    required this.referencias,
  });

  /// Texto exacto que se envió a Crossref.
  final String consulta;
  final List<Referencia> referencias;

  factory BusquedaReferencias.fromJson(Map<String, dynamic> json) =>
      BusquedaReferencias(
        consulta: json['consulta'] as String,
        referencias: [
          for (final r in json['referencias'] as List)
            Referencia.fromJson(r as Map<String, dynamic>),
        ],
      );
}

class EstadoInvestigacion {
  const EstadoInvestigacion({
    required this.busquedaDisponible,
    required this.redaccionDisponible,
    required this.maxReferencias,
  });

  final bool busquedaDisponible;
  final bool redaccionDisponible;
  final int maxReferencias;

  factory EstadoInvestigacion.fromJson(Map<String, dynamic> json) =>
      EstadoInvestigacion(
        busquedaDisponible: json['busqueda_disponible'] as bool,
        redaccionDisponible: json['redaccion_disponible'] as bool,
        maxReferencias: json['max_referencias'] as int,
      );
}

List<Referencia> referenciasDe(Object? json) => [
  for (final r in (json as List?) ?? const [])
    Referencia.fromJson(r as Map<String, dynamic>),
];

List<Evidencia> evidenciasDe(Object? json) => [
  for (final e in (json as List?) ?? const [])
    Evidencia.fromJson(e as Map<String, dynamic>),
];

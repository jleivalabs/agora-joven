import 'debate.dart';
import 'referencia.dart';
import 'solicitud_archivo.dart';

/// Límites del contenido de un debate (iguales a backend/app/schemas.py → LIMITES).
class LimitesDebate {
  LimitesDebate._();

  static const ambito = (3, 120);
  static const titulo = (10, 160);
  static const resumen = (30, 300);
  static const contexto = (80, 3000);
  static const objetivo = (20, 500);
  static const perspectivaTitulo = (3, 80);
  static const perspectivaDescripcion = (20, 600);
  static const minPerspectivas = 2;
  static const maxPerspectivas = 5;
}

class PerspectivaBorrador {
  const PerspectivaBorrador({this.titulo = '', this.descripcion = ''});

  final String titulo;
  final String descripcion;

  factory PerspectivaBorrador.fromJson(Map<String, dynamic> json) =>
      PerspectivaBorrador(
        titulo: (json['titulo'] as String?) ?? '',
        descripcion: (json['descripcion'] as String?) ?? '',
      );

  Map<String, String> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
  };
}

/// Borrador privado de un debate: todos sus campos pueden estar incompletos.
class Borrador {
  const Borrador({
    required this.id,
    this.categoria,
    this.ambito,
    this.titulo,
    this.resumen,
    this.contexto,
    this.perspectivas = const [],
    this.objetivo,
    this.paso = 1,
    required this.actualizadoEn,
    this.debateId,
    this.referencias = const [],
    this.evidencias = const [],
    this.redaccion,
  });

  final int id;
  final String? categoria;
  final String? ambito;
  final String? titulo;
  final String? resumen;
  final String? contexto;
  final List<PerspectivaBorrador> perspectivas;
  final String? objetivo;
  final int paso;
  final DateTime actualizadoEn;

  /// Debate creado al publicarlo; null mientras sea borrador.
  final int? debateId;

  /// 7C: referencias seleccionadas, procedencia de lo aceptado y redacción pendiente.
  final List<Referencia> referencias;
  final List<Evidencia> evidencias;
  final Redaccion? redaccion;

  factory Borrador.fromJson(Map<String, dynamic> json) => Borrador(
    id: json['id'] as int,
    categoria: json['categoria'] as String?,
    ambito: json['ambito'] as String?,
    titulo: json['titulo'] as String?,
    resumen: json['resumen'] as String?,
    contexto: json['contexto'] as String?,
    perspectivas: [
      for (final p in (json['perspectivas'] as List?) ?? const [])
        PerspectivaBorrador.fromJson(p as Map<String, dynamic>),
    ],
    objetivo: json['objetivo'] as String?,
    paso: json['paso'] as int,
    actualizadoEn: DateTime.parse(json['actualizado_en'] as String),
    debateId: json['debate_id'] as int?,
    referencias: referenciasDe(json['referencias']),
    evidencias: evidenciasDe(json['evidencias']),
    redaccion: Redaccion.fromJsonONulo(json['redaccion']),
  );
}

class MiDebate {
  const MiDebate({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.estado,
    required this.aportes,
    required this.editable,
    this.archivoOrigen,
    this.solicitudArchivo,
  });

  final int id;
  final String titulo;
  final String categoria;
  final EstadoDebate estado;
  final int aportes;
  final bool editable;
  final OrigenArchivo? archivoOrigen;

  /// Última solicitud de archivo de la cuenta para este debate.
  final SolicitudArchivo? solicitudArchivo;

  factory MiDebate.fromJson(Map<String, dynamic> json) => MiDebate(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    categoria: json['categoria'] as String,
    estado: json['estado'] == 'archivado'
        ? EstadoDebate.archivado
        : EstadoDebate.publicado,
    aportes: json['aportes'] as int,
    editable: json['editable'] as bool,
    archivoOrigen: origenArchivo(json['archivo_origen']),
    solicitudArchivo: SolicitudArchivo.fromJsonONulo(json['solicitud_archivo']),
  );
}

class MisDebates {
  const MisDebates({
    required this.borradores,
    required this.publicados,
    required this.archivados,
  });

  final List<Borrador> borradores;
  final List<MiDebate> publicados;
  final List<MiDebate> archivados;

  factory MisDebates.fromJson(Map<String, dynamic> json) => MisDebates(
    borradores: [
      for (final b in json['borradores'] as List)
        Borrador.fromJson(b as Map<String, dynamic>),
    ],
    publicados: [
      for (final d in json['publicados'] as List)
        MiDebate.fromJson(d as Map<String, dynamic>),
    ],
    archivados: [
      for (final d in json['archivados'] as List)
        MiDebate.fromJson(d as Map<String, dynamic>),
    ],
  );
}

/// Categorías existentes (mismo orden y códigos que el servidor) para el asistente.
const categoriasDebate = [
  ('educacion', 'Educación'),
  ('ambiente', 'Ambiente'),
  ('movilidad', 'Movilidad'),
  ('empleo', 'Empleo'),
  ('salud', 'Salud'),
  ('tecnologia', 'Tecnología'),
  ('cultura', 'Cultura'),
  ('participacion', 'Participación'),
];

String etiquetaCategoria(String? codigo) =>
    categoriasDebate
        .where((c) => c.$1 == codigo)
        .map((c) => c.$2)
        .firstOrNull ??
    (codigo ?? '');

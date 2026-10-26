import 'solicitud_archivo.dart';
import 'version_debate.dart';

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

enum Procedencia { editorial, usuario }

enum EstadoDebate { publicado, archivado }

T _enumPorNombre<T extends Enum>(
  List<T> valores,
  Object? nombre,
  T porDefecto,
) {
  if (nombre == null) return porDefecto;
  return valores.firstWhere(
    (v) => v.name == nombre,
    orElse: () => throw FormatException('Valor desconocido: $nombre'),
  );
}

class DebateResumen {
  const DebateResumen({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.resumen,
    required this.origen,
    this.procedencia = Procedencia.editorial,
    this.estado = EstadoDebate.publicado,
    this.autorNombre,
  });

  final int id;
  final String titulo;
  final String categoria;
  final String resumen;

  /// Texto de procedencia ("Material editorial de demostración" o "Debate creado por…").
  final String origen;
  final Procedencia procedencia;
  final EstadoDebate estado;

  /// Nombre visible de quien creó el debate (nunca el correo); null en los editoriales.
  final String? autorNombre;

  bool get esDeUsuario => procedencia == Procedencia.usuario;
  bool get archivado => estado == EstadoDebate.archivado;

  factory DebateResumen.fromJson(Map<String, dynamic> json) => DebateResumen(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    categoria: json['categoria'] as String,
    resumen: json['resumen'] as String,
    origen: json['origen'] as String,
    // Valores por defecto: respuestas anteriores a 7B solo tenían debates editoriales publicados.
    procedencia: _enumPorNombre(
      Procedencia.values,
      json['procedencia'],
      Procedencia.editorial,
    ),
    estado: _enumPorNombre(
      EstadoDebate.values,
      json['estado'],
      EstadoDebate.publicado,
    ),
    autorNombre: json['autor_nombre'] as String?,
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

  Map<String, String> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
  };
}

class DebateDetalle extends DebateResumen {
  const DebateDetalle({
    required super.id,
    required super.titulo,
    required super.categoria,
    required super.resumen,
    required super.origen,
    super.procedencia,
    super.estado,
    super.autorNombre,
    required this.contexto,
    required this.perspectivas,
    this.ambito,
    this.objetivo,
    this.archivadoEn,
    this.aportes = 0,
    this.esPropio = false,
    this.editable = false,
    this.archivoOrigen,
    this.solicitudArchivo,
    this.versionActual,
    this.motivoBloqueo,
    this.aclaraciones = const [],
  });

  final String contexto;
  final List<Perspectiva> perspectivas;
  final String? ambito;
  final String? objetivo;
  final DateTime? archivadoEn;
  final int aportes;

  /// La cuenta de la sesión es la autora (lo calcula el servidor).
  final bool esPropio;

  /// Propio, publicado y sin aportes: se puede editar (el servidor vuelve a comprobarlo).
  final bool editable;

  /// Cómo se archivó (público). Nulo si está publicado.
  final OrigenArchivo? archivoOrigen;

  /// Última solicitud de archivo de la cuenta autora (solo llega en debates propios).
  final SolicitudArchivo? solicitudArchivo;

  /// Versión publicada vigente (7B.1). Los aportes nuevos se publican sobre ella.
  final int? versionActual;

  /// `participacion` o `historico` si el contenido ya no se puede reescribir.
  final String? motivoBloqueo;

  /// Añadidos fechados del autor, en orden cronológico.
  final List<Aclaracion> aclaraciones;

  /// Mismo detalle con otra solicitud (tras solicitar o cancelar, sin recargar todo).
  DebateDetalle conSolicitud(SolicitudArchivo? solicitud) => DebateDetalle(
    id: id,
    titulo: titulo,
    categoria: categoria,
    resumen: resumen,
    origen: origen,
    procedencia: procedencia,
    estado: estado,
    autorNombre: autorNombre,
    contexto: contexto,
    perspectivas: perspectivas,
    ambito: ambito,
    objetivo: objetivo,
    archivadoEn: archivadoEn,
    aportes: aportes,
    esPropio: esPropio,
    editable: editable,
    archivoOrigen: archivoOrigen,
    solicitudArchivo: solicitud,
    versionActual: versionActual,
    motivoBloqueo: motivoBloqueo,
    aclaraciones: aclaraciones,
  );

  /// Mismo detalle con una aclaración más (tras confirmarla el servidor).
  DebateDetalle conAclaracion(Aclaracion aclaracion) => DebateDetalle(
    id: id,
    titulo: titulo,
    categoria: categoria,
    resumen: resumen,
    origen: origen,
    procedencia: procedencia,
    estado: estado,
    autorNombre: autorNombre,
    contexto: contexto,
    perspectivas: perspectivas,
    ambito: ambito,
    objetivo: objetivo,
    archivadoEn: archivadoEn,
    aportes: aportes,
    esPropio: esPropio,
    editable: editable,
    archivoOrigen: archivoOrigen,
    solicitudArchivo: solicitudArchivo,
    versionActual: versionActual,
    motivoBloqueo: motivoBloqueo,
    aclaraciones: [...aclaraciones, aclaracion],
  );

  factory DebateDetalle.fromJson(Map<String, dynamic> json) {
    final resumen = DebateResumen.fromJson(json);
    return DebateDetalle(
      id: resumen.id,
      titulo: resumen.titulo,
      categoria: resumen.categoria,
      resumen: resumen.resumen,
      origen: resumen.origen,
      procedencia: resumen.procedencia,
      estado: resumen.estado,
      autorNombre: resumen.autorNombre,
      contexto: json['contexto'] as String,
      perspectivas: [
        for (final p in json['perspectivas'] as List)
          Perspectiva.fromJson(p as Map<String, dynamic>),
      ],
      ambito: json['ambito'] as String?,
      objetivo: json['objetivo'] as String?,
      archivadoEn: json['archivado_en'] == null
          ? null
          : DateTime.parse(json['archivado_en'] as String),
      aportes: (json['aportes'] as int?) ?? 0,
      esPropio: (json['es_propio'] as bool?) ?? false,
      editable: (json['editable'] as bool?) ?? false,
      archivoOrigen: origenArchivo(json['archivo_origen']),
      solicitudArchivo: SolicitudArchivo.fromJsonONulo(
        json['solicitud_archivo'],
      ),
      versionActual: json['version_actual'] as int?,
      motivoBloqueo: json['motivo_bloqueo'] as String?,
      aclaraciones: [
        for (final a in (json['aclaraciones'] as List?) ?? const [])
          Aclaracion.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}

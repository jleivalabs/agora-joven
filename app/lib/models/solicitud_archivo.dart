import 'debate.dart';

/// Límites del motivo de una solicitud, de una justificación y de un archivo directo
/// (iguales en el backend).
class LimitesMotivo {
  LimitesMotivo._();

  static const minimo = 10;
  static const maximo = 500;
}

enum EstadoSolicitud { pendiente, aprobada, rechazada, cancelada }

/// Cómo se archivó un debate. Es público: explica el archivo sin datos internos de revisión.
enum OrigenArchivo { anterior, solicitud, administracion }

T? _enumONulo<T extends Enum>(List<T> valores, Object? nombre) =>
    valores.where((v) => v.name == nombre).firstOrNull;

DateTime? _fecha(Object? valor) =>
    valor == null ? null : DateTime.parse(valor as String);

OrigenArchivo? origenArchivo(Object? nombre) =>
    _enumONulo(OrigenArchivo.values, nombre);

/// Explicación pública de un debate archivado (para todas las cuentas).
String explicacionArchivo(OrigenArchivo? origen) => switch (origen) {
  OrigenArchivo.solicitud => 'Archivado a petición de quien lo creó, tras la revisión de la administración.',
  OrigenArchivo.administracion => 'Archivado por la administración.',
  OrigenArchivo.anterior => 'Archivado por quien lo creó antes de que existiera la revisión de archivos.',
  null => 'Debate archivado.',
};

String etiquetaSolicitud(EstadoSolicitud estado) => switch (estado) {
  EstadoSolicitud.pendiente => 'Solicitud de archivo pendiente de revisión',
  EstadoSolicitud.aprobada => 'Solicitud de archivo aprobada',
  EstadoSolicitud.rechazada => 'Solicitud de archivo rechazada',
  EstadoSolicitud.cancelada => 'Solicitud de archivo cancelada',
};

/// Solicitud vista por quien la hizo: estado y respuesta, sin datos de quien la revisó.
class SolicitudArchivo {
  const SolicitudArchivo({
    required this.id,
    required this.debateId,
    required this.motivo,
    required this.estado,
    required this.creadaEn,
    this.resueltaEn,
    this.respuesta,
  });

  final int id;
  final int debateId;
  final String motivo;
  final EstadoSolicitud estado;
  final DateTime creadaEn;
  final DateTime? resueltaEn;

  /// Justificación de la administración al resolverla.
  final String? respuesta;

  bool get pendiente => estado == EstadoSolicitud.pendiente;

  static SolicitudArchivo? fromJsonONulo(Object? json) => json == null
      ? null
      : SolicitudArchivo.fromJson(json as Map<String, dynamic>);

  factory SolicitudArchivo.fromJson(Map<String, dynamic> json) =>
      SolicitudArchivo(
        id: json['id'] as int,
        debateId: json['debate_id'] as int,
        motivo: json['motivo'] as String,
        estado:
            _enumONulo(EstadoSolicitud.values, json['estado']) ??
            EstadoSolicitud.pendiente,
        creadaEn: DateTime.parse(json['creada_en'] as String),
        resueltaEn: _fecha(json['resuelta_en']),
        respuesta: json['respuesta'] as String?,
      );
}

/// Registro completo de una solicitud, solo para la administración (sin correos).
class SolicitudAdmin {
  const SolicitudAdmin({
    required this.id,
    required this.estado,
    required this.motivo,
    required this.creadaEn,
    required this.solicitanteNombre,
    required this.debateId,
    required this.debateTitulo,
    required this.debateCategoria,
    required this.debateEstado,
    required this.debateResumen,
    required this.debateAportes,
    this.resueltaEn,
    this.justificacion,
    this.revisorNombre,
  });

  final int id;
  final EstadoSolicitud estado;
  final String motivo;
  final DateTime creadaEn;
  final DateTime? resueltaEn;
  final String? justificacion;
  final String solicitanteNombre;
  final String? revisorNombre;
  final int debateId;
  final String debateTitulo;
  final String debateCategoria;
  final EstadoDebate debateEstado;
  final String debateResumen;
  final int debateAportes;

  factory SolicitudAdmin.fromJson(Map<String, dynamic> json) {
    final debate = json['debate'] as Map<String, dynamic>;
    return SolicitudAdmin(
      id: json['id'] as int,
      estado:
          _enumONulo(EstadoSolicitud.values, json['estado']) ??
          EstadoSolicitud.pendiente,
      motivo: json['motivo'] as String,
      creadaEn: DateTime.parse(json['creada_en'] as String),
      resueltaEn: _fecha(json['resuelta_en']),
      justificacion: json['justificacion'] as String?,
      solicitanteNombre: json['solicitante_nombre'] as String,
      revisorNombre: json['revisor_nombre'] as String?,
      debateId: debate['id'] as int,
      debateTitulo: debate['titulo'] as String,
      debateCategoria: debate['categoria'] as String,
      debateEstado: json['debate_estado'] == 'archivado'
          ? EstadoDebate.archivado
          : EstadoDebate.publicado,
      debateResumen: json['debate_resumen'] as String,
      debateAportes: json['debate_aportes'] as int,
    );
  }
}

import 'dart:async';

import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/debate.dart';
import '../repositories/debates_repository.dart';
import '../repositories/solicitudes_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_comunidad.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Detalle de un debate. Se crea una instancia por pantalla (etiqueta = id).
class DetalleDebateController extends GetxController {
  DetalleDebateController(
    this._repositorio,
    this._sesion,
    this.debateId, {
    this.actividad,
    this.solicitudes,
  });

  final DebatesRepository _repositorio;
  final SesionController _sesion;
  final int debateId;
  final ActividadComunidad? actividad;

  /// Necesario para solicitar o cancelar el archivo (la pantalla lo inyecta).
  final SolicitudesRepository? solicitudes;

  final estado = EstadoCarga.cargando.obs;
  final debate = Rxn<DebateDetalle>();
  final error = RxnString();
  final noEncontrado = false.obs;

  /// Hay una acción de archivo en curso: evita envíos duplicados.
  final procesando = false.obs;

  int _peticion = 0;
  bool _activo = true;

  @override
  void onClose() {
    _activo = false;
    super.onClose();
  }

  /// Sustituye el detalle tras una edición confirmada por el servidor.
  void reemplazar(DebateDetalle editado) {
    debate.value = editado;
    estado.value = EstadoCarga.listo;
  }

  /// Solo decide qué opciones se muestran; el servidor comprueba el rol en cada acción.
  bool get esAdministrador => _sesion.usuario.value?.esAdministrador ?? false;

  /// El autor pide archivar su debate. No lo archiva: queda pendiente de revisión.
  Future<String?> solicitarArchivo(String motivo) => _accion(
    (token) => solicitudes!.solicitar(token, debateId, motivo),
    (solicitud) {
      debate.value = debate.value?.conSolicitud(solicitud);
      return 'Solicitud enviada. La administración la revisará; mientras tanto el '
          'debate sigue abierto.';
    },
    prohibido: 'Solo quien creó este debate puede solicitar su archivo.',
    conflicto: 'Este debate ya está archivado.',
  );

  Future<String?> cancelarSolicitud() {
    final solicitud = debate.value?.solicitudArchivo;
    if (solicitud == null || !solicitud.pendiente) return Future.value();
    return _accion(
      (token) => solicitudes!.cancelar(token, solicitud.id),
      (cancelada) {
        debate.value = debate.value?.conSolicitud(cancelada);
        return 'Solicitud de archivo cancelada.';
      },
      prohibido: 'No se pudo cancelar la solicitud.',
      conflicto: 'La solicitud ya se había resuelto.',
    );
  }

  /// Archivo directo de la administración, con motivo obligatorio.
  Future<String?> archivarComoAdministracion(String motivo) => _accion(
    (token) => _repositorio.archivar(token, debateId, motivo),
    (archivado) {
      debate.value = archivado;
      return 'Debate archivado. Sigue disponible para consulta.';
    },
    prohibido: 'Esta acción está reservada a la administración.',
    conflicto: 'Este debate ya está archivado.',
  );

  /// Ejecuta una acción de archivo una sola vez a la vez, descarta respuestas de otra sesión o
  /// de una pantalla cerrada y, tras un conflicto, recarga el estado real del servidor.
  Future<String?> _accion<T>(
    Future<T> Function(String token) operacion,
    String Function(T resultado) aplicar, {
    required String prohibido,
    required String conflicto,
  }) async {
    if (procesando.value) return null;
    procesando.value = true;
    try {
      final resultado = await _sesion.ejecutar(operacion);
      if (!_activo) return null;
      final mensaje = aplicar(resultado);
      actividad?.avisar();
      return mensaje;
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      if (e.tipo == TipoError.conflicto) unawaited(cargar());
      return switch (e.tipo) {
        TipoError.prohibido => prohibido,
        TipoError.conflicto => conflicto,
        TipoError.noEncontrado => 'Este debate ya no está disponible.',
        _ => 'No se pudo completar la acción. ${mensajeDeError(e)}',
      };
    } finally {
      if (_activo) procesando.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    cargar();
  }

  Future<void> cargar() async {
    final peticion = ++_peticion;
    estado.value = EstadoCarga.cargando;
    error.value = null;
    noEncontrado.value = false;

    try {
      final resultado = await _sesion.ejecutar(
        (token) => _repositorio.detalle(token, debateId),
      );
      if (!_activo || peticion != _peticion) return;
      debate.value = resultado;
      estado.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      noEncontrado.value = e.tipo == TipoError.noEncontrado;
      error.value = noEncontrado.value
          ? 'Este debate no existe o ya no está disponible.'
          : mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }
}

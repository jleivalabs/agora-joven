import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/asistente.dart';
import '../repositories/asistente_repository.dart';
import '../utils/mensajes_error.dart';
import 'sesion_controller.dart';

enum EstadoAsistente { inicial, cargando, listo, sinAportes, error }

/// Asistente de un debate. Una instancia por pantalla de detalle (etiqueta = id del debate).
///
/// Una sola consulta a la vez. Las respuestas se descartan si cambió la sesión (contador de
/// [SesionController.ejecutar]), si la pantalla se cerró ([_activo]) o si llegó una consulta
/// posterior ([_peticion]). No se reintenta solo: el reintento es una acción de la persona.
class AsistenteController extends GetxController {
  AsistenteController(this._repositorio, this._sesion, this.debateId);

  final AsistenteRepository _repositorio;
  final SesionController _sesion;
  final int debateId;

  final estado = EstadoAsistente.inicial.obs;
  final accion = Rxn<AccionAsistente>();
  final respuesta = Rxn<RespuestaAsistente>();
  final error = RxnString();

  int _peticion = 0;
  bool _activo = true;

  @override
  void onClose() {
    _activo = false;
    super.onClose();
  }

  Future<void> consultar(AccionAsistente nueva) async {
    if (estado.value == EstadoAsistente.cargando) return;
    final peticion = ++_peticion;
    accion.value = nueva;
    respuesta.value = null;
    error.value = null;
    estado.value = EstadoAsistente.cargando;

    try {
      final resultado = await _sesion.ejecutar(
        (token) => _repositorio.consultar(token, debateId, nueva),
      );
      if (!_activo || peticion != _peticion) return;
      respuesta.value = resultado;
      estado.value = resultado.sinAportes
          ? EstadoAsistente.sinAportes
          : EstadoAsistente.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      error.value = _mensaje(e);
      estado.value = EstadoAsistente.error;
    }
  }

  /// Repite la última acción, solo cuando la persona lo pide.
  Future<void> reintentar() async {
    final ultima = accion.value;
    if (ultima != null) await consultar(ultima);
  }

  static String _mensaje(ApiException e) {
    return switch (e.codigo) {
      503 =>
        'El asistente no está disponible en este momento. Inténtalo más tarde.',
      502 => 'El asistente no pudo generar una respuesta adecuada. Puedes intentarlo de nuevo.',
      429 => 'Se alcanzó el límite de uso del asistente. Inténtalo más tarde.',
      404 => 'Este debate ya no está disponible.',
      _ => mensajeDeError(e),
    };
  }
}

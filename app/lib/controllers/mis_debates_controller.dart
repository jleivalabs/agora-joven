import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/borrador.dart';
import '../repositories/borradores_repository.dart';
import '../repositories/debates_repository.dart';
import '../repositories/solicitudes_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_comunidad.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// "Mis debates": borradores, publicados y archivados de la cuenta de la sesión.
class MisDebatesController extends GetxController {
  MisDebatesController(
    this._debates,
    this._borradores,
    this._sesion, [
    this._actividad,
    this._solicitudes,
  ]);

  final DebatesRepository _debates;
  final BorradoresRepository _borradores;
  final SesionController _sesion;
  final ActividadComunidad? _actividad;
  final SolicitudesRepository? _solicitudes;

  final estado = EstadoCarga.cargando.obs;
  final datos = Rxn<MisDebates>();
  final error = RxnString();
  final eliminando = <int>{}.obs;

  /// Solicitudes de archivo que se están cancelando (evita envíos duplicados).
  final cancelando = <int>{}.obs;

  int _peticion = 0;
  bool _activo = true;
  Worker? _cambios;

  @override
  void onInit() {
    super.onInit();
    cargar();
    final actividad = _actividad;
    if (actividad != null) {
      _cambios = ever<int>(actividad.cambios, (_) => cargar());
    }
  }

  @override
  void onClose() {
    _activo = false;
    _cambios?.dispose();
    super.onClose();
  }

  Future<void> cargar() async {
    final peticion = ++_peticion;
    if (datos.value == null) estado.value = EstadoCarga.cargando;
    try {
      final resultado = await _sesion.ejecutar(_debates.misDebates);
      if (!_activo || peticion != _peticion) return;
      datos.value = resultado;
      error.value = null;
      estado.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      datos.value = null;
      error.value = mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }

  /// Elimina un borrador propio (la confirmación la pide la pantalla). Devuelve el mensaje.
  Future<String?> eliminarBorrador(int id) async {
    if (eliminando.contains(id)) return null;
    eliminando.add(id);
    try {
      await _sesion.ejecutar((t) => _borradores.eliminar(t, id));
      if (!_activo) return null;
      _actividad?.avisar();
      await cargar();
      return 'Borrador eliminado.';
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      return switch (e.tipo) {
        TipoError.noEncontrado => 'Este borrador ya no existe.',
        TipoError.conflicto => 'Este borrador ya se publicó.',
        _ => 'No se pudo eliminar el borrador. ${mensajeDeError(e)}',
      };
    } finally {
      if (_activo) eliminando.remove(id);
    }
  }

  /// Cancela una solicitud de archivo pendiente propia. Devuelve el mensaje.
  Future<String?> cancelarSolicitud(int solicitudId) async {
    if (cancelando.contains(solicitudId)) return null;
    cancelando.add(solicitudId);
    try {
      await _sesion.ejecutar((t) => _solicitudes!.cancelar(t, solicitudId));
      if (!_activo) return null;
      _actividad?.avisar();
      await cargar();
      return 'Solicitud de archivo cancelada.';
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      if (e.tipo == TipoError.conflicto) await cargar();
      return switch (e.tipo) {
        TipoError.conflicto => 'La solicitud ya se había resuelto.',
        TipoError.noEncontrado => 'Esta solicitud ya no está disponible.',
        _ => 'No se pudo cancelar la solicitud. ${mensajeDeError(e)}',
      };
    } finally {
      if (_activo) cancelando.remove(solicitudId);
    }
  }
}

import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/solicitud_archivo.dart';
import '../repositories/solicitudes_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_comunidad.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Administración: solicitudes de archivo pendientes y su resolución.
///
/// Que la sección se muestre solo a administradores es una comodidad de la interfaz; el
/// servidor rechaza con 403 a cualquier otra cuenta.
class AdminSolicitudesController extends GetxController {
  AdminSolicitudesController(
    this._repositorio,
    this._sesion, [
    this._actividad,
  ]);

  final SolicitudesRepository _repositorio;
  final SesionController _sesion;
  final ActividadComunidad? _actividad;

  final estado = EstadoCarga.cargando.obs;
  final pendientes = <SolicitudAdmin>[].obs;
  final error = RxnString();

  /// Solicitudes con una resolución en curso (evita aprobar o rechazar dos veces).
  final resolviendo = <int>{}.obs;

  int _peticion = 0;
  bool _activo = true;

  @override
  void onInit() {
    super.onInit();
    cargar();
  }

  @override
  void onClose() {
    _activo = false;
    super.onClose();
  }

  Future<void> cargar() async {
    final peticion = ++_peticion;
    if (pendientes.isEmpty) estado.value = EstadoCarga.cargando;
    try {
      final resultado = await _sesion.ejecutar(_repositorio.pendientes);
      if (!_activo || peticion != _peticion) return;
      pendientes.assignAll(resultado);
      error.value = null;
      estado.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      pendientes.clear();
      error.value = e.tipo == TipoError.prohibido
          ? 'Tu cuenta no tiene permisos de administración.'
          : mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }

  SolicitudAdmin? buscar(int id) =>
      pendientes.where((s) => s.id == id).firstOrNull;

  /// Aprueba (archiva el debate) o rechaza. Devuelve (resuelta, mensaje); resuelta indica que
  /// la solicitud ya no está pendiente, aunque la hubiera resuelto otra persona.
  Future<(bool, String)?> resolver(
    int id, {
    required bool aprobar,
    required String justificacion,
  }) async {
    if (resolviendo.contains(id)) return null;
    resolviendo.add(id);
    try {
      await _sesion.ejecutar(
        (t) => _repositorio.resolver(
          t,
          id,
          aprobar: aprobar,
          justificacion: justificacion,
        ),
      );
      if (!_activo) return null;
      pendientes.removeWhere((s) => s.id == id);
      _actividad?.avisar();
      return (
        true,
        aprobar
            ? 'Solicitud aprobada: el debate quedó archivado.'
            : 'Solicitud rechazada: el debate sigue activo.',
      );
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      if (e.tipo == TipoError.conflicto) {
        await cargar();
        return (
          true,
          'Esta solicitud ya se había resuelto o cancelado. Lista actualizada.',
        );
      }
      return (
        false,
        switch (e.tipo) {
          TipoError.prohibido =>
            'Tu cuenta no tiene permisos de administración.',
          TipoError.noEncontrado => 'Esta solicitud ya no existe.',
          _ => 'No se pudo resolver la solicitud. ${mensajeDeError(e)}',
        },
      );
    } finally {
      if (_activo) resolviendo.remove(id);
    }
  }
}

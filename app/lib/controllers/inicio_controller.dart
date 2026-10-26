import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/estadisticas.dart';
import '../repositories/estadisticas_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_comunidad.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Datos del dashboard: comunidad y participación personal, cada sección con su propio estado.
///
/// Un fallo nunca se muestra como cero: la sección pasa a error con "Reintentar". Las respuestas
/// de sesiones anteriores ([SesionController.ejecutar]), de cargas superadas o posteriores al
/// cierre de la pantalla se descartan.
class InicioController extends GetxController {
  InicioController(this._repositorio, this._sesion, [this._actividad]);

  final EstadisticasRepository _repositorio;
  final SesionController _sesion;
  final ActividadComunidad? _actividad;

  final estadoComunidad = EstadoCarga.cargando.obs;
  final comunidad = Rxn<EstadisticasComunidad>();
  final errorComunidad = RxnString();

  final estadoMias = EstadoCarga.cargando.obs;
  final mias = Rxn<EstadisticasPersonales>();
  final errorMias = RxnString();

  int _peticionComunidad = 0;
  int _peticionMias = 0;
  bool _activo = true;
  Worker? _cambiosAportes;

  @override
  void onInit() {
    super.onInit();
    cargar();
    final actividad = _actividad;
    if (actividad != null) {
      _cambiosAportes = ever<int>(actividad.cambios, (_) => cargar());
    }
  }

  @override
  void onClose() {
    _activo = false;
    _cambiosAportes?.dispose();
    super.onClose();
  }

  Future<void> cargar() => Future.wait([cargarComunidad(), cargarMias()]);

  Future<void> cargarComunidad() async {
    final peticion = ++_peticionComunidad;
    if (comunidad.value == null) estadoComunidad.value = EstadoCarga.cargando;
    try {
      final datos = await _sesion.ejecutar(_repositorio.comunidad);
      if (!_activo || peticion != _peticionComunidad) return;
      comunidad.value = datos;
      errorComunidad.value = null;
      estadoComunidad.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticionComunidad) return;
      comunidad.value = null;
      errorComunidad.value = mensajeDeError(e);
      estadoComunidad.value = EstadoCarga.error;
    }
  }

  Future<void> cargarMias() async {
    final peticion = ++_peticionMias;
    if (mias.value == null) estadoMias.value = EstadoCarga.cargando;
    try {
      final datos = await _sesion.ejecutar(_repositorio.mias);
      if (!_activo || peticion != _peticionMias) return;
      mias.value = datos;
      errorMias.value = null;
      estadoMias.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticionMias) return;
      mias.value = null;
      errorMias.value = mensajeDeError(e);
      estadoMias.value = EstadoCarga.error;
    }
  }
}

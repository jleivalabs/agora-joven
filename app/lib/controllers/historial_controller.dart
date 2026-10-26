import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/version_debate.dart';
import '../repositories/debates_repository.dart';
import '../utils/mensajes_error.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Lista de versiones publicadas de un debate (una instancia por pantalla).
class HistorialController extends GetxController {
  HistorialController(this._repositorio, this._sesion, this.debateId);

  final DebatesRepository _repositorio;
  final SesionController _sesion;
  final int debateId;

  final estado = EstadoCarga.cargando.obs;
  final versiones = <VersionResumen>[].obs;
  final error = RxnString();

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
    estado.value = EstadoCarga.cargando;
    try {
      final resultado = await _sesion.ejecutar(
        (t) => _repositorio.versiones(t, debateId),
      );
      if (!_activo || peticion != _peticion) return;
      versiones.assignAll(resultado);
      error.value = null;
      estado.value = resultado.isEmpty ? EstadoCarga.vacio : EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      versiones.clear();
      error.value = e.tipo == TipoError.noEncontrado
          ? 'Este debate no existe o ya no está disponible.'
          : mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }
}

/// Una versión concreta con sus diferencias respecto a la anterior.
class VersionController extends GetxController {
  VersionController(
    this._repositorio,
    this._sesion,
    this.debateId,
    this.numero,
  );

  final DebatesRepository _repositorio;
  final SesionController _sesion;
  final int debateId;
  final int numero;

  final estado = EstadoCarga.cargando.obs;
  final version = Rxn<VersionDetalle>();
  final error = RxnString();

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
    estado.value = EstadoCarga.cargando;
    try {
      final resultado = await _sesion.ejecutar(
        (t) => _repositorio.version(t, debateId, numero),
      );
      if (!_activo || peticion != _peticion) return;
      version.value = resultado;
      error.value = null;
      estado.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      error.value = e.tipo == TipoError.noEncontrado
          ? 'Esta versión no existe.'
          : mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }
}

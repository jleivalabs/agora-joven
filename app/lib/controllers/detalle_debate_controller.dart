import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/debate.dart';
import '../repositories/debates_repository.dart';
import '../utils/mensajes_error.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Detalle de un debate. Se crea una instancia por pantalla (etiqueta = id).
class DetalleDebateController extends GetxController {
  DetalleDebateController(this._repositorio, this._sesion, this.debateId);

  final DebatesRepository _repositorio;
  final SesionController _sesion;
  final int debateId;

  final estado = EstadoCarga.cargando.obs;
  final debate = Rxn<DebateDetalle>();
  final error = RxnString();
  final noEncontrado = false.obs;

  int _peticion = 0;

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
      if (peticion != _peticion) return;
      debate.value = resultado;
      estado.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (peticion != _peticion) return;
      noEncontrado.value = e.tipo == TipoError.noEncontrado;
      error.value = noEncontrado.value
          ? 'Este debate no existe o ya no está disponible.'
          : mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }
}

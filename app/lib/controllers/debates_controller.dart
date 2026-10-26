import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/debate.dart';
import '../repositories/debates_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_comunidad.dart';
import 'sesion_controller.dart';

enum EstadoCarga { cargando, listo, vacio, error }

/// Catálogo de debates con filtro por categoría.
class DebatesController extends GetxController {
  DebatesController(this._repositorio, this._sesion, [this._actividad]);

  /// Si se indica, el catálogo se recarga al publicarse, editarse o archivarse un debate.
  final ActividadComunidad? _actividad;
  Worker? _cambios;

  final DebatesRepository _repositorio;
  final SesionController _sesion;

  final estado = EstadoCarga.cargando.obs;
  final debates = <DebateResumen>[].obs;
  final categorias = <Categoria>[].obs;

  /// Código de la categoría elegida; null es "Todas".
  final seleccion = RxnString();
  final error = RxnString();

  /// Identifica la última petición de lista: las anteriores se descartan al llegar.
  int _peticion = 0;

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
    _cambios?.dispose();
    super.onClose();
  }

  Future<void> cargar() => Future.wait([_cargarCategorias(), _cargarDebates()]);

  void seleccionar(String? categoria) {
    if (categoria == seleccion.value) return;
    seleccion.value = categoria;
    _cargarDebates();
  }

  String etiqueta(String codigo) =>
      categorias.firstWhereOrNull((c) => c.codigo == codigo)?.etiqueta ??
      codigo;

  Future<void> _cargarCategorias() async {
    try {
      categorias.assignAll(await _sesion.ejecutar(_repositorio.categorias));
    } on SesionObsoleta {
      return;
    } on ApiException {
      // Sin categorías se muestra solo "Todas"; la lista informa del error si lo hay.
    }
  }

  Future<void> _cargarDebates() async {
    final peticion = ++_peticion;
    final categoria = seleccion.value;
    estado.value = EstadoCarga.cargando;
    error.value = null;

    try {
      final resultado = await _sesion.ejecutar(
        (token) => _repositorio.listar(token, categoria: categoria),
      );
      if (peticion != _peticion) return;
      debates.assignAll(resultado);
      estado.value = resultado.isEmpty ? EstadoCarga.vacio : EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (peticion != _peticion) return;
      debates.clear();
      error.value = mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }
}

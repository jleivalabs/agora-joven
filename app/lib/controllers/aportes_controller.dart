import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/aporte.dart';
import '../repositories/aportes_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_aportes.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Aportes de un debate. Una instancia por pantalla de detalle (etiqueta = id del debate).
///
/// Toda operación pasa por [SesionController.ejecutar] (contador de sesión y 401). Además,
/// si la pantalla se cierra, [_activo] impide aplicar respuestas que lleguen después.
class AportesController extends GetxController {
  AportesController(
    this._repositorio,
    this._sesion,
    this.debateId, {
    this.actividad,
  });

  final AportesRepository _repositorio;
  final SesionController _sesion;
  final int debateId;

  /// Avisa al dashboard cuando el servidor confirma un cambio de aportes.
  final ActividadAportes? actividad;

  final estado = EstadoCarga.cargando.obs;
  final aportes = <Aporte>[].obs;
  final error = RxnString();

  /// Publicación o edición en curso (formulario).
  final enviando = false.obs;
  final errorFormulario = RxnString();

  /// Aportes cuya eliminación espera confirmación del servidor.
  final eliminando = <int>{}.obs;

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
    // Si ya hay aportes a la vista, se mantienen mientras se actualiza.
    if (aportes.isEmpty) estado.value = EstadoCarga.cargando;
    error.value = null;

    try {
      final resultado = await _sesion.ejecutar(
        (token) => _repositorio.listar(token, debateId),
      );
      if (!_activo || peticion != _peticion) return;
      aportes.assignAll(resultado);
      _actualizarEstado();
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo || peticion != _peticion) return;
      aportes.clear();
      error.value = mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }

  void prepararFormulario() {
    if (!enviando.value) errorFormulario.value = null;
  }

  /// Publica un aporte. No se reintenta solo: si la respuesta se pierde, el servidor pudo
  /// haberlo guardado, así que se pide actualizar la lista antes de repetir.
  Future<bool> publicar(TipoAporte tipo, String texto) {
    return _enviarFormulario(
      (token) =>
          _repositorio.crear(token, debateId, tipo: tipo, texto: texto.trim()),
      mensajeError: (e) => switch (e.tipo) {
        TipoError.sinConexion || TipoError.tiempoAgotado =>
          'No se pudo confirmar la publicación. Es posible que se haya guardado: '
              'actualiza los aportes antes de volver a intentarlo.',
        TipoError.noEncontrado => 'Este debate ya no está disponible.',
        TipoError.validacion =>
          'Revisa el tipo y el texto (entre 10 y 1000 caracteres).',
        _ => mensajeDeError(e),
      },
    );
  }

  /// Edita un aporte propio enviando solo lo que cambió.
  Future<bool> editar(Aporte original, TipoAporte tipo, String texto) async {
    final limpio = texto.trim();
    final nuevoTipo = tipo == original.tipo ? null : tipo;
    final nuevoTexto = limpio == original.texto ? null : limpio;
    if (nuevoTipo == null && nuevoTexto == null) return true;

    return _enviarFormulario(
      (token) => _repositorio.editar(
        token,
        original.id,
        tipo: nuevoTipo,
        texto: nuevoTexto,
      ),
      mensajeError: (e) => switch (e.tipo) {
        TipoError.prohibido =>
          'Solo quien escribió este aporte puede editarlo.',
        TipoError.noEncontrado => 'Este aporte ya no existe.',
        TipoError.sinConexion || TipoError.tiempoAgotado =>
          'No se pudo confirmar el cambio. Actualiza los aportes para ver su '
              'estado antes de repetirlo.',
        TipoError.validacion =>
          'Revisa el tipo y el texto (entre 10 y 1000 caracteres).',
        _ => mensajeDeError(e),
      },
      siNoExiste: original.id,
    );
  }

  /// Elimina un aporte propio. Solo lo retira de la lista cuando el servidor lo confirma.
  /// Devuelve el mensaje para la persona, o null si la operación se descartó.
  Future<String?> eliminar(Aporte aporte) async {
    if (eliminando.contains(aporte.id)) return null;
    eliminando.add(aporte.id);
    try {
      await _sesion.ejecutar(
        (token) => _repositorio.eliminar(token, aporte.id),
      );
      if (!_activo) return null;
      _quitar(aporte.id);
      actividad?.avisar();
      return 'Aporte eliminado.';
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      if (e.tipo == TipoError.noEncontrado) {
        // El servidor confirma que ya no existe: se retira de la lista.
        _quitar(aporte.id);
        actividad?.avisar();
        return 'Este aporte ya no existía.';
      }
      return switch (e.tipo) {
        TipoError.prohibido =>
          'Solo quien escribió este aporte puede eliminarlo.',
        TipoError.sinConexion || TipoError.tiempoAgotado =>
          'No se pudo confirmar la eliminación. Actualiza los aportes para '
              'comprobarlo.',
        _ => mensajeDeError(e),
      };
    } finally {
      if (_activo) eliminando.remove(aporte.id);
    }
  }

  Future<bool> _enviarFormulario(
    Future<Aporte> Function(String token) operacion, {
    required String Function(ApiException e) mensajeError,
    int? siNoExiste,
  }) async {
    if (enviando.value) return false;
    enviando.value = true;
    errorFormulario.value = null;
    try {
      final aporte = await _sesion.ejecutar(operacion);
      if (!_activo) return false;
      _colocar(aporte);
      actividad?.avisar();
      return true;
    } on SesionObsoleta {
      return false;
    } on ApiException catch (e) {
      if (!_activo) return false;
      if (e.tipo == TipoError.noEncontrado && siNoExiste != null) {
        _quitar(siNoExiste);
      }
      errorFormulario.value = mensajeError(e);
      return false;
    } finally {
      if (_activo) enviando.value = false;
    }
  }

  /// Reemplaza por id o inserta al principio: nunca duplica.
  void _colocar(Aporte aporte) {
    final i = aportes.indexWhere((a) => a.id == aporte.id);
    if (i >= 0) {
      aportes[i] = aporte;
    } else {
      aportes.insert(0, aporte);
    }
    _actualizarEstado();
  }

  void _quitar(int id) {
    aportes.removeWhere((a) => a.id == id);
    _actualizarEstado();
  }

  void _actualizarEstado() {
    estado.value = aportes.isEmpty ? EstadoCarga.vacio : EstadoCarga.listo;
  }
}

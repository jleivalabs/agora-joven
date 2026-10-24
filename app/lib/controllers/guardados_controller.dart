import 'package:get/get.dart';

import '../data/guardados_local.dart';
import '../models/debate.dart';
import '../models/debate_guardado.dart';
import '../models/usuario.dart';
import '../repositories/guardados_repository.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Debates guardados de la cuenta activa, compartidos por el catálogo, el detalle y la
/// pantalla Guardados.
///
/// Cambio de cuenta: al cambiar el usuario de la sesión se limpia el estado visible y se cargan
/// solo los guardados de la nueva cuenta. Cada operación captura [_cuenta] al empezar y solo
/// aplica su resultado si la cuenta no cambió. (Una escritura ya iniciada termina en la caja de
/// la cuenta que la pidió, nunca en la de otra.) Las lecturas se numeran con [_lectura] para que
/// una antigua no pise a una reciente.
class GuardadosController extends GetxController {
  GuardadosController(this._repositorio, this._sesion);

  final GuardadosRepository _repositorio;
  final SesionController _sesion;

  final estado = EstadoCarga.vacio.obs;
  final guardados = <DebateGuardado>[].obs;
  final error = RxnString();

  /// Debates con una operación de guardar o quitar en curso.
  final pendientes = <int>{}.obs;

  int _cuenta = 0;
  int _lectura = 0;
  int? _usuarioId;
  Worker? _cambioDeUsuario;

  @override
  void onInit() {
    super.onInit();
    _cambioDeUsuario = ever<Usuario?>(_sesion.usuario, _alCambiarUsuario);
    _alCambiarUsuario(_sesion.usuario.value);
  }

  @override
  void onClose() {
    _cambioDeUsuario?.dispose();
    super.onClose();
  }

  bool estaGuardado(int debateId) => guardados.any((g) => g.id == debateId);

  void _alCambiarUsuario(Usuario? usuario) {
    if (usuario?.id == _usuarioId) return;
    _cuenta++;
    _usuarioId = usuario?.id;
    guardados.clear();
    pendientes.clear();
    error.value = null;
    estado.value = EstadoCarga.vacio;
    if (usuario != null) cargar();
  }

  Future<void> cargar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return;
    final cuenta = _cuenta;
    final lectura = ++_lectura;
    bool vigente() => cuenta == _cuenta && lectura == _lectura;
    estado.value = EstadoCarga.cargando;
    error.value = null;
    try {
      final lista = await _repositorio.listar(usuarioId);
      if (!vigente()) return;
      guardados.assignAll(lista);
      _actualizarEstado();
    } on ErrorAlmacenLocal {
      if (!vigente()) return;
      error.value = 'No se pudieron leer tus guardados en este dispositivo.';
      estado.value = EstadoCarga.error;
    }
  }

  /// Guarda el debate. Devuelve el mensaje para la persona, o null si se descartó.
  Future<String?> guardar(DebateResumen debate, String etiquetaCategoria) {
    return _operar(
      debate.id,
      (usuarioId) async {
        final guardado = await _repositorio.guardar(
          usuarioId,
          debate,
          etiquetaCategoria,
        );
        return () => guardados
          ..removeWhere((g) => g.id == guardado.id)
          ..insert(0, guardado);
      },
      exito: 'Debate guardado en este dispositivo.',
      fallo: 'No se pudo guardar el debate. Inténtalo de nuevo.',
    );
  }

  /// Quita el debate de guardados. Devuelve el mensaje, o null si se descartó.
  Future<String?> quitar(int debateId) {
    return _operar(
      debateId,
      (usuarioId) async {
        await _repositorio.quitar(usuarioId, debateId);
        return () => guardados.removeWhere((g) => g.id == debateId);
      },
      exito: 'Debate quitado de guardados.',
      fallo: 'No se pudo quitar el debate de guardados. Inténtalo de nuevo.',
    );
  }

  /// Ejecuta una escritura local. [operacion] devuelve el cambio visible, que solo se aplica si
  /// el almacén confirmó la escritura y la cuenta sigue siendo la misma.
  Future<String?> _operar(
    int debateId,
    Future<void Function()> Function(int usuarioId) operacion, {
    required String exito,
    required String fallo,
  }) async {
    final usuarioId = _usuarioId;
    if (usuarioId == null || pendientes.contains(debateId)) return null;
    final cuenta = _cuenta;
    pendientes.add(debateId);
    try {
      final aplicar = await operacion(usuarioId);
      if (cuenta != _cuenta) return null;
      aplicar();
      if (estado.value == EstadoCarga.cargando) {
        // Una lectura iniciada antes de esta escritura podría no incluirla: se relee.
        cargar();
      } else if (estado.value != EstadoCarga.error) {
        _actualizarEstado();
      }
      return exito;
    } on ErrorAlmacenLocal {
      return cuenta == _cuenta ? fallo : null;
    } finally {
      if (cuenta == _cuenta) pendientes.remove(debateId);
    }
  }

  void _actualizarEstado() {
    estado.value = guardados.isEmpty ? EstadoCarga.vacio : EstadoCarga.listo;
  }
}

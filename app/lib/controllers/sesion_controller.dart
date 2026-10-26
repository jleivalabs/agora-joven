import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/usuario.dart';
import '../repositories/auth_repository.dart';
import '../utils/mensajes_error.dart';

enum EstadoSesion {
  restaurando,
  sinSesion,
  autenticada,
  errorRestauracion,

  /// Sesión válida de una cuenta que aún no declaró tener 18 años o más: solo puede confirmar
  /// o cerrar sesión. Ninguna otra operación se ejecuta en este estado.
  edadPendiente,
}

/// La operación pertenece a una sesión que ya no está vigente; su resultado se descarta.
class SesionObsoleta implements Exception {
  const SesionObsoleta();
}

/// Estado de sesión compartido por toda la app.
///
/// Protección ante respuestas tardías: [_sesion] es un contador que aumenta cada vez que
/// empieza una restauración o un inicio de sesión, y al cerrar o caducar la sesión. Cada
/// operación captura su valor al empezar y, tras cada espera, solo aplica resultados (incluidos
/// errores y bloques finally) si el contador no ha cambiado.
class SesionController extends GetxController {
  SesionController(this._auth);

  final AuthRepository _auth;

  final estado = EstadoSesion.restaurando.obs;
  final usuario = Rxn<Usuario>();

  /// Envío en curso de login o registro (bloquea envíos duplicados).
  final enviando = false.obs;

  /// Error del formulario de acceso o registro.
  final errorFormulario = RxnString();

  /// Aviso informativo en la pantalla de acceso (cuenta creada, sesión caducada…).
  final aviso = RxnString();

  /// Correo para rellenar el acceso después de registrarse.
  final emailSugerido = RxnString();

  final errorRestauracion = RxnString();

  int _sesion = 0;
  String? _token;

  @override
  void onInit() {
    super.onInit();
    restaurar();
  }

  /// Recupera el token guardado y lo valida con /auth/me.
  Future<void> restaurar() async {
    final sesion = ++_sesion;
    _limpiar();
    errorRestauracion.value = null;
    estado.value = EstadoSesion.restaurando;

    String? token;
    try {
      token = await _auth.leerToken();
    } catch (_) {
      token = null; // Si el almacén no se puede leer, se pide iniciar sesión.
    }
    if (sesion != _sesion) return;
    if (token == null || token.isEmpty) {
      estado.value = EstadoSesion.sinSesion;
      return;
    }

    try {
      final actual = await _auth.usuarioActual(token);
      if (sesion != _sesion) return;
      _token = token;
      usuario.value = actual;
      estado.value = _estadoPara(actual);
    } on ApiException catch (e) {
      if (sesion != _sesion) return;
      if (e.tipo == TipoError.noAutorizado) {
        // Token inválido o caducado: se elimina y se pide iniciar sesión.
        await _borrarTokenSinFallar(token);
        if (sesion != _sesion) return;
        aviso.value = 'Tu sesión caducó. Inicia sesión de nuevo.';
        estado.value = EstadoSesion.sinSesion;
      } else {
        // Red o servidor: se conserva el token y se ofrece reintentar.
        errorRestauracion.value = mensajeDeError(e);
        estado.value = EstadoSesion.errorRestauracion;
      }
    }
  }

  Future<void> iniciarSesion(String email, String password) async {
    if (enviando.value) return;
    final sesion = ++_sesion;
    enviando.value = true;
    errorFormulario.value = null;
    aviso.value = null;

    try {
      final token = await _auth.iniciarSesion(
        email: email.trim(),
        password: password,
      );
      if (sesion != _sesion) return;
      final actual = await _auth.usuarioActual(token);
      if (sesion != _sesion) return;

      try {
        await _auth.guardarToken(token);
      } catch (_) {
        await _borrarTokenSinFallar(token);
        if (sesion == _sesion) {
          errorFormulario.value =
              'No se pudo guardar la sesión de forma segura en este dispositivo. '
              'Inténtalo de nuevo.';
        }
        return;
      }
      if (sesion != _sesion) {
        // La sesión se invalidó mientras se guardaba: no se deja el token huérfano.
        await _borrarTokenSinFallar(token);
        return;
      }

      _token = token;
      usuario.value = actual;
      estado.value = _estadoPara(actual);
    } on ApiException catch (e) {
      if (sesion != _sesion) return;
      // Un 401 del login son credenciales incorrectas, no una sesión caducada.
      errorFormulario.value = switch (e.tipo) {
        TipoError.noAutorizado => 'Correo o contraseña incorrectos.',
        TipoError.validacion => 'Escribe tu correo y tu contraseña.',
        _ => mensajeDeError(e),
      };
    } finally {
      if (sesion == _sesion) enviando.value = false;
    }
  }

  /// Devuelve true si la cuenta se creó. No inicia sesión: lleva al acceso con un aviso.
  Future<bool> registrar({
    required String nombre,
    required String email,
    required String password,
    required bool confirmaMayoriaEdad,
  }) async {
    if (enviando.value) return false;
    final sesion = _sesion;
    enviando.value = true;
    errorFormulario.value = null;

    try {
      final creado = await _auth.registrar(
        nombre: nombre.trim(),
        email: email.trim(),
        password: password,
        confirmaMayoriaEdad: confirmaMayoriaEdad,
      );
      if (sesion != _sesion) return false;
      emailSugerido.value = creado.email;
      aviso.value = 'Cuenta creada. Inicia sesión con tu correo y contraseña.';
      return true;
    } on ApiException catch (e) {
      if (sesion != _sesion) return false;
      errorFormulario.value = switch (e.tipo) {
        TipoError.solicitudInvalida => 'Ya existe una cuenta con ese correo.',
        TipoError.validacion => mensajeDeValidacion(e),
        _ => mensajeDeError(e),
      };
      return false;
    } finally {
      if (sesion == _sesion) enviando.value = false;
    }
  }

  EstadoSesion _estadoPara(Usuario u) =>
      u.edadConfirmada ? EstadoSesion.autenticada : EstadoSesion.edadPendiente;

  /// La cuenta pendiente declara tener 18 años o más. Solo con la confirmación del servidor
  /// pasa a la sesión normal.
  Future<void> confirmarEdad() async {
    final token = _token;
    if (enviando.value ||
        token == null ||
        estado.value != EstadoSesion.edadPendiente) {
      return;
    }
    final sesion = _sesion;
    enviando.value = true;
    errorFormulario.value = null;
    try {
      final actual = await _auth.confirmarEdad(token);
      if (sesion != _sesion) return;
      usuario.value = actual;
      estado.value = _estadoPara(actual);
    } on ApiException catch (e) {
      if (sesion != _sesion) return;
      if (e.tipo == TipoError.noAutorizado) {
        _expirar(sesion, token);
        return;
      }
      errorFormulario.value =
          'No se pudo registrar tu confirmación. ${mensajeDeError(e)}';
    } finally {
      if (sesion == _sesion) enviando.value = false;
    }
  }

  void limpiarMensajesFormulario() {
    errorFormulario.value = null;
  }

  Future<void> cerrarSesion() async {
    _sesion++;
    _limpiar();
    estado.value = EstadoSesion.sinSesion;
    _volverAlInicio();
    try {
      await _auth.borrarToken();
    } catch (_) {
      aviso.value = 'Se cerró la sesión, pero no se pudo borrar el token del dispositivo.';
    }
  }

  /// Ejecuta una operación autenticada de la sesión vigente.
  ///
  /// Lanza [SesionObsoleta] si no hay sesión o si cambió mientras se esperaba la respuesta.
  /// Un 401 solo cierra la sesión si pertenece a la sesión vigente, y solo una vez.
  Future<T> ejecutar<T>(Future<T> Function(String token) operacion) async {
    final sesion = _sesion;
    final token = _token;
    if (token == null || estado.value != EstadoSesion.autenticada) {
      throw const SesionObsoleta();
    }
    try {
      final resultado = await operacion(token);
      if (sesion != _sesion) throw const SesionObsoleta();
      return resultado;
    } on ApiException catch (e) {
      if (sesion != _sesion) throw const SesionObsoleta();
      if (e.tipo == TipoError.noAutorizado) {
        _expirar(sesion, token);
        throw const SesionObsoleta();
      }
      if (e.codigoDetalle == 'edad_no_confirmada') {
        _pedirEdad(sesion);
        throw const SesionObsoleta();
      }
      rethrow;
    }
  }

  void _expirar(int sesion, String token) {
    // Ya se gestionó (otro 401 simultáneo) o pertenece a una sesión anterior.
    if (sesion != _sesion) return;
    _sesion++;
    _limpiar();
    aviso.value = 'Tu sesión caducó. Inicia sesión de nuevo.';
    estado.value = EstadoSesion.sinSesion;
    _volverAlInicio();
    _borrarTokenSinFallar(token);
  }

  /// El servidor exige la confirmación de edad (por ejemplo, tras migrar una cuenta antigua con
  /// la app abierta): se invalidan las operaciones en curso y se muestra la confirmación.
  void _pedirEdad(int sesion) {
    if (sesion != _sesion) return;
    _sesion++;
    estado.value = EstadoSesion.edadPendiente;
    _volverAlInicio();
  }

  void _limpiar() {
    _token = null;
    usuario.value = null;
    enviando.value = false;
    errorFormulario.value = null;
  }

  Future<void> _borrarTokenSinFallar(String token) async {
    try {
      await _auth.borrarTokenSiEs(token);
    } catch (_) {
      // Sin almacén disponible no hay nada más que hacer; la sesión ya no está activa.
    }
  }

  /// Cierra todas las pantallas apiladas: tras salir, Atrás no vuelve a pantallas protegidas.
  void _volverAlInicio() {
    Get.key.currentState?.popUntil((ruta) => ruta.isFirst);
  }
}

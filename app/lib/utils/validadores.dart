/// Validaciones de formulario alineadas con el backend (backend/app/schemas.py).
class Validadores {
  Validadores._();

  static final _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? nombre(String? valor) {
    final limpio = (valor ?? '').trim().split(RegExp(r'\s+')).join(' ');
    if (limpio.length < 2) return 'Escribe al menos 2 caracteres.';
    if (limpio.length > 60) return 'Máximo 60 caracteres.';
    return null;
  }

  static String? correo(String? valor) {
    final limpio = (valor ?? '').trim();
    if (limpio.isEmpty) return 'Escribe tu correo.';
    if (!_correo.hasMatch(limpio)) return 'Escribe un correo válido.';
    return null;
  }

  static String? passwordNueva(String? valor) {
    final largo = (valor ?? '').length;
    if (largo < 8) return 'Usa al menos 8 caracteres.';
    if (largo > 128) return 'Máximo 128 caracteres.';
    return null;
  }

  static String? requerido(String? valor, String mensaje) =>
      (valor ?? '').isEmpty ? mensaje : null;
}

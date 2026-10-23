import '../data/api_exception.dart';

/// Texto en español para cada tipo de error. Nunca muestra el detalle del servidor.
String mensajeDeError(ApiException e) {
  return switch (e.tipo) {
    TipoError.sinConexion => 'No se pudo conectar con el servidor. Revisa tu conexión o que el backend esté en marcha.',
    TipoError.tiempoAgotado =>
      'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
    TipoError.solicitudInvalida =>
      'La solicitud no es válida. Revisa los datos e inténtalo de nuevo.',
    TipoError.noAutorizado =>
      'Tu sesión no es válida o caducó. Inicia sesión de nuevo.',
    TipoError.prohibido => 'No tienes permiso para realizar esta acción.',
    TipoError.noEncontrado => 'No encontramos lo que buscas.',
    TipoError.validacion =>
      'Algunos datos no son válidos. Revísalos e inténtalo de nuevo.',
    TipoError.servidor =>
      'El servidor tuvo un problema. Inténtalo de nuevo más tarde.',
    TipoError.respuestaInvalida =>
      'El servidor envió una respuesta inesperada. Inténtalo de nuevo.',
    TipoError.desconocido => 'Ocurrió un error inesperado. Inténtalo de nuevo.',
  };
}

const _nombresCampos = {
  'nombre': 'el nombre',
  'email': 'el correo',
  'password': 'la contraseña',
};

/// Para un 422: "Revisa el correo y la contraseña." si el backend indica los campos.
String mensajeDeValidacion(ApiException e) {
  final campos = e.camposInvalidos
      .map((c) => _nombresCampos[c])
      .whereType<String>()
      .toSet()
      .toList();
  if (campos.isEmpty) return mensajeDeError(e);
  final lista = campos.length == 1
      ? campos.first
      : '${campos.sublist(0, campos.length - 1).join(', ')} y ${campos.last}';
  return 'Revisa $lista.';
}

import '../data/api_client.dart';
import '../data/token_storage.dart';
import '../models/usuario.dart';

/// Autenticación contra el backend y custodia del token.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<Usuario> registrar({
    required String nombre,
    required String email,
    required String password,
    required bool confirmaMayoriaEdad,
  }) async {
    final datos = await _api.post('/auth/registro', {
      'nombre': nombre,
      'email': email,
      'password': password,
      'confirma_mayoria_edad': confirmaMayoriaEdad,
    });
    return leerRespuesta(datos, (d) => Usuario.fromJson(d));
  }

  /// Devuelve el token emitido. No lo guarda: eso lo decide el controlador de sesión.
  Future<String> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final datos = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return leerRespuesta(datos, (d) => d['access_token'] as String);
  }

  Future<Usuario> usuarioActual(String token) async {
    final datos = await _api.get('/auth/me', token: token);
    return leerRespuesta(datos, (d) => Usuario.fromJson(d));
  }

  /// Declaración de tener 18 años o más para una cuenta existente pendiente.
  Future<Usuario> confirmarEdad(String token) async {
    final datos = await _api.post('/auth/confirmar-edad', {
      'confirma_mayoria_edad': true,
    }, token: token);
    return leerRespuesta(datos, (d) => Usuario.fromJson(d));
  }

  Future<String?> leerToken() => _tokens.leer();

  Future<void> guardarToken(String token) => _tokens.guardar(token);

  Future<void> borrarToken() => _tokens.borrar();

  /// Borra el token guardado solo si sigue siendo [token]; no toca el de otra sesión.
  Future<void> borrarTokenSiEs(String token) async {
    if (await _tokens.leer() == token) await _tokens.borrar();
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén del token de sesión. Solo guarda el token, nunca la contraseña.
abstract class TokenStorage {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> borrar();
}

/// Implementación con flutter_secure_storage (Keystore en Android).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  static const _clave = 'agora_joven_token';

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leer() => _almacen.read(key: _clave);

  @override
  Future<void> guardar(String token) =>
      _almacen.write(key: _clave, value: token);

  @override
  Future<void> borrar() => _almacen.delete(key: _clave);
}

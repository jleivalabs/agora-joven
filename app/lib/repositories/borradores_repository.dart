import '../data/api_client.dart';
import '../models/borrador.dart';
import '../models/debate.dart';

/// Borradores privados de la cuenta del token. El servidor responde 404 con los ajenos.
class BorradoresRepository {
  BorradoresRepository(this._api);

  final ApiClient _api;

  Future<Borrador> crear(String token, Map<String, Object?> valores) async {
    final datos = await _api.post('/borradores', valores, token: token);
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  Future<Borrador> obtener(String token, int id) async {
    final datos = await _api.get('/borradores/$id', token: token);
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  Future<Borrador> actualizar(
    String token,
    int id,
    Map<String, Object?> valores,
  ) async {
    final datos = await _api.patch('/borradores/$id', valores, token: token);
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  Future<void> eliminar(String token, int id) =>
      _api.delete('/borradores/$id', token: token);

  /// Publica el borrador. Repetirlo devuelve el mismo debate (no crea duplicados).
  Future<DebateResumen> publicar(String token, int id) async {
    final datos = await _api.post(
      '/borradores/$id/publicar',
      const {},
      token: token,
    );
    return leerRespuesta(datos, (d) => DebateResumen.fromJson(d));
  }
}

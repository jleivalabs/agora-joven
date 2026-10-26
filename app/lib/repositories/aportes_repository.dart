import '../data/api_client.dart';
import '../models/aporte.dart';

/// Aportes de los debates. Todas las operaciones requieren token; la autorización la
/// decide el servidor.
class AportesRepository {
  AportesRepository(this._api);

  final ApiClient _api;

  Future<List<Aporte>> listar(String token, int debateId) async {
    final datos = await _api.get('/debates/$debateId/aportes', token: token);
    return leerRespuesta(
      datos,
      (d) => [
        for (final a in d as List) Aporte.fromJson(a as Map<String, dynamic>),
      ],
    );
  }

  Future<Aporte> crear(
    String token,
    int debateId, {
    required TipoAporte tipo,
    required String texto,
    required int version,
  }) async {
    // `version`: la que la persona estaba viendo. Si ya no es la vigente, el servidor responde
    // 409 `version_desactualizada` y no publica.
    final datos = await _api.post('/debates/$debateId/aportes', {
      'tipo': tipo.name,
      'texto': texto,
      'version': version,
    }, token: token);
    return leerRespuesta(datos, (d) => Aporte.fromJson(d));
  }

  /// Envía solo los campos indicados (PATCH parcial).
  Future<Aporte> editar(
    String token,
    int aporteId, {
    TipoAporte? tipo,
    String? texto,
  }) async {
    final datos = await _api.patch('/aportes/$aporteId', {
      'tipo': ?tipo?.name,
      'texto': ?texto,
    }, token: token);
    return leerRespuesta(datos, (d) => Aporte.fromJson(d));
  }

  Future<void> eliminar(String token, int aporteId) =>
      _api.delete('/aportes/$aporteId', token: token);
}

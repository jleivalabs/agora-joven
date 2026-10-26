import '../data/api_client.dart';
import '../models/borrador.dart';
import '../models/debate.dart';

/// Catálogo de debates del backend. Todas las operaciones requieren token.
class DebatesRepository {
  DebatesRepository(this._api);

  final ApiClient _api;

  Future<List<Categoria>> categorias(String token) async {
    final datos = await _api.get('/debates/categorias', token: token);
    return leerRespuesta(
      datos,
      (d) => [
        for (final c in d as List)
          Categoria.fromJson(c as Map<String, dynamic>),
      ],
    );
  }

  /// [categoria] nula equivale a "Todas".
  Future<List<DebateResumen>> listar(String token, {String? categoria}) async {
    final datos = await _api.get(
      '/debates',
      token: token,
      consulta: categoria == null ? null : {'categoria': categoria},
    );
    return leerRespuesta(
      datos,
      (d) => [
        for (final x in d as List)
          DebateResumen.fromJson(x as Map<String, dynamic>),
      ],
    );
  }

  Future<DebateDetalle> detalle(String token, int id) async {
    final datos = await _api.get('/debates/$id', token: token);
    return leerRespuesta(datos, (d) => DebateDetalle.fromJson(d));
  }

  /// Sustituye el contenido de un debate propio publicado sin aportes (409 si ya los tiene).
  Future<DebateDetalle> editar(
    String token,
    int id,
    Map<String, Object?> contenido,
  ) async {
    final datos = await _api.put('/debates/$id', contenido, token: token);
    return leerRespuesta(datos, (d) => DebateDetalle.fromJson(d));
  }

  /// Archivo directo, **solo administración** (el servidor responde 403 a cualquier otra
  /// cuenta, también a la autora). El motivo es interno; el debate sigue consultable.
  Future<DebateDetalle> archivar(String token, int id, String motivo) async {
    final datos = await _api.post('/debates/$id/archivar', {
      'motivo': motivo,
    }, token: token);
    return leerRespuesta(datos, (d) => DebateDetalle.fromJson(d));
  }

  /// Borradores, publicados y archivados de la cuenta del token.
  Future<MisDebates> misDebates(String token) async {
    final datos = await _api.get('/mis-debates', token: token);
    return leerRespuesta(datos, (d) => MisDebates.fromJson(d));
  }
}

import '../data/api_client.dart';
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
}

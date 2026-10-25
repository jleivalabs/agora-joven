import '../data/api_client.dart';
import '../models/estadisticas.dart';

/// Estadísticas del dashboard, calculadas en el servidor.
class EstadisticasRepository {
  EstadisticasRepository(this._api);

  final ApiClient _api;

  Future<EstadisticasComunidad> comunidad(String token) async {
    final datos = await _api.get('/estadisticas/comunidad', token: token);
    return leerRespuesta(datos, (d) => EstadisticasComunidad.fromJson(d));
  }

  /// No recibe identificador: el servidor responde por la cuenta del token.
  Future<EstadisticasPersonales> mias(String token) async {
    final datos = await _api.get('/estadisticas/mias', token: token);
    return leerRespuesta(datos, (d) => EstadisticasPersonales.fromJson(d));
  }
}

import '../config/app_config.dart';
import '../data/api_client.dart';
import '../models/asistente.dart';

/// Asistente educativo del backend propio. La app nunca conoce la clave del proveedor de IA.
class AsistenteRepository {
  AsistenteRepository(this._api);

  final ApiClient _api;

  Future<RespuestaAsistente> consultar(
    String token,
    int debateId,
    AccionAsistente accion,
  ) async {
    final datos = await _api.post(
      '/asistente/debates/$debateId',
      {'accion': accion.name},
      token: token,
      tiempoRecepcion: AppConfig.tiempoRecepcionAsistente,
    );
    return leerRespuesta(datos, (d) => RespuestaAsistente.fromJson(d));
  }
}

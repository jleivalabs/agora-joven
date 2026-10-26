import '../data/api_client.dart';
import '../models/solicitud_archivo.dart';

/// Solicitudes de archivo (autor) y su revisión (administración). Requieren token; los
/// permisos los decide el servidor con el rol guardado en la base.
class SolicitudesRepository {
  SolicitudesRepository(this._api);

  final ApiClient _api;

  /// Crea la solicitud o devuelve la pendiente existente (el servidor no duplica).
  Future<SolicitudArchivo> solicitar(
    String token,
    int debateId,
    String motivo,
  ) async {
    final datos = await _api.post('/debates/$debateId/solicitud-archivo', {
      'motivo': motivo,
    }, token: token);
    return leerRespuesta(datos, (d) => SolicitudArchivo.fromJson(d));
  }

  Future<SolicitudArchivo> cancelar(String token, int solicitudId) async {
    final datos = await _api.post(
      '/solicitudes-archivo/$solicitudId/cancelar',
      const {},
      token: token,
    );
    return leerRespuesta(datos, (d) => SolicitudArchivo.fromJson(d));
  }

  /// Pendientes, por orden de llegada (solo administración).
  Future<List<SolicitudAdmin>> pendientes(String token) async {
    final datos = await _api.get('/admin/solicitudes-archivo', token: token);
    return leerRespuesta(
      datos,
      (d) => [
        for (final s in d as List)
          SolicitudAdmin.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  Future<SolicitudAdmin> resolver(
    String token,
    int solicitudId, {
    required bool aprobar,
    required String justificacion,
  }) async {
    final datos = await _api.post(
      '/admin/solicitudes-archivo/$solicitudId/${aprobar ? 'aprobar' : 'rechazar'}',
      {'justificacion': justificacion},
      token: token,
    );
    return leerRespuesta(datos, (d) => SolicitudAdmin.fromJson(d));
  }
}

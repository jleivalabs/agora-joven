import '../data/api_client.dart';
import '../models/borrador.dart';
import '../models/referencia.dart';

/// Investigación asistida de un borrador propio (7C): referencias de Crossref y redacción con IA
/// sin búsqueda. Las operaciones que cambian el borrador devuelven el borrador actualizado.
class InvestigacionRepository {
  InvestigacionRepository(this._api);

  final ApiClient _api;

  Future<EstadoInvestigacion> estado(String token) async {
    final datos = await _api.get('/investigacion/estado', token: token);
    return leerRespuesta(datos, (d) => EstadoInvestigacion.fromJson(d));
  }

  /// Búsqueda en Crossref con la pregunta y el ámbito guardados. No guarda resultados.
  Future<BusquedaReferencias> buscar(String token, int borradorId) async {
    final datos = await _api.post(
      '/borradores/$borradorId/referencias/buscar',
      const {},
      token: token,
    );
    return leerRespuesta(datos, (d) => BusquedaReferencias.fromJson(d));
  }

  /// Solo se envía el DOI: el servidor obtiene los metadatos de Crossref.
  Future<Borrador> agregar(String token, int borradorId, String doi) async {
    final datos = await _api.post('/borradores/$borradorId/referencias', {
      'doi': doi,
    }, token: token);
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  Future<Borrador> quitar(String token, int borradorId, String doi) async {
    final datos = await _api.delete(
      '/borradores/$borradorId/referencias/$doi',
      token: token,
    );
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  Future<Borrador> redactar(String token, int borradorId) async {
    final datos = await _api.post(
      '/borradores/$borradorId/redaccion',
      const {},
      token: token,
      tiempoRecepcion: const Duration(seconds: 40),
    );
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  /// [valorAnterior]: contenido del campo que la persona vio al confirmar (el servidor responde
  /// 409 si cambió entretanto).
  Future<Borrador> aceptar(
    String token,
    int borradorId,
    String sugerenciaId, {
    required String modo,
    String? valorAnterior,
    String? texto,
    String? titulo,
    String? descripcion,
  }) async {
    final datos = await _api.post(
      '/borradores/$borradorId/sugerencias/$sugerenciaId/aceptar',
      {
        'modo': modo,
        'valor_anterior': ?valorAnterior,
        'texto': ?texto,
        'titulo': ?titulo,
        'descripcion': ?descripcion,
      },
      token: token,
    );
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }

  Future<Borrador> descartar(
    String token,
    int borradorId,
    String sugerenciaId,
  ) async {
    final datos = await _api.post(
      '/borradores/$borradorId/sugerencias/$sugerenciaId/descartar',
      const {},
      token: token,
    );
    return leerRespuesta(datos, (d) => Borrador.fromJson(d));
  }
}

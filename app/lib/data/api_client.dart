import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Única puerta de la app hacia HTTP.
///
/// No añade interceptores de registro: ni cuerpos, ni contraseñas, ni tokens, ni la
/// cabecera Authorization llegan a la consola.
class ApiClient {
  ApiClient({required String baseUrl, HttpClientAdapter? adaptador})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: AppConfig.tiempoConexion,
          sendTimeout: AppConfig.tiempoEnvio,
          receiveTimeout: AppConfig.tiempoRecepcion,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      ) {
    if (adaptador != null) _dio.httpClientAdapter = adaptador;
  }

  final Dio _dio;

  Future<dynamic> get(
    String ruta, {
    String? token,
    Map<String, dynamic>? consulta,
  }) {
    return _enviar(
      () => _dio.get<dynamic>(
        ruta,
        queryParameters: consulta,
        options: _opciones(token),
      ),
    );
  }

  /// [tiempoRecepcion] amplía la espera para operaciones lentas (p. ej. el asistente).
  Future<dynamic> post(
    String ruta,
    Object cuerpo, {
    String? token,
    Duration? tiempoRecepcion,
  }) {
    return _enviar(
      () => _dio.post<dynamic>(
        ruta,
        data: cuerpo,
        options: _opciones(token, tiempoRecepcion),
      ),
    );
  }

  Future<dynamic> patch(String ruta, Object cuerpo, {String? token}) {
    return _enviar(
      () => _dio.patch<dynamic>(ruta, data: cuerpo, options: _opciones(token)),
    );
  }

  Future<void> delete(String ruta, {String? token}) async {
    await _enviar(() => _dio.delete<dynamic>(ruta, options: _opciones(token)));
  }

  Options? _opciones(String? token, [Duration? tiempoRecepcion]) =>
      token == null && tiempoRecepcion == null
      ? null
      : Options(
          headers: {'Authorization': ?(token == null ? null : 'Bearer $token')},
          receiveTimeout: tiempoRecepcion,
        );

  Future<dynamic> _enviar(Future<Response<dynamic>> Function() peticion) async {
    try {
      return (await peticion()).data;
    } on DioException catch (e) {
      throw ApiException.desdeDio(e);
    }
  }
}

/// Convierte una respuesta en modelo; si no tiene la forma esperada, lanza un error tipado.
T leerRespuesta<T>(dynamic datos, T Function(dynamic datos) convertir) {
  try {
    return convertir(datos);
  } on TypeError {
    throw const ApiException(TipoError.respuestaInvalida);
  } on FormatException {
    throw const ApiException(TipoError.respuestaInvalida);
  }
}

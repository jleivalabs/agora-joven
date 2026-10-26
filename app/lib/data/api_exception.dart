import 'dart:io';

import 'package:dio/dio.dart';

enum TipoError {
  sinConexion,
  tiempoAgotado,
  solicitudInvalida, // 400
  noAutorizado, // 401
  prohibido, // 403
  noEncontrado, // 404
  conflicto, // 409
  validacion, // 422
  limiteUso, // 429
  servidor, // 5xx
  respuestaInvalida,
  desconocido,
}

/// Error de acceso al backend, ya clasificado. No conserva el cuerpo de la respuesta:
/// los textos que ve la persona se eligen en la app, no los dicta el servidor.
class ApiException implements Exception {
  const ApiException(
    this.tipo, {
    this.codigo,
    this.camposInvalidos = const [],
    this.codigoDetalle,
    this.versionActual,
  });

  final TipoError tipo;
  final int? codigo;

  /// Código de un error estructurado del servidor (`detail.codigo`), por ejemplo
  /// `version_desactualizada` (409) o `edad_no_confirmada` (403). Solo un código: el texto que
  /// ve la persona lo elige la app.
  final String? codigoDetalle;

  /// Código de un 409 estructurado.
  String? get codigoConflicto =>
      tipo == TipoError.conflicto ? codigoDetalle : null;

  /// En `version_desactualizada`, la versión vigente del debate según el servidor.
  final int? versionActual;

  /// Nombres de los campos rechazados en un 422 (por ejemplo `email`).
  final List<String> camposInvalidos;

  factory ApiException.desdeDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(TipoError.tiempoAgotado);
      case DioExceptionType.connectionError:
        return const ApiException(TipoError.sinConexion);
      case DioExceptionType.badResponse:
        final codigo = e.response?.statusCode;
        final detalle = _detalleEstructurado(e.response?.data);
        return ApiException(
          _tipoPorCodigo(codigo),
          codigo: codigo,
          camposInvalidos: codigo == 422 ? _campos(e.response?.data) : const [],
          codigoDetalle: detalle?['codigo'] as String?,
          versionActual: codigo == 409
              ? (detalle?['version_actual'] as int?)
              : null,
        );
      case DioExceptionType.unknown:
        return ApiException(
          e.error is SocketException
              ? TipoError.sinConexion
              : TipoError.desconocido,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return const ApiException(TipoError.desconocido);
    }
  }

  static TipoError _tipoPorCodigo(int? codigo) {
    if (codigo == null) return TipoError.desconocido;
    if (codigo >= 500) return TipoError.servidor;
    return switch (codigo) {
      400 => TipoError.solicitudInvalida,
      401 => TipoError.noAutorizado,
      403 => TipoError.prohibido,
      404 => TipoError.noEncontrado,
      409 => TipoError.conflicto,
      422 => TipoError.validacion,
      429 => TipoError.limiteUso,
      _ => TipoError.desconocido,
    };
  }

  static Map? _detalleEstructurado(Object? cuerpo) =>
      cuerpo is Map && cuerpo['detail'] is Map ? cuerpo['detail'] as Map : null;

  /// Extrae el último elemento de `loc` de cada error de validación de FastAPI.
  static List<String> _campos(Object? cuerpo) {
    if (cuerpo is! Map || cuerpo['detail'] is! List) return const [];
    return [
      for (final error in cuerpo['detail'] as List)
        if (error is Map &&
            error['loc'] is List &&
            (error['loc'] as List).isNotEmpty)
          '${(error['loc'] as List).last}',
    ];
  }

  @override
  String toString() => 'ApiException($tipo, codigo: $codigo)';
}

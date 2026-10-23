import 'package:agora_joven/data/api_exception.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/utils/mensajes_error.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/servidor_falso.dart';

void main() {
  late ServidorFalso servidor;

  setUp(() => servidor = ServidorFalso());

  Future<ApiException> errorDe(Manejador manejador) async {
    servidor.cuando('GET /prueba', manejador);
    try {
      await servidor.cliente().get('/prueba');
    } on ApiException catch (e) {
      return e;
    }
    fail('Se esperaba ApiException');
  }

  test('clasifica cada código HTTP y da mensajes distintos', () async {
    final casos = {
      400: TipoError.solicitudInvalida,
      401: TipoError.noAutorizado,
      403: TipoError.prohibido,
      404: TipoError.noEncontrado,
      422: TipoError.validacion,
      500: TipoError.servidor,
      503: TipoError.servidor,
    };
    final mensajes = <String>{};
    for (final caso in casos.entries) {
      final e = await errorDe(
        (_) => RespuestaFalsa(caso.key, {'detail': 'Traceback interno'}),
      );
      expect(e.tipo, caso.value, reason: 'HTTP ${caso.key}');
      expect(e.codigo, caso.key);
      expect(mensajeDeError(e), isNot(contains('Traceback')));
      mensajes.add(mensajeDeError(e));
    }
    expect(mensajes.length, 6); // 500 y 503 comparten mensaje.
  });

  test('distingue desconexión y tiempo agotado', () async {
    final sinConexion = await errorDe(sinRed);
    final lento = await errorDe(sinRespuestaATiempo);

    expect(sinConexion.tipo, TipoError.sinConexion);
    expect(lento.tipo, TipoError.tiempoAgotado);
    expect(mensajeDeError(sinConexion), isNot(mensajeDeError(lento)));
  });

  test('envía el token como Bearer solo cuando se indica', () async {
    servidor.cuando('GET /prueba', (_) => const RespuestaFalsa(200, {}));
    final cliente = servidor.cliente();

    await cliente.get('/prueba');
    await cliente.get('/prueba', token: 'abc');

    expect(servidor.peticiones[0].headers['Authorization'], isNull);
    expect(servidor.peticiones[1].headers['Authorization'], 'Bearer abc');
  });

  test('una respuesta con forma inesperada es un error tipado', () async {
    servidor.cuando(
      'GET /auth/me',
      (_) => const RespuestaFalsa(200, ['no', 'es', 'un', 'usuario']),
    );
    final repo = AuthRepository(servidor.cliente(), AlmacenFalso());

    await expectLater(
      repo.usuarioActual('token-ana'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.tipo,
          'tipo',
          TipoError.respuestaInvalida,
        ),
      ),
    );
  });
}

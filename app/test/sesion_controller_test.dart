import 'dart:async';

import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

void main() {
  // cerrarSesion consulta Get.key, que requiere el binding de Flutter (siempre presente en la app).
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late AlmacenFalso almacen;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    almacen = AlmacenFalso();
  });
  tearDown(Get.reset);

  /// Crea el controlador sin disparar onInit (restaurar) salvo que se pida.
  SesionController crear() =>
      SesionController(AuthRepository(servidor.cliente(), almacen));

  Future<SesionController> autenticado() async {
    final sesion = crear();
    await sesion.iniciarSesion(emailAna, passwordAna);
    expect(sesion.estado.value, EstadoSesion.autenticada);
    return sesion;
  }

  group('restauración', () {
    test('sin token muestra el acceso', () async {
      final sesion = crear();
      await sesion.restaurar();

      expect(sesion.estado.value, EstadoSesion.sinSesion);
      expect(servidor.contar('GET /auth/me'), 0);
    });

    test('con token válido recupera el usuario', () async {
      almacen.token = 'token-ana';
      final sesion = crear();
      await sesion.restaurar();

      expect(sesion.estado.value, EstadoSesion.autenticada);
      expect(sesion.usuario.value!.email, emailAna);
    });

    test('con token caducado lo elimina y pide iniciar sesión', () async {
      almacen.token = 'token-caducado';
      final sesion = crear();
      await sesion.restaurar();

      expect(sesion.estado.value, EstadoSesion.sinSesion);
      expect(almacen.token, isNull);
      expect(sesion.aviso.value, contains('caducó'));
    });

    test('con fallo de red conserva el token y permite reintentar', () async {
      almacen.token = 'token-ana';
      servidor.cuando('GET /auth/me', sinRed);
      final sesion = crear();
      await sesion.restaurar();

      expect(sesion.estado.value, EstadoSesion.errorRestauracion);
      expect(sesion.errorRestauracion.value, contains('No se pudo conectar'));
      expect(almacen.token, 'token-ana');

      servidor.cuando(
        'GET /auth/me',
        (_) => const RespuestaFalsa(200, {
          'id': 1,
          'nombre': 'Ana',
          'email': emailAna,
          'creado_en': '2026-10-22T00:00:00Z',
        }),
      );
      await sesion.restaurar();
      expect(sesion.estado.value, EstadoSesion.autenticada);
    });

    test('con error 5xx tampoco borra el token', () async {
      almacen.token = 'token-ana';
      servidor.cuando('GET /auth/me', (_) => const RespuestaFalsa(503));
      final sesion = crear();
      await sesion.restaurar();

      expect(sesion.estado.value, EstadoSesion.errorRestauracion);
      expect(
        sesion.errorRestauracion.value,
        contains('servidor tuvo un problema'),
      );
      expect(almacen.token, 'token-ana');
    });

    test(
      'una restauración pendiente no reactiva la sesión tras cerrarla',
      () async {
        almacen.token = 'token-ana';
        final respuesta = Completer<RespuestaFalsa>();
        servidor.cuando('GET /auth/me', (_) => respuesta.future);
        final sesion = crear();
        final restauracion = sesion.restaurar();

        await sesion.cerrarSesion();
        respuesta.complete(
          const RespuestaFalsa(200, {
            'id': 1,
            'nombre': 'Ana',
            'email': emailAna,
            'creado_en': '2026-10-22T00:00:00Z',
          }),
        );
        await restauracion;

        expect(sesion.estado.value, EstadoSesion.sinSesion);
        expect(sesion.usuario.value, isNull);
      },
    );
  });

  group('inicio de sesión', () {
    test('válido guarda solo el token y autentica', () async {
      final sesion = await autenticado();

      expect(almacen.token, 'token-ana');
      expect(sesion.usuario.value!.nombre, 'Ana');
      expect(sesion.enviando.value, isFalse);
    });

    test(
      'credenciales inválidas: mensaje propio, sin token ni aviso de caducidad',
      () async {
        final sesion = crear();
        await sesion.iniciarSesion(emailAna, 'otra-clave');

        expect(sesion.estado.value, isNot(EstadoSesion.autenticada));
        expect(
          sesion.errorFormulario.value,
          'Correo o contraseña incorrectos.',
        );
        expect(sesion.aviso.value, isNull);
        expect(almacen.token, isNull);
      },
    );

    test('tiempo agotado muestra un mensaje distinto', () async {
      servidor.cuando('POST /auth/login', sinRespuestaATiempo);
      final sesion = crear();
      await sesion.iniciarSesion(emailAna, passwordAna);

      expect(sesion.errorFormulario.value, contains('tardó demasiado'));
    });

    test(
      'si falla guardar el token no presenta la sesión como iniciada',
      () async {
        almacen.fallarEscritura = true;
        final sesion = crear();
        await sesion.iniciarSesion(emailAna, passwordAna);

        expect(sesion.estado.value, isNot(EstadoSesion.autenticada));
        expect(sesion.usuario.value, isNull);
        expect(
          sesion.errorFormulario.value,
          contains('No se pudo guardar la sesión'),
        );
        expect(almacen.token, isNull);
      },
    );

    test('ignora envíos duplicados mientras hay uno en curso', () async {
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando('POST /auth/login', (_) => respuesta.future);
      final sesion = crear();

      final primero = sesion.iniciarSesion(emailAna, passwordAna);
      final segundo = sesion.iniciarSesion(emailAna, passwordAna);
      respuesta.complete(
        const RespuestaFalsa(200, {
          'access_token': 'token-ana',
          'token_type': 'bearer',
        }),
      );
      await Future.wait([primero, segundo]);

      expect(servidor.contar('POST /auth/login'), 1);
      expect(sesion.estado.value, EstadoSesion.autenticada);
    });

    test('un login pendiente no reactiva la sesión tras invalidarla', () async {
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando('POST /auth/login', (_) => respuesta.future);
      final sesion = crear();

      final login = sesion.iniciarSesion(emailAna, passwordAna);
      await sesion.cerrarSesion();
      respuesta.complete(
        const RespuestaFalsa(200, {
          'access_token': 'token-ana',
          'token_type': 'bearer',
        }),
      );
      await login;

      expect(sesion.estado.value, EstadoSesion.sinSesion);
      expect(almacen.token, isNull);
      expect(sesion.enviando.value, isFalse);
    });
  });

  group('registro', () {
    test('correcto deja aviso y correo sugerido, sin iniciar sesión', () async {
      final sesion = crear();
      final ok = await sesion.registrar(
        nombre: 'Bea',
        email: ' Bea@Example.com ',
        password: 'clave-de-bea-123',
      );

      expect(ok, isTrue);
      expect(sesion.aviso.value, contains('Cuenta creada'));
      expect(sesion.emailSugerido.value, 'bea@example.com');
      expect(sesion.estado.value, isNot(EstadoSesion.autenticada));
      expect(almacen.token, isNull);
    });

    test('correo duplicado (400)', () async {
      final sesion = crear();
      final ok = await sesion.registrar(
        nombre: 'Ana',
        email: emailAna,
        password: passwordAna,
      );

      expect(ok, isFalse);
      expect(
        sesion.errorFormulario.value,
        'Ya existe una cuenta con ese correo.',
      );
    });

    test('validación (422) indica los campos', () async {
      servidor.cuando(
        'POST /auth/registro',
        (_) => const RespuestaFalsa(422, {
          'detail': [
            {
              'loc': ['body', 'email'],
              'msg': 'detalle interno',
              'type': 'value_error',
            },
          ],
        }),
      );
      final sesion = crear();
      await sesion.registrar(
        nombre: 'Ana',
        email: 'x@y.z',
        password: passwordAna,
      );

      expect(sesion.errorFormulario.value, 'Revisa el correo.');
      expect(sesion.errorFormulario.value, isNot(contains('detalle interno')));
    });
  });

  group('cierre de sesión y 401', () {
    test('cerrar sesión borra el token y los datos del usuario', () async {
      final sesion = await autenticado();
      await sesion.cerrarSesion();

      expect(sesion.estado.value, EstadoSesion.sinSesion);
      expect(sesion.usuario.value, isNull);
      expect(almacen.token, isNull);
      await expectLater(
        sesion.ejecutar((t) async => t),
        throwsA(isA<SesionObsoleta>()),
      );
    });

    test('un 401 de una sesión anterior no cierra la sesión actual', () async {
      final sesion = await autenticado();
      final respuestaTardia = Completer<RespuestaFalsa>();
      servidor.cuando('GET /debates', (_) => respuestaTardia.future);
      final operacionAntigua = sesion.ejecutar(
        (token) => servidor.cliente().get('/debates', token: token),
      );

      await sesion.cerrarSesion();
      await sesion.iniciarSesion(emailAna, passwordAna);
      respuestaTardia.complete(
        const RespuestaFalsa(401, {'detail': 'caducada'}),
      );

      await expectLater(operacionAntigua, throwsA(isA<SesionObsoleta>()));
      expect(sesion.estado.value, EstadoSesion.autenticada);
      expect(almacen.token, 'token-ana');
      expect(sesion.aviso.value, isNull);
    });

    test('varios 401 simultáneos cierran la sesión una sola vez', () async {
      final sesion = await autenticado();
      final respuestas = [
        Completer<RespuestaFalsa>(),
        Completer<RespuestaFalsa>(),
      ];
      var i = 0;
      servidor.cuando('GET /debates', (_) => respuestas[i++].future);
      var cierres = 0;
      ever(sesion.estado, (e) {
        if (e == EstadoSesion.sinSesion) cierres++;
      });

      final a = sesion.ejecutar(
        (t) => servidor.cliente().get('/debates', token: t),
      );
      final b = sesion.ejecutar(
        (t) => servidor.cliente().get('/debates', token: t),
      );
      for (final r in respuestas) {
        r.complete(const RespuestaFalsa(401, {'detail': 'caducada'}));
      }
      await expectLater(a, throwsA(isA<SesionObsoleta>()));
      await expectLater(b, throwsA(isA<SesionObsoleta>()));

      expect(cierres, 1);
      expect(sesion.estado.value, EstadoSesion.sinSesion);
      expect(sesion.aviso.value, contains('caducó'));
      expect(almacen.token, isNull);
    });
  });
}

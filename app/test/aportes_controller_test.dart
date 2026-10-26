import 'dart:async';

import 'package:agora_joven/controllers/aportes_controller.dart';
import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/models/aporte.dart';
import 'package:agora_joven/repositories/aportes_repository.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

const textoValido = 'Propongo horarios acordados entre estudiantes.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late AlmacenFalso almacen;
  late SesionController sesion;
  late AportesRepository repositorio;

  setUp(() async {
    Get.testMode = true;
    servidor = ServidorFalso();
    almacen = AlmacenFalso();
    final cliente = servidor.cliente();
    sesion = SesionController(AuthRepository(cliente, almacen));
    repositorio = AportesRepository(cliente);
    await sesion.iniciarSesion(emailAna, passwordAna);
  });
  tearDown(Get.reset);

  Future<AportesController> cargado({int debateId = 1}) async {
    final c = AportesController(repositorio, sesion, debateId);
    await c.cargar();
    return c;
  }

  group('lista', () {
    test('vacía', () async {
      final c = await cargado();
      expect(c.estado.value, EstadoCarga.vacio);
    });

    test(
      'propios y ajenos con es_propio del servidor, más recientes primero',
      () async {
        servidor.sembrarAporte(
          autorId: 2,
          texto: 'Aporte de Beto, el primero.',
        );
        servidor.sembrarAporte(autorId: 1, texto: 'Aporte de Ana, el segundo.');
        final c = await cargado();

        expect(c.estado.value, EstadoCarga.listo);
        expect(c.aportes.map((a) => a.autorNombre), ['Ana', 'Beto']);
        expect(c.aportes.map((a) => a.esPropio), [true, false]);
      },
    );

    test('error y reintento', () async {
      servidor.cuando('GET /debates/{id}/aportes', sinRed);
      final c = await cargado();
      expect(c.estado.value, EstadoCarga.error);
      expect(c.error.value, contains('No se pudo conectar'));

      servidor.cuando(
        'GET /debates/{id}/aportes',
        (_) => const RespuestaFalsa(200, []),
      );
      await c.cargar();
      expect(c.estado.value, EstadoCarga.vacio);
    });

    test('una respuesta de carga antigua no pisa a la más reciente', () async {
      final lenta = Completer<RespuestaFalsa>();
      var llamada = 0;
      servidor.cuando('GET /debates/{id}/aportes', (_) {
        llamada++;
        if (llamada == 1) return lenta.future;
        return const RespuestaFalsa(200, []);
      });
      final c = AportesController(repositorio, sesion, 1);

      final primera = c.cargar();
      await c.cargar();
      lenta.complete(const RespuestaFalsa(500));
      await primera;

      expect(c.estado.value, EstadoCarga.vacio);
    });
  });

  group('crear y editar', () {
    test(
      'publicar añade al principio sin duplicar aunque se actualice',
      () async {
        final c = await cargado();

        final ok = await c.publicar(
          TipoAporte.propuesta,
          '  $textoValido  ',
          1,
        );
        expect(ok, isTrue);
        expect(c.aportes.single.texto, textoValido);
        expect(c.aportes.single.esPropio, isTrue);

        await c.cargar();
        expect(c.aportes.length, 1);
      },
    );

    test('envíos duplicados se ignoran mientras hay uno en curso', () async {
      final respuesta = Completer<RespuestaFalsa>();
      final c = await cargado();
      servidor.cuando('POST /debates/{id}/aportes', (_) => respuesta.future);

      final primero = c.publicar(TipoAporte.pregunta, textoValido, 1);
      final segundo = c.publicar(TipoAporte.pregunta, textoValido, 1);
      expect(c.enviando.value, isTrue);
      respuesta.complete(const RespuestaFalsa(500));
      await Future.wait([primero, segundo]);

      expect(servidor.contar('POST /debates/{id}/aportes'), 1);
      expect(c.enviando.value, isFalse);
    });

    test(
      'sin red al publicar: avisa que pudo guardarse y no reintenta',
      () async {
        final c = await cargado();
        servidor.cuando('POST /debates/{id}/aportes', sinRespuestaATiempo);

        final ok = await c.publicar(TipoAporte.pregunta, textoValido, 1);

        expect(ok, isFalse);
        expect(
          c.errorFormulario.value,
          contains('Es posible que se haya guardado'),
        );
        expect(servidor.contar('POST /debates/{id}/aportes'), 1);
        expect(c.aportes, isEmpty);
      },
    );

    test('editar reemplaza por id y envía solo lo que cambió', () async {
      servidor.sembrarAporte(autorId: 1, texto: textoValido);
      final c = await cargado();

      final ok = await c.editar(
        c.aportes.single,
        TipoAporte.argumento,
        textoValido,
      );

      expect(ok, isTrue);
      expect(ServidorFalso.cuerpo(servidor.peticiones.last), {
        'tipo': 'argumento',
      });
      expect(c.aportes.single.tipo, TipoAporte.argumento);
      expect(c.aportes.single.editado, isTrue);
      expect(c.aportes.length, 1);
    });

    test('editar sin cambios no llama al servidor', () async {
      servidor.sembrarAporte(autorId: 1, texto: textoValido);
      final c = await cargado();
      final antes = servidor.peticiones.length;

      expect(
        await c.editar(c.aportes.single, TipoAporte.pregunta, textoValido),
        isTrue,
      );
      expect(servidor.peticiones.length, antes);
    });

    test('403 al editar un aporte ajeno: mensaje y datos intactos', () async {
      servidor.sembrarAporte(autorId: 2, texto: textoValido);
      final c = await cargado();

      final ok = await c.editar(
        c.aportes.single,
        TipoAporte.pregunta,
        'Otro texto distinto.',
      );

      expect(ok, isFalse);
      expect(
        c.errorFormulario.value,
        'Solo quien escribió este aporte puede editarlo.',
      );
      expect(c.aportes.single.texto, textoValido);
    });

    test('404 al editar: lo retira y lo explica', () async {
      final a = servidor.sembrarAporte(autorId: 1, texto: textoValido);
      final c = await cargado();
      servidor.aportes.remove(a);

      expect(
        await c.editar(
          c.aportes.single,
          TipoAporte.pregunta,
          'Otro texto distinto.',
        ),
        isFalse,
      );
      expect(c.errorFormulario.value, 'Este aporte ya no existe.');
      expect(c.aportes, isEmpty);
    });
  });

  group('eliminar', () {
    test('solo retira el aporte cuando el servidor confirma', () async {
      servidor.sembrarAporte(autorId: 1, texto: textoValido);
      final c = await cargado();
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando('DELETE /aportes/{id}', (_) => respuesta.future);

      final eliminacion = c.eliminar(c.aportes.single);
      await pumpEventQueue();
      expect(c.aportes.length, 1);
      expect(c.eliminando, contains(1));

      respuesta.complete(const RespuestaFalsa(204));
      expect(await eliminacion, 'Aporte eliminado.');
      expect(c.aportes, isEmpty);
      expect(c.eliminando, isEmpty);
    });

    test('403 y error de conexión no retiran el aporte', () async {
      servidor.sembrarAporte(autorId: 2, texto: textoValido);
      final c = await cargado();

      expect(
        await c.eliminar(c.aportes.single),
        'Solo quien escribió este aporte puede eliminarlo.',
      );
      servidor.cuando('DELETE /aportes/{id}', sinRed);
      expect(
        await c.eliminar(c.aportes.single),
        contains('No se pudo confirmar la eliminación'),
      );
      expect(c.aportes.length, 1);
    });

    test('404 al eliminar: el servidor confirma que ya no existe', () async {
      final a = servidor.sembrarAporte(autorId: 1, texto: textoValido);
      final c = await cargado();
      servidor.aportes.remove(a);

      expect(await c.eliminar(c.aportes.single), 'Este aporte ya no existía.');
      expect(c.aportes, isEmpty);
    });
  });

  group('sesión y ciclo de vida', () {
    test(
      'una publicación tardía no se aplica tras cambiar de sesión',
      () async {
        final c = await cargado();
        final respuesta = Completer<RespuestaFalsa>();
        servidor.cuando('POST /debates/{id}/aportes', (_) => respuesta.future);

        final publicacion = c.publicar(TipoAporte.pregunta, textoValido, 1);
        await sesion.cerrarSesion();
        await sesion.iniciarSesion(emailBeto, passwordAna);
        respuesta.complete(
          RespuestaFalsa(201, {
            'id': 50,
            'debate_id': 1,
            'tipo': 'pregunta',
            'texto': textoValido,
            'autor_nombre': 'Ana',
            'creado_en': '2026-10-22T10:00:00Z',
            'editado_en': null,
            'es_propio': true,
          }),
        );

        expect(await publicacion, isFalse);
        expect(c.aportes, isEmpty);
        expect(sesion.usuario.value!.nombre, 'Beto');
      },
    );

    test('un 401 tardío de la sesión anterior no cierra la nueva', () async {
      final c = await cargado();
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando('GET /debates/{id}/aportes', (_) => respuesta.future);

      final carga = c.cargar();
      await sesion.cerrarSesion();
      await sesion.iniciarSesion(emailBeto, passwordAna);
      respuesta.complete(const RespuestaFalsa(401, {'detail': 'caducada'}));
      await carga;

      expect(sesion.estado.value, EstadoSesion.autenticada);
      expect(sesion.usuario.value!.nombre, 'Beto');
    });

    test('respuestas que llegan tras cerrar el detalle se descartan', () async {
      final c = await cargado();
      final carga = Completer<RespuestaFalsa>();
      final publicacion = Completer<RespuestaFalsa>();
      servidor.cuando('GET /debates/{id}/aportes', (_) => carga.future);
      servidor.cuando('POST /debates/{id}/aportes', (_) => publicacion.future);

      final pendienteCarga = c.cargar();
      final pendientePublicacion = c.publicar(
        TipoAporte.pregunta,
        textoValido,
        1,
      );
      c.onClose(); // la pantalla se cierra
      carga.complete(const RespuestaFalsa(500));
      publicacion.complete(const RespuestaFalsa(500));
      await pendienteCarga;

      expect(await pendientePublicacion, isFalse);
      expect(c.estado.value, isNot(EstadoCarga.error));
      expect(c.errorFormulario.value, isNull);
    });

    test('los aportes de otro debate no se mezclan', () async {
      servidor.sembrarAporte(
        autorId: 1,
        debateId: 1,
        texto: 'Aporte del debate uno.',
      );
      servidor.sembrarAporte(
        autorId: 1,
        debateId: 2,
        texto: 'Aporte del debate dos.',
      );

      final uno = await cargado(debateId: 1);
      final dos = await cargado(debateId: 2);

      expect(uno.aportes.single.texto, 'Aporte del debate uno.');
      expect(dos.aportes.single.texto, 'Aporte del debate dos.');
    });
  });
}

import 'dart:async';

import 'package:agora_joven/controllers/actividad_comunidad.dart';
import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/inicio_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/models/aporte.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/estadisticas_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late SesionController sesion;
  late EstadisticasRepository repositorio;

  setUp(() async {
    Get.testMode = true;
    servidor = ServidorFalso();
    final cliente = servidor.cliente();
    sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
    repositorio = EstadisticasRepository(cliente);
    await sesion.iniciarSesion(emailAna, passwordAna);
  });
  tearDown(Get.reset);

  Future<InicioController> cargado([ActividadComunidad? actividad]) async {
    final c = InicioController(repositorio, sesion, actividad)..onInit();
    await pumpEventQueue();
    return c;
  }

  void sembrar() {
    // Ana: 3 aportes en el debate 1 y 1 en el 2. Beto: 1 en el debate 2.
    servidor.sembrarAporte(autorId: 1, debateId: 1, tipo: 'pregunta');
    servidor.sembrarAporte(autorId: 1, debateId: 1, tipo: 'argumento');
    servidor.sembrarAporte(autorId: 1, debateId: 1, tipo: 'argumento');
    servidor.sembrarAporte(autorId: 1, debateId: 2, tipo: 'propuesta');
    servidor.sembrarAporte(autorId: 2, debateId: 2, tipo: 'pregunta');
  }

  test('carga comunidad y participación personal', () async {
    sembrar();
    final c = await cargado();

    expect(c.estadoComunidad.value, EstadoCarga.listo);
    final comunidad = c.comunidad.value!;
    expect(comunidad.totalDebates, 20);
    expect(comunidad.totalAportes, 5);
    expect(comunidad.participantes, 2);
    expect(comunidad.totalSinAportes, 18);
    expect(comunidad.etiqueta('movilidad'), 'Movilidad');

    expect(c.estadoMias.value, EstadoCarga.listo);
    final mias = c.mias.value!;
    expect(mias.totalAportes, 4);
    expect(mias.debatesParticipados, 2);
    expect(mias.porTipo, {
      TipoAporte.pregunta: 1,
      TipoAporte.argumento: 2,
      TipoAporte.propuesta: 1,
    });
  });

  test(
    'la consulta personal no envía identificadores: el servidor usa el token',
    () async {
      await cargado();

      final mias = servidor.peticiones.lastWhere(
        (p) => p.path == '/estadisticas/mias',
      );
      expect(mias.queryParameters, isEmpty);
      expect(mias.headers['Authorization'], 'Bearer token-ana');
    },
  );

  test(
    'un fallo deja la sección en error, nunca en cero, y se puede reintentar',
    () async {
      servidor.cuando(
        'GET /estadisticas/comunidad',
        (_) => const RespuestaFalsa(503),
      );
      final c = await cargado();

      expect(c.estadoComunidad.value, EstadoCarga.error);
      expect(c.comunidad.value, isNull);
      expect(c.errorComunidad.value, contains('servidor tuvo un problema'));
      expect(
        c.estadoMias.value,
        EstadoCarga.listo,
      ); // la otra sección no se ve afectada

      servidor.cuando(
        'GET /estadisticas/comunidad',
        (_) => const RespuestaFalsa(200, {
          'total_debates': 20,
          'por_categoria': [],
          'total_aportes': 0,
          'participantes': 0,
          'sin_aportes': {'total': 20, 'debates': []},
          'actividad_reciente': [],
        }),
      );
      await c.cargarComunidad();
      expect(c.estadoComunidad.value, EstadoCarga.listo);
    },
  );

  test(
    'un fallo al recargar no deja cifras antiguas como si fueran válidas',
    () async {
      final c = await cargado();
      servidor.cuando('GET /estadisticas/mias', sinRed);

      await c.cargarMias();

      expect(c.estadoMias.value, EstadoCarga.error);
      expect(c.mias.value, isNull);
    },
  );

  test('se actualiza al confirmarse un cambio de aportes', () async {
    final actividad = ActividadComunidad();
    final c = await cargado(actividad);
    expect(c.mias.value!.totalAportes, 0);

    servidor.sembrarAporte(autorId: 1, debateId: 3, tipo: 'propuesta');
    actividad.avisar();
    await pumpEventQueue();

    expect(c.mias.value!.totalAportes, 1);
    expect(c.comunidad.value!.totalAportes, 1);
  });

  test('una respuesta tardía de la sesión anterior se descarta', () async {
    final c = await cargado();
    final tardia = Completer<RespuestaFalsa>();
    servidor.cuando('GET /estadisticas/mias', (_) => tardia.future);

    final recarga = c.cargarMias();
    await sesion.cerrarSesion();
    await sesion.iniciarSesion(emailBeto, passwordAna);
    tardia.complete(
      const RespuestaFalsa(200, {
        'total_aportes': 99,
        'por_tipo': {'pregunta': 99, 'argumento': 0, 'propuesta': 0},
        'debates_participados': 9,
        'aportes_recientes': [],
      }),
    );
    await recarga;

    expect(c.mias.value!.totalAportes, isNot(99));
  });

  test(
    'las respuestas que llegan tras cerrar la pantalla no se aplican',
    () async {
      final c = await cargado();
      final tardia = Completer<RespuestaFalsa>();
      servidor.cuando('GET /estadisticas/comunidad', (_) => tardia.future);

      final recarga = c.cargarComunidad();
      c.onClose();
      tardia.complete(const RespuestaFalsa(500));
      await recarga;

      expect(c.estadoComunidad.value, EstadoCarga.listo);
    },
  );

  test('una carga antigua no pisa a la más reciente', () async {
    final c = await cargado();
    final lenta = Completer<RespuestaFalsa>();
    var llamada = 0;
    servidor.cuando('GET /estadisticas/comunidad', (_) {
      llamada++;
      if (llamada == 1) return lenta.future;
      return const RespuestaFalsa(200, {
        'total_debates': 20,
        'por_categoria': [],
        'total_aportes': 7,
        'participantes': 3,
        'sin_aportes': {'total': 15, 'debates': []},
        'actividad_reciente': [],
      });
    });

    final antigua = c.cargarComunidad();
    await c.cargarComunidad();
    lenta.complete(const RespuestaFalsa(500));
    await antigua;

    expect(c.estadoComunidad.value, EstadoCarga.listo);
    expect(c.comunidad.value!.totalAportes, 7);
  });
}

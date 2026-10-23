import 'dart:async';

import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/detalle_debate_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/debates_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late SesionController sesion;
  late DebatesRepository repositorio;

  setUp(() async {
    Get.testMode = true;
    servidor = ServidorFalso();
    final cliente = servidor.cliente();
    sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
    repositorio = DebatesRepository(cliente);
    await sesion.iniciarSesion(emailAna, passwordAna);
  });
  tearDown(Get.reset);

  Future<DebatesController> cargado() async {
    final c = DebatesController(repositorio, sesion);
    await c.cargar();
    return c;
  }

  test('carga los 20 debates y las categorías del backend', () async {
    final c = await cargado();

    expect(c.estado.value, EstadoCarga.listo);
    expect(c.debates.length, 20);
    expect(c.categorias.map((x) => x.codigo), contains('educacion'));
    expect(c.etiqueta('educacion'), 'Educación');
  });

  test('filtra por categoría y vuelve a Todas', () async {
    final c = await cargado();

    c.seleccionar('movilidad');
    await pumpEventQueue();
    expect(c.debates, isNotEmpty);
    expect(c.debates.every((d) => d.categoria == 'movilidad'), isTrue);
    expect(servidor.peticiones.last.queryParameters['categoria'], 'movilidad');

    c.seleccionar(null);
    await pumpEventQueue();
    expect(c.debates.length, 20);
    expect(servidor.peticiones.last.queryParameters, isEmpty);
  });

  test('categoría sin debates muestra el estado vacío', () async {
    final c = await cargado();

    c.seleccionar('cultura');
    await pumpEventQueue();

    expect(c.estado.value, EstadoCarga.vacio);
  });

  test('descarta respuestas de filtros que llegan fuera de orden', () async {
    final c = await cargado();
    final lenta = Completer<RespuestaFalsa>();
    servidor.cuando('GET /debates', (p) {
      if (p.queryParameters['categoria'] == 'educacion') return lenta.future;
      return RespuestaFalsa(200, [
        for (final d in debatesFalsos)
          if (d['categoria'] == 'ambiente')
            {
              for (final k in [
                'id',
                'titulo',
                'categoria',
                'resumen',
                'origen',
              ])
                k: d[k],
            },
      ]);
    });

    c.seleccionar('educacion'); // llega tarde
    c.seleccionar('ambiente'); // llega antes
    await pumpEventQueue();
    expect(c.debates.every((d) => d.categoria == 'ambiente'), isTrue);

    lenta.complete(
      RespuestaFalsa(200, [
        {
          for (final k in ['id', 'titulo', 'categoria', 'resumen', 'origen'])
            k: debatesFalsos[2][k],
        },
      ]),
    );
    await pumpEventQueue();

    expect(c.seleccion.value, 'ambiente');
    expect(c.debates.every((d) => d.categoria == 'ambiente'), isTrue);
    expect(c.estado.value, EstadoCarga.listo);
  });

  test('error del servidor y reintento', () async {
    servidor.cuando('GET /debates', (_) => const RespuestaFalsa(500));
    final c = await cargado();

    expect(c.estado.value, EstadoCarga.error);
    expect(c.error.value, contains('servidor tuvo un problema'));

    servidor.cuando(
      'GET /debates',
      (_) => RespuestaFalsa(200, [
        {
          for (final k in ['id', 'titulo', 'categoria', 'resumen', 'origen'])
            k: debatesFalsos[0][k],
        },
      ]),
    );
    await c.cargar();
    expect(c.estado.value, EstadoCarga.listo);
  });

  test(
    'un 401 durante la carga cierra la sesión sin mostrar error de lista',
    () async {
      servidor.tokensValidos
          .clear(); // el token deja de ser válido en el servidor
      final c = await cargado();

      expect(sesion.estado.value, EstadoSesion.sinSesion);
      expect(sesion.aviso.value, contains('caducó'));
      expect(
        c.estado.value,
        EstadoCarga.cargando,
      ); // no aplica el resultado de una sesión cerrada
    },
  );

  test('detalle: contenido completo y 404 con mensaje propio', () async {
    final ok = DetalleDebateController(repositorio, sesion, 3);
    await ok.cargar();
    expect(ok.estado.value, EstadoCarga.listo);
    expect(ok.debate.value!.perspectivas.length, 2);
    expect(ok.debate.value!.origen, 'Material editorial de demostración');

    final noExiste = DetalleDebateController(repositorio, sesion, 999);
    await noExiste.cargar();
    expect(noExiste.estado.value, EstadoCarga.error);
    expect(noExiste.noEncontrado.value, isTrue);
    expect(noExiste.error.value, contains('no existe'));
  });
}

import 'dart:async';

import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/guardados_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/models/debate.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/guardados_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late AlmacenGuardadosFalso almacen;
  late SesionController sesion;
  late GuardadosController guardados;

  DebateResumen debate(int id) => DebateResumen(
    id: id,
    titulo: 'Debate sintético $id',
    categoria: 'educacion',
    resumen: 'Resumen.',
    origen: 'Material editorial de demostración',
  );

  setUp(() async {
    Get.testMode = true;
    servidor = ServidorFalso();
    almacen = AlmacenGuardadosFalso();
    sesion = SesionController(
      AuthRepository(servidor.cliente(), AlmacenFalso()),
    );
    guardados = GuardadosController(GuardadosRepository(almacen), sesion)
      ..onInit();
  });
  tearDown(Get.reset);

  Future<void> entrarComo(String email) async {
    await sesion.iniciarSesion(email, passwordAna);
    await pumpEventQueue();
  }

  test(
    'sin sesión no hay guardados; al entrar se cargan los de esa cuenta',
    () async {
      almacen.cajas[1] = {};
      await guardados.guardar(
        debate(1),
        'Educación',
      ); // sin sesión: se descarta
      expect(almacen.cajas[1], isEmpty);

      await entrarComo(emailAna);
      expect(guardados.estado.value, EstadoCarga.vacio);
    },
  );

  test('guardar, evitar duplicados y quitar', () async {
    await entrarComo(emailAna);

    expect(
      await guardados.guardar(debate(3), 'Educación'),
      'Debate guardado en este dispositivo.',
    );
    expect(guardados.estaGuardado(3), isTrue);
    await guardados.guardar(debate(3), 'Educación');
    expect(guardados.guardados.length, 1);
    expect(almacen.cajas[1]!.length, 1);
    expect(guardados.estado.value, EstadoCarga.listo);

    expect(await guardados.quitar(3), 'Debate quitado de guardados.');
    expect(guardados.estaGuardado(3), isFalse);
    expect(almacen.cajas[1], isEmpty);
    expect(guardados.estado.value, EstadoCarga.vacio);
  });

  test('un fallo de escritura no lo presenta como guardado', () async {
    await entrarComo(emailAna);
    almacen.fallarEscritura = true;

    final mensaje = await guardados.guardar(debate(3), 'Educación');

    expect(mensaje, 'No se pudo guardar el debate. Inténtalo de nuevo.');
    expect(guardados.estaGuardado(3), isFalse);
    expect(guardados.pendientes, isEmpty);
  });

  test('un fallo al quitar mantiene el debate como guardado', () async {
    await entrarComo(emailAna);
    await guardados.guardar(debate(3), 'Educación');
    almacen.fallarEscritura = true;

    expect(await guardados.quitar(3), contains('No se pudo quitar'));
    expect(guardados.estaGuardado(3), isTrue);
    expect(almacen.cajas[1]!.containsKey(3), isTrue);
  });

  test(
    'un fallo de lectura muestra error, no vacía datos y permite reintentar',
    () async {
      await entrarComo(emailAna);
      await guardados.guardar(debate(3), 'Educación');
      almacen.fallarLectura = true;

      await guardados.cargar();
      expect(guardados.estado.value, EstadoCarga.error);
      expect(guardados.error.value, contains('No se pudieron leer'));
      expect(almacen.cajas[1]!.containsKey(3), isTrue);

      almacen.fallarLectura = false;
      await guardados.cargar();
      expect(guardados.estado.value, EstadoCarga.listo);
      expect(guardados.estaGuardado(3), isTrue);
    },
  );

  test(
    'cada cuenta ve solo sus guardados y se conservan tras cerrar sesión',
    () async {
      await entrarComo(emailAna);
      await guardados.guardar(debate(3), 'Educación');

      await sesion.cerrarSesion();
      await pumpEventQueue();
      expect(guardados.guardados, isEmpty);

      await entrarComo(emailBeto);
      expect(guardados.estado.value, EstadoCarga.vacio);
      await guardados.guardar(debate(5), 'Educación');

      await sesion.cerrarSesion();
      await entrarComo(emailAna);
      expect(guardados.guardados.map((g) => g.id), [3]);
      expect(almacen.cajas[2]!.keys, [5]);
    },
  );

  test(
    'un guardado pendiente de la cuenta A no aparece en la cuenta B',
    () async {
      await entrarComo(emailAna);
      final espera = Completer<void>();
      almacen.esperaEscritura = espera;

      final pendiente = guardados.guardar(debate(3), 'Educación');
      await pumpEventQueue();
      expect(guardados.pendientes, contains(3));

      await sesion.cerrarSesion();
      await entrarComo(emailBeto);
      espera.complete();

      expect(await pendiente, isNull); // descartado: no se avisa en la cuenta B
      expect(guardados.estaGuardado(3), isFalse);
      expect(guardados.pendientes, isEmpty);
      expect(almacen.cajas[1]!.keys, [
        3,
      ]); // la escritura terminó en la caja de A
      expect(almacen.cajas[2], isNull);
    },
  );

  test(
    'una lectura pendiente de la cuenta A no se muestra en la cuenta B',
    () async {
      almacen.cajas[1] = {};
      await entrarComo(emailAna);
      await guardados.guardar(debate(3), 'Educación');
      final espera = Completer<void>();
      almacen.esperaLectura = espera;

      final lectura = guardados.cargar();
      await sesion.cerrarSesion();
      await entrarComo(emailBeto);
      espera.complete();
      await lectura;

      expect(guardados.guardados, isEmpty);
      expect(guardados.estado.value, EstadoCarga.vacio);
    },
  );

  test('un guardado que termina durante una lectura no se pierde', () async {
    await entrarComo(emailAna);
    final lectura = Completer<void>();
    almacen.esperaLectura = lectura;
    final carga = guardados.cargar(); // leerá antes de que exista el guardado

    await guardados.guardar(debate(3), 'Educación');
    lectura.complete();
    await carga;
    await pumpEventQueue();

    expect(guardados.estaGuardado(3), isTrue);
    expect(guardados.estado.value, EstadoCarga.listo);
  });
}

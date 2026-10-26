import 'dart:async';

import 'package:agora_joven/app.dart';
import 'package:agora_joven/controllers/crear_debate_controller.dart';
import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/historial_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/borradores_repository.dart';
import 'package:agora_joven/repositories/debates_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/navegacion.dart';
import 'helpers/servidor_falso.dart';

/// Bloque 7B.1: historial de versiones, conflicto de versión al aportar y aclaraciones.
void main() {
  late ServidorFalso servidor;
  late AlmacenGuardadosFalso guardados;

  const tituloAna = '¿Debería abrir la biblioteca los domingos?';

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    guardados = AlmacenGuardadosFalso();
  });
  tearDown(Get.reset);

  /// Debate de Ana con su versión 1 de publicación.
  Map<String, Object?> sembrarDebateDeAna() {
    final debate = <String, Object?>{
      'id': 300,
      'titulo': tituloAna,
      'categoria': 'educacion',
      'ambito': 'Universidad',
      'resumen': 'Hay quienes solo pueden estudiar los fines de semana.',
      'contexto':
          'La biblioteca cierra los domingos y hay estudiantes que trabajan entre semana '
          'y solo pueden estudiar ese día.',
      'perspectivas': [
        {'titulo': 'Abrir', 'descripcion': 'Más horas de estudio.'},
        {'titulo': 'No abrir', 'descripcion': 'El presupuesto es limitado.'},
      ],
      'objetivo': 'Decidir si conviene abrir los domingos.',
      'origen': 'Debate creado por una persona usuaria',
      'procedencia': 'usuario',
      'estado': 'publicado',
      'autor_id': 1,
      'actualizado_en': '2026-10-24T12:00:00Z',
      'publicado_en': '2026-10-24T12:00:00Z',
      'archivado_en': null,
      'version_actual': 1,
      'con_participacion': false,
    };
    servidor.debates.add(debate);
    servidor.versiones.add({
      'debate_id': 300,
      'numero': 1,
      'tipo': 'publicacion',
      for (final c in [
        'categoria',
        'ambito',
        'titulo',
        'resumen',
        'contexto',
        'perspectivas',
        'objetivo',
      ])
        c: debate[c],
      'creada_en': '2026-10-24T12:00:00Z',
      'autor_id': 1,
      'motivo': null,
    });
    return debate;
  }

  /// Simula una edición confirmada en el servidor mientras alguien redacta.
  void editarEnServidor(Map<String, Object?> debate, String nuevoTitulo) {
    final anterior = servidor.versiones.lastWhere(
      (v) => v['debate_id'] == debate['id'],
    );
    debate['titulo'] = nuevoTitulo;
    debate['version_actual'] = (debate['version_actual'] as int) + 1;
    servidor.versiones.add({
      ...anterior,
      'numero': debate['version_actual'],
      'tipo': 'edicion',
      'titulo': nuevoTitulo,
      'creada_en': '2026-10-24T13:00:00Z',
      'motivo': 'Aclaro la pregunta.',
    });
  }

  Future<void> abrirApp(
    WidgetTester tester, {
    Size tamano = const Size(800, 2400),
    double escala = 1,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = escala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      AgoraJovenApp(
        api: servidor.cliente(),
        tokens: AlmacenFalso('token-ana'),
        guardados: guardados,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Desplazable vertical de la pantalla superior (la última ruta apilada).
  Finder vertical() => find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .last;

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: vertical());
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> abrirDebate(WidgetTester tester, String titulo) async {
    await irAPestana(tester, 'Debates');
    await tocar(tester, find.text(titulo));
  }

  group('historial', () {
    testWidgets(
      'lista de versiones, versión vigente e histórica con diferencias',
      (tester) async {
        final debate = sembrarDebateDeAna();
        editarEnServidor(
          debate,
          '¿Debería abrir la biblioteca los domingos y festivos?',
        );
        await abrirApp(tester);
        await abrirDebate(
          tester,
          '¿Debería abrir la biblioteca los domingos y festivos?',
        );
        expect(find.byKey(const Key('version-vigente')), findsOneWidget);

        await tester.tap(find.byKey(const Key('historial')));
        await tester.pumpAndSettle();
        expect(find.text('Versión 2 (vigente)'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('version-1')),
            matching: find.text('Versión 1'),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Motivo: Aclaro la pregunta.'),
          findsOneWidget,
        );
        expect(find.textContaining('Cambió: Pregunta'), findsOneWidget);

        await tester.tap(find.byKey(const Key('version-2')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('aviso-version-vigente')), findsOneWidget);
        expect(find.text('Cambios respecto a la versión 1'), findsOneWidget);
        expect(find.text(tituloAna), findsOneWidget); // valor "antes"
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('version-1')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('aviso-version-historica')),
          findsOneWidget,
        );
        expect(
          find.textContaining('No es el contenido vigente'),
          findsOneWidget,
        );
        expect(find.text('Cambios respecto a la versión 0'), findsNothing);
        // Los borradores nunca aparecen en el historial.
        expect(servidor.contar('GET /borradores'), 0);
      },
    );

    for (final caso in [
      ('pantalla estrecha', const Size(360, 1600), 1.0),
      ('texto ampliado ×2', const Size(360, 1600), 2.0),
    ]) {
      testWidgets('historial y versión sin desbordamientos (${caso.$1})', (
        tester,
      ) async {
        final debate = sembrarDebateDeAna();
        editarEnServidor(
          debate,
          '¿Debería abrir la biblioteca también en vacaciones?',
        );
        await abrirApp(tester, tamano: caso.$2, escala: caso.$3);
        await abrirDebate(
          tester,
          '¿Debería abrir la biblioteca también en vacaciones?',
        );
        await tester.tap(find.byKey(const Key('historial')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('version-2')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('aviso-version-vigente')), findsOneWidget);
      });
    }

    test('una respuesta tardía no se aplica tras cambiar de sesión', () async {
      Get.testMode = true;
      final cliente = servidor.cliente();
      final sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
      await sesion.iniciarSesion(emailAna, passwordAna);
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando('GET /debates/{id}/versiones', (_) => respuesta.future);
      final c = HistorialController(DebatesRepository(cliente), sesion, 1)
        ..onInit();
      await pumpEventQueue();

      await sesion.cerrarSesion();
      await sesion.iniciarSesion(emailBeto, passwordAna);
      respuesta.complete(const RespuestaFalsa(200, []));
      await pumpEventQueue();

      expect(c.estado.value, EstadoCarga.cargando);
      expect(c.versiones, isEmpty);
    });
  });

  group('aportes y versiones', () {
    testWidgets(
      'si el debate cambia mientras se redacta: conflicto, texto conservado y sin reintento',
      (tester) async {
        final debate = sembrarDebateDeAna();
        await abrirApp(tester);
        await abrirDebate(tester, tituloAna);
        await tocar(tester, find.byKey(const Key('aporte-nuevo')));
        expect(find.byKey(const Key('version-del-aporte')), findsOneWidget);
        const texto = 'Propongo abrir solo en época de exámenes.';
        await tester.enterText(find.byKey(const Key('aporte-texto')), texto);

        editarEnServidor(debate, '¿Debería abrir la biblioteca en exámenes?');
        await tester.tap(find.byKey(const Key('aporte-enviar')));
        await tester.pumpAndSettle();

        expect(
          servidor.aportes,
          isEmpty,
        ); // no se publicó contra la versión nueva
        expect(
          find.textContaining('El debate cambió mientras redactabas'),
          findsOneWidget,
        );
        expect(
          find.text(texto),
          findsOneWidget,
        ); // el texto sigue en el formulario
        final enviar = tester.widget<FilledButton>(
          find.byKey(const Key('aporte-enviar')),
        );
        expect(enviar.onPressed, isNull); // hay que decidir antes de reenviar
        await tester.pump(const Duration(seconds: 2));
        expect(
          servidor.contar('POST /debates/{id}/aportes'),
          1,
        ); // sin reintento automático

        await tester.tap(find.byKey(const Key('ver-version-actual')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('aviso-version-vigente')), findsOneWidget);
        expect(
          find.text('¿Debería abrir la biblioteca en exámenes?'),
          findsWidgets,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text(texto), findsOneWidget);

        await tester.tap(find.byKey(const Key('aceptar-version')));
        await tester.pumpAndSettle();
        expect(
          find.text('Tu aporte se publicará sobre la versión 2 del debate.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('aporte-enviar')));
        await tester.pumpAndSettle();

        expect(servidor.aportes.single['version'], 2);
        expect(servidor.aportes.single['texto'], texto);
        expect(find.text('Escrito sobre la versión 2'), findsOneWidget);
      },
    );

    testWidgets('un aporte anterior al historial muestra versión desconocida', (
      tester,
    ) async {
      servidor.sembrarAporte(autorId: 2, debateId: 1, version: null);
      await abrirApp(tester);
      await abrirDebate(tester, 'Debate sintético 1');

      await tocar(tester, find.text('Versión original desconocida'));
      expect(
        find.byKey(const Key('aviso-version-desconocida')),
        findsOneWidget,
      );
    });
  });

  group('aclaraciones y edición', () {
    testWidgets('el autor añade una aclaración sin cambiar el contenido', (
      tester,
    ) async {
      sembrarDebateDeAna();
      await abrirApp(tester);
      await abrirDebate(tester, tituloAna);

      await tester.tap(find.byTooltip('Opciones de tu debate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir aclaración'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-motivo')), 'corta');
      await tester.tap(find.byKey(const Key('confirmar-motivo')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe al menos 10 caracteres.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('campo-motivo')),
        'Me refiero a la biblioteca central.',
      );
      await tester.tap(find.byKey(const Key('confirmar-motivo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aclaraciones')), findsOneWidget);
      expect(find.text('Me refiero a la biblioteca central.'), findsOneWidget);
      expect(servidor.aclaraciones.single['autor_id'], 1);
      expect(servidor.debates.last['titulo'], tituloAna);
      expect(servidor.debates.last['version_actual'], 1);
    });

    testWidgets('otra cuenta no ve opciones de aclarar en un debate ajeno', (
      tester,
    ) async {
      await abrirApp(tester);
      await abrirDebate(tester, 'Debate sintético 1');
      expect(find.byTooltip('Opciones de tu debate'), findsNothing);
      expect(find.text('Añadir aclaración'), findsNothing);
    });

    test('editar crea versión con motivo; sin cambios no crea otra', () async {
      Get.testMode = true;
      final debate = sembrarDebateDeAna();
      final cliente = servidor.cliente();
      final sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
      await sesion.iniciarSesion(emailAna, passwordAna);
      final debates = DebatesRepository(cliente);
      final detalle = await debates.detalle('token-ana', 300);

      final c = CrearDebateController(
        BorradoresRepository(cliente),
        debates,
        sesion,
        debateEditado: detalle,
      )..onInit();
      final sinCambios = await c.guardarEdicion(
        'Reviso el texto sin cambiarlo.',
      );
      expect(sinCambios!.versionActual, 1);

      c.cambiarTitulo(
        '¿Debería abrir la biblioteca los domingos por la tarde?',
      );
      final editado = await c.guardarEdicion(
        'Preciso el horario de la pregunta.',
      );
      expect(editado!.versionActual, 2);
      final ultima = servidor.versiones.last;
      expect(ultima['motivo'], 'Preciso el horario de la pregunta.');
      expect(ultima['autor_id'], 1);
      expect(debate['version_actual'], 2);

      // Tras el primer aporte, aunque se elimine, el contenido queda protegido.
      final aporte = servidor.sembrarAporte(
        autorId: 2,
        debateId: 300,
        version: 2,
      );
      servidor.aportes.remove(aporte);
      c.cambiarTitulo('¿Otro cambio después de la participación?');
      expect(await c.guardarEdicion('Intento cambiar tras aportes.'), isNull);
      expect(c.errorPublicar.value, contains('bloqueado'));
    });
  });
}

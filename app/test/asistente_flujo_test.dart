import 'dart:async';

import 'package:agora_joven/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

/// Flujo visual del asistente con servidor SIMULADO (sin IA real).
void main() {
  late ServidorFalso servidor;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
  });
  tearDown(Get.reset);

  Future<void> abrirDetalle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AgoraJovenApp(
        api: servidor.cliente(),
        tokens: AlmacenFalso('token-ana'),
        guardados: AlmacenGuardadosFalso(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debate sintético 1'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'las dos acciones están identificadas y el contexto se marca como IA',
    (tester) async {
      await abrirDetalle(tester);
      expect(find.text('Asistente educativo'), findsOneWidget);
      expect(find.text('Explicar el contexto'), findsOneWidget);
      expect(find.text('Resumir perspectivas de los aportes'), findsOneWidget);

      await tester.tap(find.byKey(const Key('asistente-contexto')));
      await tester.pumpAndSettle();

      expect(
        find.text('Generado por IA · Explicar el contexto'),
        findsOneWidget,
      );
      expect(find.text('Texto simulado de contexto.'), findsOneWidget);
      expect(
        find.text('Texto generado por IA con fines educativos.'),
        findsOneWidget,
      );
      // El resultado no se publica como aporte.
      expect(servidor.contar('POST /debates/{id}/aportes'), 0);
      expect(servidor.aportes, isEmpty);
    },
  );

  testWidgets('resumen sin aportes muestra un estado informativo', (
    tester,
  ) async {
    await abrirDetalle(tester);

    await tester.tap(find.byKey(const Key('asistente-perspectivas')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('todavía no tiene aportes que resumir'),
      findsOneWidget,
    );
    expect(find.textContaining('Generado por IA'), findsNothing);
  });

  testWidgets('resumen parcial indica cuántos aportes usó', (tester) async {
    for (var i = 0; i < 3; i++) {
      servidor.sembrarAporte(autorId: 2, texto: 'Aporte número $i con texto.');
    }
    await abrirDetalle(tester);

    await tester.tap(find.byKey(const Key('asistente-perspectivas')));
    await tester.pumpAndSettle();

    expect(find.text('Texto simulado de perspectivas.'), findsOneWidget);
    expect(
      find.text('Basado en 2 de 3 aportes (los más recientes).'),
      findsOneWidget,
    );
  });

  testWidgets('error del asistente con reintento explícito', (tester) async {
    servidor.cuando(
      'POST /asistente/debates/{id}',
      (_) => const RespuestaFalsa(503),
    );
    await abrirDetalle(tester);

    await tester.tap(find.byKey(const Key('asistente-contexto')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('no está disponible en este momento'),
      findsOneWidget,
    );
    expect(servidor.contar('POST /asistente/debates/{id}'), 1);

    servidor.cuando(
      'POST /asistente/debates/{id}',
      (_) => RespuestaFalsa(200, {
        'debate_id': 1,
        'accion': 'contexto',
        'estado': 'generado',
        'texto': 'Ahora sí.',
        'aviso': 'IA',
        'aportes_usados': 0,
        'aportes_totales': 0,
        'parcial': false,
        'truncado': false,
      }),
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Ahora sí.'), findsOneWidget);
    expect(servidor.contar('POST /asistente/debates/{id}'), 2);
  });

  testWidgets('mientras consulta, los botones se desactivan', (tester) async {
    final respuesta = Completer<RespuestaFalsa>();
    servidor.cuando('POST /asistente/debates/{id}', (_) => respuesta.future);
    await abrirDetalle(tester);

    await tester.tap(find.byKey(const Key('asistente-contexto')));
    await tester.pump();

    final boton = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('asistente-perspectivas')),
    );
    expect(boton.onPressed, isNull);
    await tester.tap(
      find.byKey(const Key('asistente-perspectivas')),
      warnIfMissed: false,
    );

    respuesta.complete(const RespuestaFalsa(502));
    await tester.pumpAndSettle();
    expect(find.textContaining('no pudo generar'), findsOneWidget);
    expect(servidor.contar('POST /asistente/debates/{id}'), 1);
  });

  testWidgets('salir del detalle con una consulta pendiente no la aplica', (
    tester,
  ) async {
    final respuesta = Completer<RespuestaFalsa>();
    servidor.cuando('POST /asistente/debates/{id}', (_) => respuesta.future);
    await abrirDetalle(tester);

    await tester.tap(find.byKey(const Key('asistente-contexto')));
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    respuesta.complete(const RespuestaFalsa(503));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la respuesta en Markdown se muestra con formato, sin marcas', (
    tester,
  ) async {
    servidor.cuando(
      'POST /asistente/debates/{id}',
      (_) => const RespuestaFalsa(200, {
        'debate_id': 1,
        'accion': 'contexto',
        'estado': 'generado',
        'texto': '### Contexto\n\nLos **huertos urbanos** se debaten.\n\n* Una idea\n* Otra idea',
        'aviso': 'Texto generado por IA con fines educativos.',
        'aportes_usados': 0,
        'aportes_totales': 0,
        'parcial': false,
        'truncado': false,
      }),
    );
    await abrirDetalle(tester);

    await tester.tap(find.byKey(const Key('asistente-contexto')));
    await tester.pumpAndSettle();

    final resultado = find.byKey(const Key('asistente-resultado'));
    final visible = tester
        .widgetList<SelectableText>(
          find.descendant(of: resultado, matching: find.byType(SelectableText)),
        )
        .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
        .join('\n');
    expect(visible, contains('Los huertos urbanos se debaten.'));
    expect(visible, isNot(contains('**')));
    expect(visible, isNot(contains('###')));
    expect(
      find.descendant(of: resultado, matching: find.text('•')),
      findsNWidgets(2),
    );
    expect(find.text('Generado por IA · Explicar el contexto'), findsOneWidget);
    expect(
      find.text('Texto generado por IA con fines educativos.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

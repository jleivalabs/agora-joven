import 'dart:async';

import 'package:agora_joven/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

const textoValido = 'Propongo horarios acordados entre estudiantes.';

/// Flujos de aportes con la app completa, servidor falso y almacén simulado.
void main() {
  late ServidorFalso servidor;
  late AlmacenFalso almacen;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    almacen = AlmacenFalso('token-ana');
  });
  tearDown(Get.reset);

  /// Abre la app con sesión de Ana y entra al debate 1. Pantalla alta para ver la sección
  /// de aportes sin desplazar.
  Future<void> abrirDetalle(WidgetTester tester, {bool esperar = true}) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AgoraJovenApp(api: servidor.cliente(), tokens: almacen),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debate sintético 1'));
    if (esperar) {
      await tester.pumpAndSettle();
    } else {
      // Con una respuesta pendiente el indicador gira sin fin: se avanza a mano.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> escribirYEnviar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const Key('aporte-texto')), texto);
    await tester.tap(find.byKey(const Key('aporte-enviar')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin aportes: estado vacío y publicación de una propuesta', (
    tester,
  ) async {
    await abrirDetalle(tester);
    expect(find.textContaining('Aún no hay aportes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aporte-nuevo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Propuesta'));
    await tester.pump();
    await escribirYEnviar(tester, textoValido);

    expect(find.text('Nuevo aporte'), findsNothing); // el formulario se cerró
    expect(find.text(textoValido), findsOneWidget);
    expect(find.text('PROPUESTA'), findsOneWidget);
    expect(find.text('Ana (tú)'), findsOneWidget);
  });

  testWidgets('el formulario valida la longitud sin llamar al servidor', (
    tester,
  ) async {
    await abrirDetalle(tester);
    await tester.tap(find.byKey(const Key('aporte-nuevo')));
    await tester.pumpAndSettle();

    await escribirYEnviar(tester, '   corto   ');

    expect(find.text('Escribe al menos 10 caracteres.'), findsOneWidget);
    expect(servidor.contar('POST /debates/{id}/aportes'), 0);
  });

  testWidgets('editar y eliminar solo aparecen en aportes propios', (
    tester,
  ) async {
    servidor.sembrarAporte(autorId: 2, texto: 'Aporte escrito por Beto.');
    servidor.sembrarAporte(autorId: 1, texto: 'Aporte escrito por Ana.');
    await abrirDetalle(tester);

    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('Ana (tú)'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    final tarjetaBeto = find.ancestor(
      of: find.text('Aporte escrito por Beto.'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: tarjetaBeto, matching: find.text('Editar')),
      findsNothing,
    );
  });

  testWidgets('editar conserva el tipo, cambia el texto y marca Editado', (
    tester,
  ) async {
    servidor.sembrarAporte(autorId: 1, tipo: 'argumento', texto: textoValido);
    await abrirDetalle(tester);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar aporte'), findsOneWidget);
    expect(find.text(textoValido), findsOneWidget); // texto precargado

    await escribirYEnviar(tester, 'Texto revisado del argumento.');

    expect(find.text('Texto revisado del argumento.'), findsOneWidget);
    expect(find.text('ARGUMENTO'), findsOneWidget);
    expect(find.text('Editado'), findsOneWidget);
    expect(ServidorFalso.cuerpo(servidor.peticiones.last), {
      'texto': 'Texto revisado del argumento.',
    });
  });

  testWidgets('error al guardar conserva el texto y el formulario abierto', (
    tester,
  ) async {
    servidor.cuando('POST /debates/{id}/aportes', sinRed);
    await abrirDetalle(tester);
    await tester.tap(find.byKey(const Key('aporte-nuevo')));
    await tester.pumpAndSettle();

    await escribirYEnviar(tester, textoValido);

    expect(find.text('Nuevo aporte'), findsOneWidget);
    expect(
      find.textContaining('Es posible que se haya guardado'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('aporte-texto')))
          .controller!
          .text,
      textoValido,
    );
    expect(servidor.contar('POST /debates/{id}/aportes'), 1);
  });

  testWidgets(
    'eliminar pide confirmación: cancelar conserva, confirmar retira',
    (tester) async {
      servidor.sembrarAporte(autorId: 1, texto: textoValido);
      await abrirDetalle(tester);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este aporte?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text(textoValido), findsOneWidget);
      expect(servidor.contar('DELETE /aportes/{id}'), 0);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text(textoValido), findsNothing);
      expect(find.text('Aporte eliminado.'), findsOneWidget);
      expect(find.textContaining('Aún no hay aportes'), findsOneWidget);
    },
  );

  testWidgets('403 al eliminar: avisa y el aporte sigue en la lista', (
    tester,
  ) async {
    servidor.sembrarAporte(autorId: 1, texto: textoValido);
    servidor.cuando('DELETE /aportes/{id}', (_) => const RespuestaFalsa(403));
    await abrirDetalle(tester);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Solo quien escribió este aporte puede eliminarlo.'),
      findsOneWidget,
    );
    expect(find.text(textoValido), findsOneWidget);
  });

  testWidgets(
    'fallo al cargar aportes no oculta el debate y se puede reintentar',
    (tester) async {
      servidor.cuando(
        'GET /debates/{id}/aportes',
        (_) => const RespuestaFalsa(503),
      );
      await abrirDetalle(tester);

      expect(find.text('Contexto del debate sintético 1.'), findsOneWidget);
      expect(find.textContaining('servidor tuvo un problema'), findsOneWidget);

      servidor.sembrarAporte(autorId: 2, texto: 'Aporte que ya existía.');
      servidor.cuando(
        'GET /debates/{id}/aportes',
        (_) => RespuestaFalsa(200, [
          {
            'id': 1,
            'debate_id': 1,
            'tipo': 'pregunta',
            'texto': 'Aporte que ya existía.',
            'autor_nombre': 'Beto',
            'creado_en': '2026-10-22T10:00:00Z',
            'editado_en': null,
            'es_propio': false,
          },
        ]),
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Aporte que ya existía.'), findsOneWidget);
    },
  );

  testWidgets(
    'actualizar muestra aportes nuevos de otra persona sin duplicar',
    (tester) async {
      servidor.sembrarAporte(autorId: 1, texto: textoValido);
      await abrirDetalle(tester);
      servidor.sembrarAporte(autorId: 2, texto: 'Beto acaba de publicar esto.');

      await tester.tap(find.byTooltip('Actualizar aportes'));
      await tester.pumpAndSettle();

      expect(find.text('Beto acaba de publicar esto.'), findsOneWidget);
      expect(find.text(textoValido), findsOneWidget);
    },
  );

  testWidgets('salir del detalle con una carga pendiente no la aplica', (
    tester,
  ) async {
    final respuesta = Completer<RespuestaFalsa>();
    servidor.cuando('GET /debates/{id}/aportes', (_) => respuesta.future);
    await abrirDetalle(tester, esperar: false);
    expect(find.text('Contexto'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    respuesta.complete(const RespuestaFalsa(500));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la sesión que caduca al publicar vuelve al acceso sin navegar de más',
    (tester) async {
      await abrirDetalle(tester);
      await tester.tap(find.byKey(const Key('aporte-nuevo')));
      await tester.pumpAndSettle();
      servidor.tokensValidos.clear();

      await escribirYEnviar(tester, textoValido);

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(
        find.text('Tu sesión caducó. Inicia sesión de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Nuevo aporte'), findsNothing);
    },
  );
}

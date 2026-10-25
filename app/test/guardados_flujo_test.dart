import 'package:agora_joven/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/navegacion.dart';
import 'helpers/servidor_falso.dart';

/// Flujo visual de guardados con la app completa, servidor falso y almacenes simulados.
void main() {
  late ServidorFalso servidor;
  late AlmacenFalso tokens;
  late AlmacenGuardadosFalso guardados;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    tokens = AlmacenFalso('token-ana');
    guardados = AlmacenGuardadosFalso();
  });
  tearDown(Get.reset);

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      AgoraJovenApp(
        api: servidor.cliente(),
        tokens: tokens,
        guardados: guardados,
      ),
    );
    await tester.pumpAndSettle();
    if (find.byType(NavigationBar).evaluate().isNotEmpty) {
      await irAPestana(tester, 'Debates');
    }
  }

  Future<void> abrirGuardados(WidgetTester tester) =>
      irAPestana(tester, 'Guardados');

  testWidgets(
    'guardar desde el detalle, verlo en Guardados, abrirlo y quitarlo',
    (tester) async {
      await abrir(tester);
      await abrirGuardados(tester);
      expect(
        find.textContaining('Aún no has guardado debates'),
        findsOneWidget,
      );
      await irAPestana(tester, 'Debates');

      await tester.tap(find.text('Debate sintético 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar debate'));
      await tester.pumpAndSettle();
      expect(find.text('Debate guardado en este dispositivo.'), findsOneWidget);
      expect(find.byTooltip('Quitar de guardados'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(guardados.cajas[1]!.keys, [1]);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await abrirGuardados(tester);
      expect(find.text('Debate sintético 1'), findsOneWidget);
      expect(find.textContaining('Ambiente · guardado el'), findsOneWidget);

      await tester.tap(find.text('Debate sintético 1'));
      await tester.pumpAndSettle();
      expect(find.text('Contexto del debate sintético 1.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quitar de guardados'));
      await tester.pumpAndSettle();
      expect(find.text('Debate quitado de guardados.'), findsOneWidget);
      expect(
        find.textContaining('Aún no has guardado debates'),
        findsOneWidget,
      );
      expect(guardados.cajas[1], isEmpty);
    },
  );

  testWidgets('si falla la escritura, el detalle no se marca como guardado', (
    tester,
  ) async {
    guardados.fallarEscritura = true;
    await abrir(tester);
    await tester.tap(find.text('Debate sintético 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Guardar debate'));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo guardar el debate. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Guardar debate'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('la lista de guardados se lee aunque el backend falle', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Debate sintético 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Guardar debate'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // El backend deja de responder: el catálogo falla, los guardados siguen disponibles.
    servidor.cuando('GET /debates', sinRed);
    servidor.cuando('GET /debates/{id}', sinRed);
    servidor.cuando('GET /debates/{id}/aportes', sinRed);
    await abrirGuardados(tester);
    expect(find.text('Debate sintético 2'), findsOneWidget);

    // Abrir el detalle sigue el flujo remoto: error con Reintentar.
    await tester.tap(find.text('Debate sintético 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('error de lectura de guardados con reintento', (tester) async {
    guardados.fallarLectura = true;
    await abrir(tester);
    await abrirGuardados(tester);

    expect(
      find.text('No se pudieron leer tus guardados en este dispositivo.'),
      findsOneWidget,
    );

    guardados.fallarLectura = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no has guardado debates'), findsOneWidget);
  });

  testWidgets(
    'cambiar de cuenta muestra solo los guardados de la nueva cuenta',
    (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Debate sintético 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar debate'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cuenta y cierre de sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('login-email')), emailBeto);
      await tester.enterText(
        find.byKey(const Key('login-password')),
        passwordAna,
      );
      await tester.tap(find.byKey(const Key('login-enviar')));
      await tester.pumpAndSettle();

      await abrirGuardados(tester);
      expect(
        find.textContaining('Aún no has guardado debates'),
        findsOneWidget,
      );
      expect(guardados.cajas[1]!.keys, [1]); // los de Ana siguen en su caja
    },
  );
}

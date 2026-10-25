import 'package:agora_joven/theme/app_theme.dart';
import 'package:agora_joven/widgets/tarjetas_estadistica.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rejilla compartida de tarjetas: igual ancho e igual altura dentro de cada grupo.
void main() {
  var pulsada = '';

  List<Widget> tarjetas() => [
    const TarjetaEstadistica(
      valor: 20,
      titulo: 'Debates publicados',
      explicacion: 'En el catálogo actual',
      icono: Icons.forum_outlined,
    ),
    TarjetaEstadistica(
      valor: 5,
      titulo: 'Aportes',
      explicacion: 'Preguntas, argumentos y propuestas',
      icono: Icons.chat_bubble_outline,
      onTap: () => pulsada = 'Aportes',
    ),
    const TarjetaEstadistica(
      valor: 2,
      titulo: 'Participantes',
      explicacion: 'Cuentas con al menos un aporte',
      icono: Icons.people_outline,
    ),
    const TarjetaEstadistica(
      valor: 17,
      titulo: 'Debates sin aportes',
      // Explicación más larga a propósito: no debe desigualar las tarjetas.
      explicacion: 'Esperan una primera voz de la comunidad para empezar la conversación',
      icono: Icons.campaign_outlined,
    ),
  ];

  Future<void> montar(
    WidgetTester tester,
    double ancho, {
    double escala = 1,
  }) async {
    tester.view.physicalSize = Size(ancho, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(ancho, 3000),
            textScaler: TextScaler.linear(escala),
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [RejillaEstadisticas(children: tarjetas())],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Rect> rectangulos(WidgetTester tester) => [
    for (final e in find.byType(TarjetaEstadistica).evaluate())
      tester.getRect(find.byWidget(e.widget)),
  ];

  void mismasDimensiones(List<Rect> r) {
    for (final x in r) {
      expect(x.width, closeTo(r.first.width, 0.01));
      expect(x.height, closeTo(r.first.height, 0.01));
    }
  }

  testWidgets('2×2 con igual ancho y altura', (tester) async {
    await montar(tester, 400);

    final r = rectangulos(tester);
    mismasDimensiones(r);
    expect({for (final x in r) x.left}.length, 2); // dos columnas
    expect({for (final x in r) x.top}.length, 2); // dos filas
    expect(
      r[1].left - r[0].right,
      closeTo(AppSpacing.s, 0.01),
    ); // separación uniforme
    expect(r[2].top - r[0].bottom, closeTo(AppSpacing.s, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('los textos no se recortan ni se reduce la tipografía', (
    tester,
  ) async {
    await montar(tester, 400);

    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.maxLines, isNull);
      expect(t.overflow, isNull);
    }
    expect(
      find.text(
        'Esperan una primera voz de la comunidad para empezar la conversación',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pantalla estrecha: una columna, mismas dimensiones', (
    tester,
  ) async {
    await montar(tester, 280);

    final r = rectangulos(tester);
    mismasDimensiones(r);
    expect({for (final x in r) x.left}.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texto ampliado ×2: crece en altura sin desbordar', (
    tester,
  ) async {
    await montar(tester, 360);
    final normal = rectangulos(tester).first.height;

    await montar(tester, 360, escala: 2);
    final r = rectangulos(tester);

    mismasDimensiones(r);
    expect(r.first.height, greaterThan(normal));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la tarjeta es pulsable y accesible', (tester) async {
    await montar(tester, 400);

    expect(
      find.bySemanticsLabel('Aportes: 5. Preguntas, argumentos y propuestas'),
      findsOneWidget,
    );
    await tester.tap(find.text('Aportes'));
    expect(pulsada, 'Aportes');
  });
}

import 'package:agora_joven/theme/app_theme.dart';
import 'package:agora_joven/widgets/texto_markdown_seguro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuestas de ejemplo LOCALES con el formato que mostraron las capturas (sin llamar a Gemini).
const respuestaContexto = '''
### ¿De qué trata el debate?

Los **huertos urbanos** proponen convertir terrenos baldíos o parques en espacios de cultivo
comunitario. El debate gira en torno a *cómo* y *dónde* impulsarlos.

### Perspectivas principales

* **Impulso municipal:** los gobiernos locales cederían espacios y apoyo técnico.
* **Iniciativa vecinal:** los huertos funcionan mejor cuando nacen de la comunidad.
* **Prioridad a otros usos:** algunos espacios deberían destinarse a recreación o deporte.

1. Primer punto numerado.
2. Segundo punto numerado con un texto bastante más largo para comprobar que se ajusta a varias líneas sin desbordarse en pantallas estrechas.

Este es un párrafo largo de cierre que repite ideas para forzar varias líneas en un móvil: el asistente resume, no toma partido, y recuerda que las opiniones de las personas participantes no son hechos comprobados.
''';

const marcas = ['**', '### ', '\n* ', '\n1. '];

void main() {
  Future<void> montar(
    WidgetTester tester,
    String texto, {
    Size tamano = const Size(360, 800),
    double escala = 1,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: MediaQuery(
          data: MediaQueryData(
            size: tamano,
            textScaler: TextScaler.linear(escala),
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [TextoMarkdownSeguro(texto: texto)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Texto visible concatenado (el widget es seleccionable: usa SelectableText).
  String textoVisible(WidgetTester tester) => tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
      .join('\n');

  Iterable<TextSpan> fragmentos(WidgetTester tester) sync* {
    for (final t in tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    )) {
      final raiz = t.textSpan;
      if (raiz == null) continue;
      final pendientes = <InlineSpan>[raiz];
      while (pendientes.isNotEmpty) {
        final s = pendientes.removeLast();
        if (s is TextSpan) {
          yield s;
          pendientes.addAll(s.children ?? const []);
        }
      }
    }
  }

  testWidgets('no muestra marcas Markdown y conserva el texto', (tester) async {
    await montar(tester, respuestaContexto);

    final visible = textoVisible(tester);
    for (final marca in marcas) {
      expect(
        visible.contains(marca),
        isFalse,
        reason: 'marca visible: "$marca"',
      );
    }
    expect(visible, contains('¿De qué trata el debate?'));
    expect(visible, contains('Impulso municipal:'));
    expect(visible, contains('Segundo punto numerado'));
    expect(visible, contains('no son hechos comprobados.'));
  });

  testWidgets('negritas, cursivas y encabezados con estilo propio', (
    tester,
  ) async {
    await montar(tester, respuestaContexto);

    final spans = fragmentos(tester).toList();
    TextStyle? estiloDe(String texto) =>
        spans.firstWhere((s) => s.text?.contains(texto) ?? false).style;

    expect(estiloDe('huertos urbanos')?.fontWeight, FontWeight.w700);
    expect(estiloDe('cómo')?.fontStyle, FontStyle.italic);
    final h3 = estiloDe('¿De qué trata el debate?');
    final parrafo = estiloDe('proponen convertir');
    expect(h3?.fontWeight, FontWeight.w700);
    expect(h3!.fontSize, greaterThan(parrafo!.fontSize!));
  });

  testWidgets('listas con viñetas y numeradas', (tester) async {
    await montar(tester, respuestaContexto);

    expect(find.text('•'), findsNWidgets(3));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });

  for (final (descripcion, tamano, escala) in [
    ('móvil estrecho', const Size(320, 640), 1.0),
    ('móvil con texto ampliado ×2', const Size(360, 800), 2.0),
  ]) {
    testWidgets('sin desbordamientos: $descripcion', (tester) async {
      await montar(tester, respuestaContexto, tamano: tamano, escala: escala);

      expect(tester.takeException(), isNull);
      // Sin scroll propio: el desplazamiento es el de la pantalla.
      expect(
        find.descendant(
          of: find.byType(TextoMarkdownSeguro),
          matching: find.byType(ListView),
        ),
        findsNothing,
      );
    });
  }

  testWidgets(
    'contenido no confiable: sin imágenes remotas, HTML ni enlaces activos',
    (tester) async {
      await montar(
        tester,
        'Antes ![logo](https://example.com/logo.png) después.\n\n'
        '<script>alert(1)</script>\n\n'
        'Un [enlace](https://example.com/externo) sin abrir.',
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('[Imagen no mostrada: logo]'), findsOneWidget);
      final visible = textoVisible(tester);
      expect(visible, contains('Un enlace sin abrir.'));
      // El bloque HTML se omite: no se muestra ni se ejecuta.
      expect(visible, isNot(contains('alert')));

      await tester.tap(find.textContaining('enlace', findRichText: true).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

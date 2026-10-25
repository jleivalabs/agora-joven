import 'package:agora_joven/app.dart';
import 'package:agora_joven/widgets/tarjetas_estadistica.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/navegacion.dart';
import 'helpers/servidor_falso.dart';

/// Dashboard con la app completa, servidor falso (estadísticas calculadas a partir de sus datos)
/// y almacenes simulados.
void main() {
  late ServidorFalso servidor;
  late AlmacenGuardadosFalso guardados;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    guardados = AlmacenGuardadosFalso();
  });
  tearDown(Get.reset);

  void sembrar() {
    // Ana: 3 aportes en el debate 1 y 1 en el 2. Beto: 1 en el debate 2.
    servidor.sembrarAporte(
      autorId: 1,
      debateId: 1,
      tipo: 'pregunta',
      texto: 'Primera pregunta de Ana.',
    );
    servidor.sembrarAporte(autorId: 1, debateId: 1, tipo: 'argumento');
    servidor.sembrarAporte(autorId: 1, debateId: 1, tipo: 'argumento');
    servidor.sembrarAporte(
      autorId: 1,
      debateId: 2,
      tipo: 'propuesta',
      texto: 'Propuesta reciente de Ana.',
    );
    servidor.sembrarAporte(autorId: 2, debateId: 2, tipo: 'pregunta');
  }

  Future<void> abrir(
    WidgetTester tester, {
    Size tamano = const Size(400, 4000),
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

  Finder cifra(String etiqueta, int valor) => find.bySemanticsLabel(
    RegExp('^${RegExp.escape(etiqueta)}: $valor(\\.|\$)'),
  );

  testWidgets('la sesión empieza en Inicio con navegación principal', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('La comunidad'), findsOneWidget);
    expect(find.text('Mi participación'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final destino in ['Inicio', 'Debates', 'Guardados']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destino),
        ),
        findsOneWidget,
      );
    }
    expect(find.byTooltip('Cuenta y cierre de sesión'), findsOneWidget);
  });

  testWidgets('cifras exactas de la comunidad y de mi participación', (
    tester,
  ) async {
    sembrar();
    await abrir(tester);

    expect(cifra('Debates publicados', 20), findsOneWidget);
    expect(cifra('Aportes', 5), findsOneWidget);
    expect(cifra('Participantes', 2), findsOneWidget);
    expect(cifra('Debates sin aportes', 18), findsOneWidget);
    expect(cifra('Mis aportes', 4), findsOneWidget);
    expect(cifra('Debates en los que participé', 2), findsOneWidget);
    expect(find.text('Preguntas: 1'), findsOneWidget);
    expect(find.text('Argumentos: 2'), findsOneWidget);
    expect(find.text('Propuestas: 1'), findsOneWidget);
    expect(find.text('Propuesta reciente de Ana.'), findsOneWidget);
    expect(find.textContaining('3 aportes · último el'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Movilidad: 7 debates\.')),
      findsOneWidget,
    );
  });

  testWidgets('sin aportes: ceros reales e invitación a participar', (
    tester,
  ) async {
    await abrir(tester);

    expect(cifra('Aportes', 0), findsOneWidget);
    expect(cifra('Participantes', 0), findsOneWidget);
    expect(
      find.text('Todavía no hay aportes en ningún debate.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Todavía no has publicado aportes'),
      findsOneWidget,
    );

    await tester.tap(find.text('Explorar debates'));
    await tester.pumpAndSettle();
    expect(find.text('Debate sintético 1'), findsOneWidget);
  });

  testWidgets('una categoría abre el catálogo filtrado', (tester) async {
    await abrir(tester);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Movilidad: 7 debates\.')));
    await tester.pumpAndSettle();

    expect(find.text('Debate sintético 2'), findsOneWidget); // movilidad
    expect(find.text('Debate sintético 1'), findsNothing); // ambiente
    expect(servidor.peticiones.last.queryParameters['categoria'], 'movilidad');
  });

  testWidgets('actividad reciente y mis aportes abren el debate', (
    tester,
  ) async {
    sembrar();
    await abrir(tester);

    await tester.tap(find.text('Propuesta reciente de Ana.'));
    await tester.pumpAndSettle();
    expect(find.text('Contexto del debate sintético 2.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Debate sintético 1').first);
    await tester.pumpAndSettle();
    expect(find.text('Contexto del debate sintético 1.'), findsOneWidget);
  });

  testWidgets('Mis guardados usa el almacén local y lleva a la pestaña', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Aún no has guardado debates.'), findsOneWidget);

    await tester.tap(find.text('Mis guardados'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aún no has guardado debates. Abre uno'),
      findsOneWidget,
    );
  });

  testWidgets('un error muestra Reintentar y no cifras en cero', (
    tester,
  ) async {
    servidor.cuando(
      'GET /estadisticas/comunidad',
      (_) => const RespuestaFalsa(503),
    );
    servidor.cuando('GET /estadisticas/mias', sinRed);
    await abrir(tester);

    expect(find.textContaining('servidor tuvo un problema'), findsOneWidget);
    expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    expect(find.text('Reintentar'), findsNWidgets(2));
    expect(cifra('Aportes', 0), findsNothing);
    expect(cifra('Mis aportes', 0), findsNothing);

    servidor.cuando(
      'GET /estadisticas/mias',
      (_) => const RespuestaFalsa(200, {
        'total_aportes': 0,
        'por_tipo': {'pregunta': 0, 'argumento': 0, 'propuesta': 0},
        'debates_participados': 0,
        'aportes_recientes': [],
      }),
    );
    await tester.tap(find.text('Reintentar').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Todavía no has publicado aportes'),
      findsOneWidget,
    );
    expect(
      find.text('Reintentar'),
      findsOneWidget,
    ); // la comunidad sigue en error
  });

  testWidgets('publicar un aporte actualiza las cifras del inicio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3600);
    await abrir(tester, tamano: const Size(800, 3600));
    expect(cifra('Aportes', 0), findsOneWidget);

    await irAPestana(tester, 'Debates');
    await tester.tap(find.text('Debate sintético 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aporte-nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('aporte-texto')),
      'Mi primer aporte de prueba.',
    );
    await tester.tap(find.byKey(const Key('aporte-enviar')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await irAPestana(tester, 'Inicio');

    expect(cifra('Aportes', 1), findsOneWidget);
    expect(cifra('Mis aportes', 1), findsOneWidget);
    expect(cifra('Participantes', 1), findsOneWidget);
  });

  testWidgets('actualización manual', (tester) async {
    await abrir(tester);
    servidor.sembrarAporte(autorId: 2, debateId: 4);

    await tester.tap(find.byTooltip('Actualizar cifras'));
    await tester.pumpAndSettle();

    expect(cifra('Aportes', 1), findsOneWidget);
    expect(cifra('Participantes', 1), findsOneWidget);
  });

  for (final (descripcion, tamano, escala) in [
    ('móvil estrecho', const Size(320, 4000), 1.0),
    ('texto ampliado ×2', const Size(360, 8000), 2.0),
  ]) {
    testWidgets('sin desbordamientos: $descripcion', (tester) async {
      sembrar();
      await abrir(tester, tamano: tamano, escala: escala);

      expect(tester.takeException(), isNull);
      expect(find.text('Mis aportes recientes'), findsOneWidget);
    });
  }

  testWidgets('categorías de más a menos debates, empates por nombre', (
    tester,
  ) async {
    await abrir(tester);

    // Datos del servidor falso: Ambiente 7, Movilidad 7, Educación 6, Cultura 0.
    final etiquetas = find.bySemanticsLabel(
      RegExp(r'^[^:]+: \d+ debates?\. Abrir'),
    );
    final orden = [
      for (var i = 0; i < etiquetas.evaluate().length; i++)
        tester.getSemantics(etiquetas.at(i)).label.split(':').first,
    ];
    expect(orden, ['Ambiente', 'Movilidad', 'Educación', 'Cultura']);
  });

  testWidgets('tarjetas simétricas en cada grupo', (tester) async {
    sembrar();
    await abrir(tester);

    final rects = [
      for (final e in find.byType(TarjetaEstadistica).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects, hasLength(6));
    final comunidad = rects.sublist(0, 4);
    final mias = rects.sublist(4);
    for (final grupo in [comunidad, mias]) {
      for (final r in grupo) {
        expect(r.width, closeTo(grupo.first.width, 0.01));
        expect(r.height, closeTo(grupo.first.height, 0.01));
      }
    }
    expect({for (final r in comunidad) r.left}.length, 2); // 2×2
    expect({for (final r in comunidad) r.top}.length, 2);
  });
}

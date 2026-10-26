import 'package:agora_joven/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/navegacion.dart';
import 'helpers/servidor_falso.dart';

/// Bloque 7B con la app completa: asistente de creación, borradores, publicación y archivo.
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
        tokens: tokens,
        guardados: guardados,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirAsistente(WidgetTester tester) async {
    await irAPestana(tester, 'Debates');
    await tester.tap(find.byKey(const Key('crear-debate')));
    await tester.pumpAndSettle();
  }

  Future<void> escribir(WidgetTester tester, String clave, String texto) async {
    await tester.enterText(find.byKey(Key('campo-$clave')), texto);
    await tester.pump();
  }

  Future<void> siguiente(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('crear-siguiente')));
    await tester.pumpAndSettle();
  }

  Future<void> pasoTema(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movilidad').last);
    await tester.pumpAndSettle();
    await escribir(tester, 'ambito', 'Estudiantes de la ciudad');
  }

  Future<void> completarHastaRevision(WidgetTester tester) async {
    await pasoTema(tester);
    await siguiente(tester);
    await escribir(
      tester,
      'titulo',
      '¿Debería ampliarse el horario del bus universitario?',
    );
    await siguiente(tester);
    await escribir(
      tester,
      'resumen',
      'Quienes estudian de noche tienen pocas opciones para volver a casa.',
    );
    await escribir(
      tester,
      'contexto',
      'El servicio termina antes que algunas clases nocturnas y hay quienes caminan largas '
          'distancias o pagan transporte privado para volver.',
    );
    await siguiente(tester);
    await escribir(tester, 'perspectiva-0-titulo', 'Ampliar el horario');
    await escribir(
      tester,
      'perspectiva-0-descripcion',
      'Mejora la seguridad al volver.',
    );
    await escribir(tester, 'perspectiva-1-titulo', 'Mantenerlo');
    await escribir(
      tester,
      'perspectiva-1-descripcion',
      'Los recursos irían a otras rutas.',
    );
    await siguiente(tester);
    await escribir(
      tester,
      'objetivo',
      'Aclarar si conviene ampliar el horario y cómo.',
    );
    await siguiente(tester);
  }

  testWidgets('desde el catálogo: progreso y error junto al campo', (
    tester,
  ) async {
    await abrirApp(tester);
    await abrirAsistente(tester);

    expect(find.text('Paso 1 de 6 · Tema'), findsOneWidget);
    await siguiente(tester);

    expect(find.text('Paso 1 de 6 · Tema'), findsOneWidget);
    expect(find.text('Elige una categoría.'), findsOneWidget);
    expect(find.text('Indica a quién afecta.'), findsOneWidget);
  });

  testWidgets('crear, revisar y publicar: aparece como debate de usuario', (
    tester,
  ) async {
    await abrirApp(tester);
    await abrirAsistente(tester);
    await completarHastaRevision(tester);

    expect(find.text('Paso 6 de 6 · Revisión'), findsOneWidget);
    expect(find.text('Vista previa'), findsOneWidget);
    expect(
      find.textContaining('Se publicará con tu nombre visible (Ana)'),
      findsOneWidget,
    );
    expect(
      servidor.debates.where((d) => d['procedencia'] == 'usuario'),
      isEmpty,
    );

    await tester.tap(find.byKey(const Key('crear-publicar')));
    await tester.pumpAndSettle();

    expect(find.text('Debate'), findsOneWidget); // detalle
    expect(find.textContaining('Debate creado por Ana'), findsOneWidget);
    expect(find.textContaining('no lo ha verificado'), findsOneWidget);
    expect(find.text('Ámbito: Estudiantes de la ciudad'), findsOneWidget);
    expect(find.text('Objetivo'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    // El catálogo se recargó: el debate nuevo está al final de la lista.
    await tester.scrollUntilVisible(
      find.textContaining('CREADO POR ANA'),
      400,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    expect(find.textContaining('CREADO POR ANA'), findsOneWidget);
  });

  testWidgets(
    'guardar y salir, cerrar la app por completo y retomar el borrador',
    (tester) async {
      await abrirApp(tester);
      await abrirAsistente(tester);
      await pasoTema(tester);
      await siguiente(tester);
      await escribir(tester, 'titulo', '¿Pregunta a medias');

      await tester.tap(find.byTooltip('Guardar y salir'));
      await tester.pumpAndSettle();
      expect(
        find.text('Borrador guardado. Puedes retomarlo en Mis debates.'),
        findsOneWidget,
      );

      // Cierre completo: se reconstruye la app con el mismo backend y el mismo token.
      Get.reset();
      Get.testMode = true;
      await tester.pumpWidget(const SizedBox());
      await abrirApp(tester);

      expect(find.textContaining('1 borrador'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mis-debates')));
      await tester.pumpAndSettle();
      expect(find.text('¿Pregunta a medias'), findsOneWidget);

      await tester.tap(find.text('¿Pregunta a medias'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 2 de 6 · Pregunta'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('campo-titulo')))
            .controller!
            .text,
        '¿Pregunta a medias',
      );
    },
  );

  testWidgets('salir con cambios sin guardar pregunta antes de descartarlos', (
    tester,
  ) async {
    await abrirApp(tester);
    await abrirAsistente(tester);
    await escribir(tester, 'ambito', 'Algo escrito');

    await tester.tap(find.byTooltip('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Tienes cambios sin guardar'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 6 · Tema'), findsOneWidget);

    await tester.tap(find.byTooltip('Salir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 6 · Tema'), findsNothing);
    expect(servidor.borradores, isEmpty);
  });

  testWidgets(
    'si guardar falla, se avisa, se conservan los datos y se reintenta',
    (tester) async {
      await abrirApp(tester);
      await abrirAsistente(tester);
      final original = servidor.manejador('POST /borradores')!;
      servidor.cuando('POST /borradores', sinRed);
      await escribir(tester, 'ambito', 'Barrio norte');

      await tester.tap(find.byTooltip('Guardar y salir'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo guardar el borrador'),
        findsOneWidget,
      );
      expect(find.text('Paso 1 de 6 · Tema'), findsOneWidget); // no salió
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('campo-ambito')))
            .controller!
            .text,
        'Barrio norte',
      );

      servidor.cuando('POST /borradores', original);
      await tester.tap(find.text('Reintentar guardado'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsNothing);
      expect(servidor.borradores.single['ambito'], 'Barrio norte');
    },
  );

  Future<void> escribirMotivo(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const Key('campo-motivo')), texto);
    await tester.tap(find.byKey(const Key('confirmar-motivo')));
    await tester.pumpAndSettle();
  }

  /// Un debate publicado por Ana con una solicitud de archivo pendiente.
  Map<String, Object?> sembrarSolicitud() {
    final debate = <String, Object?>{
      'id': 300,
      'titulo': '¿Debería abrir la biblioteca los domingos?',
      'categoria': 'educacion',
      'resumen': 'Hay quienes solo pueden estudiar los fines de semana.',
      'contexto': 'Contexto suficiente para el debate sembrado.',
      'perspectivas': [
        {'titulo': 'Abrir', 'descripcion': 'Más horas de estudio.'},
        {'titulo': 'No abrir', 'descripcion': 'El presupuesto es limitado.'},
      ],
      'origen': 'Debate creado por una persona usuaria',
      'procedencia': 'usuario',
      'estado': 'publicado',
      'autor_id': 1,
      'actualizado_en': '2026-10-24T12:00:00Z',
      'publicado_en': '2026-10-24T12:00:00Z',
      'archivado_en': null,
    };
    servidor.debates.add(debate);
    servidor.solicitudes.add({
      'id': 1,
      'debate_id': 300,
      'solicitante_id': 1,
      'motivo': 'La biblioteca ya anunció el nuevo horario.',
      'estado': 'pendiente',
      'creada_en': '2026-10-24T14:00:00Z',
      'resuelta_en': null,
      'revisor_id': null,
      'justificacion': null,
    });
    return debate;
  }

  void sesionDeRosa() {
    servidor.tokensValidos['token-rosa'] = 3;
    tokens = AlmacenFalso('token-rosa');
  }

  testWidgets(
    'el autor solicita el archivo: queda pendiente, sigue abierto y puede cancelarla',
    (tester) async {
      await abrirApp(tester);
      await abrirAsistente(tester);
      await completarHastaRevision(tester);
      await tester.tap(find.byKey(const Key('crear-publicar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones de tu debate'));
      await tester.pumpAndSettle();
      // El autor ya no puede archivar directamente.
      expect(find.text('Archivar (administración)'), findsNothing);
      expect(find.text('Archivar debate'), findsNothing);
      await tester.tap(find.text('Solicitar archivo'));
      await tester.pumpAndSettle();

      await escribirMotivo(tester, 'corto');
      expect(find.text('Escribe al menos 10 caracteres.'), findsOneWidget);
      expect(servidor.solicitudes, isEmpty);
      await escribirMotivo(tester, 'Ya no es necesario este debate.');

      expect(servidor.solicitudes.single['estado'], 'pendiente');
      expect(find.byKey(const Key('aviso-solicitud')), findsOneWidget);
      expect(find.textContaining('pendiente de revisión'), findsWidgets);
      // La solicitud no archiva ni bloquea la participación.
      expect(find.byKey(const Key('aviso-archivado')), findsNothing);
      expect(find.byKey(const Key('aporte-nuevo')), findsOneWidget);

      await tester.tap(find.byTooltip('Opciones de tu debate'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitar archivo'), findsNothing);
      await tester.tap(find.text('Cancelar solicitud de archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar solicitud'));
      await tester.pumpAndSettle();

      expect(servidor.solicitudes.single['estado'], 'cancelada');
      expect(find.byKey(const Key('aviso-solicitud')), findsNothing);
      expect(find.text('Solicitud de archivo cancelada.'), findsWidgets);
    },
  );

  testWidgets(
    'Mis debates muestra la solicitud pendiente y permite cancelarla',
    (tester) async {
      sembrarSolicitud();
      await abrirApp(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('mis-debates')),
        200,
      );
      await tester.tap(find.byKey(const Key('mis-debates')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Publicados'));
      await tester.pumpAndSettle();

      expect(find.textContaining('pendiente de revisión'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancelar-solicitud-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar solicitud'));
      await tester.pumpAndSettle();

      expect(servidor.solicitudes.single['estado'], 'cancelada');
      expect(find.textContaining('pendiente de revisión'), findsNothing);
      expect(find.byKey(const Key('cancelar-solicitud-1')), findsNothing);
    },
  );

  testWidgets('una cuenta normal no ve Administración ni el archivo directo', (
    tester,
  ) async {
    await abrirApp(tester);
    expect(find.byKey(const Key('administracion')), findsNothing);
    expect(find.text('Administración'), findsNothing);

    await irAPestana(tester, 'Debates');
    await tester.tap(find.text(servidor.debates.first['titulo']! as String));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Opciones de administración'), findsNothing);
    expect(find.byTooltip('Opciones de tu debate'), findsNothing);
  });

  for (final caso in [
    ('pantalla amplia', const Size(800, 2400), 1.0),
    ('pantalla estrecha con texto ×2', const Size(360, 1600), 2.0),
  ]) {
    testWidgets(
      'administración (${caso.$1}): aprueba una solicitud y el debate explica su archivo',
      (tester) async {
        sembrarSolicitud();
        sesionDeRosa();
        await abrirApp(tester, tamano: caso.$2, escala: caso.$3);

        await tester.scrollUntilVisible(
          find.byKey(const Key('administracion')),
          200,
        );
        await tester.ensureVisible(find.byKey(const Key('administracion')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('administracion')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('solicitud-1')));
        await tester.pumpAndSettle();
        expect(
          find.text('La biblioteca ya anunció el nuevo horario.'),
          findsOneWidget,
        );
        expect(find.textContaining('Solicitada por Ana'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('aprobar-solicitud')),
          200,
        );
        await tester.ensureVisible(find.byKey(const Key('aprobar-solicitud')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('aprobar-solicitud')));
        await tester.pumpAndSettle();
        await escribirMotivo(tester, 'Se confirmó el cambio de horario.');

        expect(tester.takeException(), isNull);
        expect(
          find.text('No hay solicitudes de archivo pendientes.'),
          findsOneWidget,
        );
        expect(servidor.solicitudes.single['estado'], 'aprobada');
        expect(servidor.debates.last['estado'], 'archivado');
        expect(servidor.debates.last['archivo_origen'], 'solicitud');
      },
    );
  }

  testWidgets('administración: archivo directo con motivo obligatorio', (
    tester,
  ) async {
    sesionDeRosa();
    await abrirApp(tester);
    await irAPestana(tester, 'Debates');
    await tester.tap(find.text(servidor.debates.first['titulo']! as String));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Opciones de administración'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitar archivo'), findsNothing); // no es la autora
    await tester.tap(find.text('Archivar (administración)'));
    await tester.pumpAndSettle();
    await escribirMotivo(tester, '');
    expect(find.text('Escribe al menos 10 caracteres.'), findsOneWidget);
    expect(servidor.contar('POST /debates/{id}/archivar'), 0);
    await escribirMotivo(tester, 'Contenido duplicado en otro debate.');

    expect(servidor.contar('POST /debates/{id}/archivar'), 1);
    expect(find.byKey(const Key('aviso-archivado')), findsOneWidget);
    expect(
      find.textContaining('Archivado por la administración.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('aporte-nuevo')), findsNothing);
    expect(find.byTooltip('Opciones de administración'), findsNothing);
  });

  testWidgets(
    'un debate archivado sigue abriéndose desde Guardados con su estado',
    (tester) async {
      await abrirApp(tester);
      await abrirAsistente(tester);
      await completarHastaRevision(tester);
      await tester.tap(find.byKey(const Key('crear-publicar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar debate'));
      await tester.pumpAndSettle();
      servidor.debates.last['estado'] =
          'archivado'; // archivado mientras estaba guardado
      await tester.pageBack();
      await tester.pumpAndSettle();

      await irAPestana(tester, 'Guardados');
      await tester.tap(
        find.text('¿Debería ampliarse el horario del bus universitario?'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aviso-archivado')), findsOneWidget);
      expect(find.text('Contexto'), findsOneWidget);
    },
  );

  testWidgets('eliminar un borrador pide confirmación', (tester) async {
    await abrirApp(tester);
    await abrirAsistente(tester);
    await escribir(tester, 'ambito', 'Borrador a eliminar');
    await tester.tap(find.byTooltip('Guardar y salir'));
    await tester.pumpAndSettle();
    await irAPestana(tester, 'Inicio');
    await tester.tap(find.byKey(const Key('mis-debates')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar borrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(servidor.borradores, hasLength(1));

    await tester.tap(find.byTooltip('Eliminar borrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(servidor.borradores, isEmpty);
    expect(find.text('Borrador eliminado.'), findsOneWidget);
  });

  for (final (descripcion, tamano, escala) in [
    ('móvil estrecho', const Size(320, 900), 1.0),
    ('texto ampliado ×2', const Size(360, 1600), 2.0),
  ]) {
    testWidgets('sin desbordamientos en el asistente: $descripcion', (
      tester,
    ) async {
      await abrirApp(tester, tamano: tamano, escala: escala);
      await abrirAsistente(tester);
      expect(tester.takeException(), isNull);

      await escribir(tester, 'ambito', 'Estudiantes de la ciudad');
      await tester.tap(find.byTooltip('Guardar y salir'));
      await tester.pumpAndSettle();
      await irAPestana(tester, 'Inicio');
      await tester.scrollUntilVisible(
        find.byKey(const Key('mis-debates')),
        200,
      );
      await tester.tap(find.byKey(const Key('mis-debates')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Mis debates'), findsWidgets);
    });
  }
}

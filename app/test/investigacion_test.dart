import 'dart:async';

import 'package:agora_joven/app.dart';
import 'package:agora_joven/controllers/crear_debate_controller.dart';
import 'package:agora_joven/controllers/investigacion_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/data/abridor_enlaces.dart';
import 'package:agora_joven/models/referencia.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/borradores_repository.dart';
import 'package:agora_joven/repositories/debates_repository.dart';
import 'package:agora_joven/repositories/investigacion_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/navegacion.dart';
import 'helpers/servidor_falso.dart';

/// Bloque 7C con proveedores simulados: ninguna prueba contacta con Crossref ni con Gemini.
class AbridorFalso implements AbridorEnlaces {
  AbridorFalso({this.resultado = true});

  bool resultado;
  final abiertos = <Uri>[];

  @override
  Future<bool> abrir(Uri enlace) async {
    abiertos.add(enlace);
    return resultado;
  }
}

void main() {
  late ServidorFalso servidor;
  late AbridorFalso abridor;
  late AlmacenFalso tokens;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    abridor = AbridorFalso();
    tokens = AlmacenFalso('token-ana');
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
        guardados: AlmacenGuardadosFalso(),
        abridor: abridor,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder vertical() => find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .last;

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: vertical());
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Lleva a la vista un elemento de la lista (se construye de forma diferida).
  Future<void> ver(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: vertical());
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

  /// Asistente abierto en el paso de contexto, con categoría, ámbito y pregunta.
  Future<void> hastaContexto(WidgetTester tester) async {
    await irAPestana(tester, 'Debates');
    await tester.tap(find.byKey(const Key('crear-debate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campo-categoria')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movilidad').last);
    await tester.pumpAndSettle();
    await escribir(tester, 'ambito', 'Estudiantes de la ciudad');
    await siguiente(tester);
    await escribir(
      tester,
      'titulo',
      '¿Debería ampliarse el horario del bus universitario?',
    );
    await siguiente(tester);
  }

  Future<void> abrirInvestigacion(WidgetTester tester) async {
    await hastaContexto(tester);
    await tocar(tester, find.byKey(const Key('abrir-investigacion')));
  }

  Future<void> confirmar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('confirmar-envio')));
    await tester.pumpAndSettle();
  }

  group('referencias', () {
    testWidgets('el acceso es opcional y requiere categoría y pregunta', (
      tester,
    ) async {
      await abrirApp(tester);
      await irAPestana(tester, 'Debates');
      await tester.tap(find.byKey(const Key('crear-debate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('campo-categoria')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movilidad').last);
      await tester.pumpAndSettle();
      await escribir(tester, 'ambito', 'Estudiantes de la ciudad');
      await siguiente(tester);
      await escribir(tester, 'titulo', 'Corta');
      // La validación del paso impide avanzar sin pregunta suficiente.
      await siguiente(tester);
      expect(find.byKey(const Key('abrir-investigacion')), findsNothing);
      await escribir(
        tester,
        'titulo',
        '¿Debería ampliarse el horario del bus universitario?',
      );
      await siguiente(tester);
      final boton = tester.widget<OutlinedButton>(
        find.byKey(const Key('abrir-investigacion')),
      );
      expect(boton.onPressed, isNotNull);
      expect(servidor.contar('POST /borradores/{id}/referencias/buscar'), 0);
    });

    testWidgets(
      'buscar explica lo que se envía, muestra metadatos y añade al borrador',
      (tester) async {
        await abrirApp(tester);
        await abrirInvestigacion(tester);
        expect(find.textContaining('Todo es opcional'), findsOneWidget);
        expect(servidor.contar('POST /borradores/{id}/referencias/buscar'), 0);

        await tocar(tester, find.byKey(const Key('buscar-referencias')));
        expect(
          find.textContaining(
            '"¿Debería ampliarse el horario del bus universitario? Estudiantes de la ciudad"',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Crossref'), findsWidgets);
        await confirmar(tester);

        expect(servidor.contar('POST /borradores/{id}/referencias/buscar'), 1);
        await ver(tester, find.text('Transporte nocturno y seguridad'));
        expect(find.text('Transporte nocturno y seguridad'), findsOneWidget);
        expect(find.textContaining('Localizada en Crossref el'), findsWidgets);
        expect(find.textContaining('no certifica su calidad'), findsWidgets);
        expect(find.textContaining('verificad'), findsNothing);

        await tocar(
          tester,
          find.byKey(const Key('anadir-10.1234/movilidad.2024.001')),
        );
        await ver(tester, find.text('En tu borrador (1 de 8)'));
        expect(find.text('En tu borrador (1 de 8)'), findsOneWidget);
        expect(
          (servidor.borradores.single['referencias'] as List).single['doi'],
          '10.1234/movilidad.2024.001',
        );
        // Solo se envió el DOI: los metadatos los pone el servidor.
        final peticion = servidor.peticiones.lastWhere(
          (p) => p.path.endsWith('/referencias'),
        );
        expect(peticion.data, {'doi': '10.1234/movilidad.2024.001'});
      },
    );

    testWidgets(
      'abrir usa HTTPS a doi.org y, si falla, ofrece copiar el enlace',
      (tester) async {
        await abrirApp(tester);
        await abrirInvestigacion(tester);
        await tocar(tester, find.byKey(const Key('buscar-referencias')));
        await confirmar(tester);

        await tocar(
          tester,
          find.byKey(const Key('abrir-10.1234/movilidad.2024.001')),
        );
        expect(
          abridor.abiertos.single.toString(),
          'https://doi.org/10.1234/movilidad.2024.001',
        );

        abridor.resultado = false;
        String? copiado;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (llamada) async {
            if (llamada.method == 'Clipboard.setData') {
              copiado = (llamada.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        await tocar(
          tester,
          find.byKey(const Key('abrir-10.1234/movilidad.2024.001')),
        );
        expect(find.text('No se pudo abrir el navegador.'), findsOneWidget);
        await tester.tap(find.text('Copiar enlace'));
        await tester.pump();
        expect(copiado, 'https://doi.org/10.1234/movilidad.2024.001');
      },
    );

    test('solo se construyen enlaces HTTPS desde DOI válidos', () {
      expect(enlaceDoi('javascript:alert(1)'), isNull);
      expect(enlaceDoi('10.1/x'), isNull);
      expect(enlaceDoi('10.1234/a b'), isNull);
      expect(
        enlaceDoi('10.1234/abc(1)')?.toString(),
        'https://doi.org/10.1234/abc(1)',
      );
    });

    testWidgets(
      'sin resultados, error con reintento y servicio no configurado',
      (tester) async {
        servidor.resultadosBusqueda = [];
        await abrirApp(tester);
        await abrirInvestigacion(tester);
        await tocar(tester, find.byKey(const Key('buscar-referencias')));
        await confirmar(tester);
        await ver(tester, find.byKey(const Key('sin-resultados')));
        expect(find.byKey(const Key('sin-resultados')), findsOneWidget);

        servidor.cuando(
          'POST /borradores/{id}/referencias/buscar',
          (_) => const RespuestaFalsa(429, {
            'detail': {'codigo': 'cuota_proveedor', 'mensaje': 'x'},
          }),
        );
        await tocar(tester, find.byKey(const Key('buscar-referencias')));
        await confirmar(tester);
        await ver(tester, find.textContaining('limitó las consultas'));
        expect(find.textContaining('limitó las consultas'), findsOneWidget);
        expect(find.text('Reintentar'), findsWidgets);
      },
    );

    testWidgets('búsqueda no configurada en el servidor', (tester) async {
      servidor.busquedaDisponible = false;
      await abrirApp(tester);
      await abrirInvestigacion(tester);
      expect(find.textContaining('no está configurada'), findsOneWidget);
      expect(find.byKey(const Key('buscar-referencias')), findsNothing);
    });
  });

  group('redacción con IA (simulada)', () {
    testWidgets('desactivada por defecto', (tester) async {
      await abrirApp(tester);
      await abrirInvestigacion(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('redaccion-desactivada')),
        200,
        scrollable: vertical(),
      );
      expect(find.byKey(const Key('redaccion-desactivada')), findsOneWidget);
      expect(find.byKey(const Key('redactar')), findsNothing);
    });

    testWidgets(
      'aceptar con vista previa, descartar y conservar las demás pendientes',
      (tester) async {
        servidor.redaccionDisponible = true;
        await abrirApp(tester);
        await abrirInvestigacion(tester);
        await tocar(tester, find.byKey(const Key('redactar')));
        await confirmar(tester);
        expect(servidor.contar('POST /borradores/{id}/redaccion'), 1);
        await ver(tester, find.byKey(const Key('sugerencia-ctx1')));
        expect(find.textContaining('pendiente de revisión'), findsWidgets);
        // Nada se aplica sin aceptar.
        expect(servidor.borradores.single['contexto'], isNull);

        await tocar(tester, find.byKey(const Key('descartar-per1')));
        expect(find.byKey(const Key('sugerencia-per1')), findsNothing);
        expect(find.byKey(const Key('sugerencia-ctx1')), findsOneWidget);
        expect(find.byKey(const Key('sugerencia-pre1')), findsOneWidget);

        await tocar(tester, find.byKey(const Key('aceptar-ctx1')));
        expect(find.byKey(const Key('vista-previa')), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirmar-sugerencia')));
        await tester.pumpAndSettle();

        expect(
          servidor.borradores.single['contexto'],
          'SIMULADA: el horario afecta a quienes estudian y trabajan.',
        );
        expect(find.byKey(const Key('sugerencia-ctx1')), findsNothing);
        expect(find.byKey(const Key('sugerencia-pre1')), findsOneWidget);
        await ver(tester, find.text('Sugerencias que aceptaste'));
        expect(find.text('Sugerencias que aceptaste'), findsOneWidget);
        expect(
          find.textContaining('Procedencia: sugerencia de IA'),
          findsOneWidget,
        );

        // De vuelta al asistente, el campo muestra el contexto aplicado.
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.text(
            'SIMULADA: el horario afecta a quienes estudian y trabajan.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('sustituir un contexto escrito avisa antes de aplicar', (
      tester,
    ) async {
      servidor.redaccionDisponible = true;
      await abrirApp(tester);
      await hastaContexto(tester);
      await escribir(
        tester,
        'contexto',
        'Texto propio del contexto con suficiente longitud para el debate de prueba.',
      );
      await tocar(tester, find.byKey(const Key('abrir-investigacion')));
      await tocar(tester, find.byKey(const Key('redactar')));
      await confirmar(tester);
      await tocar(tester, find.byKey(const Key('aceptar-ctx1')));
      await tester.tap(find.byKey(const Key('modo-sustituir')));
      await tester.pumpAndSettle();
      expect(
        find.text('Se reemplazará el texto que escribiste.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        servidor.borradores.single['contexto'],
        'Texto propio del contexto con suficiente longitud para el debate de prueba.',
      );
    });
  });

  group('publicación', () {
    testWidgets(
      'el detalle muestra fuentes y procedencia sin presentarlas como verificadas',
      (tester) async {
        servidor.debates.add({
          ...servidor.debates.first,
          'id': 400,
          'titulo': '¿Debería ampliarse el horario del bus universitario?',
          'procedencia': 'usuario',
          'autor_id': 2,
          'referencias': [
            ServidorFalso.referenciaFalsa(
              '10.1234/movilidad.2024.001',
              'Transporte nocturno y seguridad',
            ),
          ],
          'evidencias': [
            {
              'id': 'ev1',
              'tipo': 'contexto',
              'campo': 'contexto',
              'procedencia': 'sugerencia_ia',
              'texto_sugerido': 'x',
              'texto_aceptado': 'x',
              'editada': true,
              'referencias': <String>[],
              'requiere_revision': false,
              'aceptada_en': '2026-10-25T11:00:00Z',
              'presente_al_publicar': true,
            },
          ],
        });
        await abrirApp(tester);
        await irAPestana(tester, 'Debates');
        await tocar(
          tester,
          find.text('¿Debería ampliarse el horario del bus universitario?'),
        );
        await ver(tester, find.byKey(const Key('fuentes')));
        await ver(tester, find.byKey(const Key('procedencia-ev1')));
        expect(find.text('Transporte nocturno y seguridad'), findsOneWidget);
        expect(find.textContaining('no está verificada'), findsOneWidget);
        expect(find.textContaining('no certifica su calidad'), findsWidgets);
        await tocar(
          tester,
          find.byKey(const Key('abrir-10.1234/movilidad.2024.001')),
        );
        expect(abridor.abiertos.single.host, 'doi.org');
      },
    );

    testWidgets('un debate anterior no muestra sección de fuentes', (
      tester,
    ) async {
      await abrirApp(tester);
      await irAPestana(tester, 'Debates');
      await tocar(tester, find.text('Debate sintético 1'));
      expect(find.byKey(const Key('fuentes')), findsNothing);
    });

    test(
      'publicar copia referencias y procedencia pública (servidor simulado)',
      () async {
        final cliente = servidor.cliente();
        final sesion = SesionController(
          AuthRepository(cliente, AlmacenFalso()),
        );
        await sesion.iniciarSesion(emailAna, passwordAna);
        servidor.borradores.add({
          'id': 9,
          'autor_id': 1,
          'titulo': '¿Debería ampliarse el horario del bus universitario?',
          'categoria': 'movilidad',
          'ambito': 'Ciudad',
          'resumen': 'Resumen suficiente.',
          'contexto': 'Contexto suficiente.',
          'perspectivas': [
            {'titulo': 'A', 'descripcion': 'B'},
            {'titulo': 'C', 'descripcion': 'D'},
          ],
          'objetivo': 'Objetivo suficiente.',
          'paso': 6,
          'debate_id': null,
          'creado_en': '2026-10-25T10:00:00Z',
          'actualizado_en': '2026-10-25T10:00:00Z',
          'referencias': [ServidorFalso.referenciaFalsa('10.1234/x.1', 'Obra')],
          'evidencias': [
            {'campo': 'contexto', 'id': 'e1'},
            {'campo': 'preguntas', 'id': 'e2'},
          ],
        });
        final debate = await BorradoresRepository(cliente)
            .publicar('token-ana', 9);
        final publicado = servidor.debates.firstWhere(
          (d) => d['id'] == debate.id,
        );
        expect((publicado['referencias'] as List).single['doi'], '10.1234/x.1');
        expect(
          [for (final e in publicado['evidencias'] as List) e['campo']],
          ['contexto'],
        );
      },
    );
  });

  group('pantallas estrechas y texto ampliado', () {
    for (final caso in [
      ('pantalla estrecha', const Size(360, 1600), 1.0),
      ('texto ampliado ×2', const Size(360, 1600), 2.0),
    ]) {
      testWidgets('investigación con resultados y sugerencias (${caso.$1})', (
        tester,
      ) async {
        servidor.redaccionDisponible = true;
        await abrirApp(tester, tamano: caso.$2, escala: caso.$3);
        await abrirInvestigacion(tester);
        await tocar(tester, find.byKey(const Key('buscar-referencias')));
        await confirmar(tester);
        await tocar(tester, find.byKey(const Key('redactar')));
        await confirmar(tester);
        await tocar(tester, find.byKey(const Key('aceptar-ctx1')));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('controlador', () {
    late SesionController sesion;
    late CrearDebateController crear;
    late InvestigacionController c;

    setUp(() async {
      final cliente = servidor.cliente();
      sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
      await sesion.iniciarSesion(emailAna, passwordAna);
      crear = CrearDebateController(
        BorradoresRepository(cliente),
        DebatesRepository(cliente),
        sesion,
      )..onInit();
      crear
        ..cambiarCategoria('movilidad')
        ..cambiarAmbito('Estudiantes de la ciudad')
        ..cambiarTitulo('¿Debería ampliarse el horario del bus universitario?');
      c = InvestigacionController(
        InvestigacionRepository(cliente),
        BorradoresRepository(cliente),
        sesion,
        crear,
      )..onInit();
      await pumpEventQueue();
    });

    test('evita búsquedas duplicadas y guarda el borrador antes', () async {
      expect(servidor.borradores, hasLength(1)); // se guardó al preparar
      final a = c.buscar();
      final b = c.buscar();
      await Future.wait([a, b]);
      expect(servidor.contar('POST /borradores/{id}/referencias/buscar'), 1);
      expect(c.busqueda.value!.referencias, hasLength(2));
    });

    test('una respuesta tardía no se aplica tras cambiar de sesión', () async {
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando(
        'POST /borradores/{id}/referencias/buscar',
        (_) => respuesta.future,
      );
      final busqueda = c.buscar();
      await pumpEventQueue();
      await sesion.cerrarSesion();
      await sesion.iniciarSesion(emailBeto, passwordAna);
      respuesta.complete(
        RespuestaFalsa(200, {
          'estado': 'resultados',
          'consulta': 'x',
          'referencias': [
            ServidorFalso.referenciaFalsa('10.1234/x.1', 'Tardía'),
          ],
          'consultada_en': '2026-10-25T10:00:00Z',
        }),
      );
      await busqueda;
      expect(c.busqueda.value, isNull);
    });

    test(
      'si el borrador cambia durante la redacción, se marca y no se aplica',
      () async {
        servidor.redaccionDisponible = true;
        final real = servidor.manejador('POST /borradores/{id}/redaccion')!;
        final espera = Completer<void>();
        servidor.cuando('POST /borradores/{id}/redaccion', (p) async {
          final r = await real(p);
          await espera.future;
          return r;
        });
        final redaccion = c.redactar();
        await pumpEventQueue();
        crear.cambiarObjetivo(
          'Un objetivo que escribo mientras espero la respuesta.',
        );
        espera.complete();
        await redaccion;

        expect(c.redaccion.value!.pendientes, hasLength(3));
        expect(c.redaccionDesactualizada, isTrue);
        expect(crear.contexto.value, isEmpty); // nada aplicado automáticamente
      },
    );

    test('un campo cambiado entretanto no se sobrescribe (409)', () async {
      servidor.redaccionDisponible = true;
      await c.redactar();
      final ctx = c.redaccion.value!.pendientes.first;
      servidor.borradores.single['contexto'] = 'Cambiado en otro dispositivo.';
      await c.aceptar(ctx, modo: 'sustituir', valorVisto: '');
      expect(c.mensaje.value, contains('El campo cambió'));
      expect(
        servidor.borradores.single['contexto'],
        'Cambiado en otro dispositivo.',
      );
      expect(c.redaccion.value!.pendientes, hasLength(3));
    });
  });

  group('edad', () {
    testWidgets('el registro exige declarar 18 años o más', (tester) async {
      tokens = AlmacenFalso();
      await abrirApp(tester);
      await tester.tap(find.text('¿No tienes cuenta? Crear una cuenta'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('solo para personas de 18 años o más'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('registro-nombre')), 'Bea');
      await tester.enterText(
        find.byKey(const Key('registro-email')),
        'bea@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('registro-password')),
        'clave-de-bea-123',
      );
      await tester.ensureVisible(find.byKey(const Key('registro-enviar')));
      await tester.tap(find.byKey(const Key('registro-enviar')));
      await tester.pumpAndSettle();
      expect(
        find.text('Debes confirmar que tienes 18 años o más.'),
        findsOneWidget,
      );
      expect(servidor.contar('POST /auth/registro'), 0);

      await tester.ensureVisible(
        find.byKey(const Key('registro-mayoria-edad')),
      );
      await tester.tap(find.byKey(const Key('registro-mayoria-edad')));
      await tester.tap(find.byKey(const Key('registro-enviar')));
      await tester.pumpAndSettle();
      expect(
        servidor.peticiones.last.data,
        containsPair('confirma_mayoria_edad', true),
      );
    });

    testWidgets(
      'una cuenta existente pendiente debe confirmar antes de seguir',
      (tester) async {
        servidor.edadPendiente.add(1);
        await abrirApp(tester);
        expect(find.byKey(const Key('confirmar-edad')), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        final boton = tester.widget<FilledButton>(
          find.byKey(const Key('confirmar-edad')),
        );
        expect(boton.onPressed, isNull); // no se da por aceptada
        await tester.tap(find.byKey(const Key('confirmar-edad-casilla')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('confirmar-edad')));
        await tester.pumpAndSettle();
        expect(servidor.edadPendiente, isEmpty);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets('desde la confirmación se puede cerrar sesión', (tester) async {
      servidor.edadPendiente.add(1);
      await abrirApp(tester);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('¿No tienes cuenta? Crear una cuenta'), findsOneWidget);
      expect(servidor.edadPendiente, contains(1));
    });

    testWidgets('un 403 de edad con la app abierta lleva a la confirmación', (
      tester,
    ) async {
      await abrirApp(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      servidor.edadPendiente.add(1);
      await irAPestana(tester, 'Debates');
      await tocar(
        tester,
        find.text('Debate sintético 1'),
      ); // la consulta recibe 403
      expect(find.byKey(const Key('confirmar-edad')), findsOneWidget);
    });
  });
}

import 'package:agora_joven/app.dart';
import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

/// Pruebas de flujo con la app completa, el ApiClient real, un servidor falso y un almacén
/// de token simulado. No dependen del backend real.
void main() {
  late ServidorFalso servidor;
  late AlmacenFalso almacen;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    almacen = AlmacenFalso();
  });
  tearDown(Get.reset);

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      AgoraJovenApp(api: servidor.cliente(), tokens: almacen),
    );
    await tester.pumpAndSettle();
  }

  /// Desplaza la fila horizontal de categorías hasta que el chip sea visible.
  Future<void> verChip(
    WidgetTester tester,
    String texto, {
    double paso = 150,
  }) async {
    await tester.scrollUntilVisible(
      find.text(texto),
      paso,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      ),
    );
    // Construido no implica visible: se termina de llevar a la vista antes de pulsar.
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
  }

  Future<void> entrar(
    WidgetTester tester, {
    String password = passwordAna,
  }) async {
    await tester.enterText(find.byKey(const Key('login-email')), emailAna);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.byKey(const Key('login-enviar')));
    await tester.pumpAndSettle();
  }

  testWidgets('sin token muestra el acceso con la identidad de la app', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('Ágora Joven'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('credenciales inválidas muestran un mensaje y no entran', (
    tester,
  ) async {
    await abrir(tester);
    await entrar(tester, password: 'otra-clave');

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Debates'), findsNothing);
  });

  testWidgets('la contraseña está oculta y se puede mostrar', (tester) async {
    await abrir(tester);
    EditableText campo() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(EditableText),
      ),
    );

    expect(campo().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(campo().obscureText, isFalse);
  });

  testWidgets('login correcto muestra el catálogo y la identidad del usuario', (
    tester,
  ) async {
    await abrir(tester);
    await entrar(tester);

    expect(find.text('Debates'), findsOneWidget);
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Debate sintético 1'), findsOneWidget);
    expect(almacen.token, 'token-ana');
  });

  testWidgets('registro vuelve al acceso con aviso y el correo escrito', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('¿No tienes cuenta? Crear una cuenta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('registro-nombre')), 'Bea');
    await tester.enterText(
      find.byKey(const Key('registro-email')),
      'bea@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('registro-password')),
      'clave-de-bea-123',
    );
    await tester.tap(find.byKey(const Key('registro-enviar')));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.textContaining('Cuenta creada'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-email')))
          .controller!
          .text,
      'bea@example.com',
    );
  });

  testWidgets(
    'registro con correo duplicado muestra el aviso en el formulario',
    (tester) async {
      await abrir(tester);
      await tester.tap(find.text('¿No tienes cuenta? Crear una cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('registro-nombre')), 'Ana');
      await tester.enterText(find.byKey(const Key('registro-email')), emailAna);
      await tester.enterText(
        find.byKey(const Key('registro-password')),
        passwordAna,
      );
      await tester.tap(find.byKey(const Key('registro-enviar')));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe una cuenta con ese correo.'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsWidgets);
    },
  );

  testWidgets('filtro por categoría, detalle y vuelta al catálogo', (
    tester,
  ) async {
    almacen.token = 'token-ana';
    await abrir(tester);

    await verChip(tester, 'Movilidad (7)');
    await tester.tap(find.text('Movilidad (7)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Debate sintético 1'),
      findsNothing,
    ); // 1 % 3 = 1 → ambiente
    expect(
      find.text('Debate sintético 2'),
      findsOneWidget,
    ); // 2 % 3 = 2 → movilidad

    await tester.tap(find.text('Debate sintético 2'));
    await tester.pumpAndSettle();
    expect(find.text('Contexto'), findsOneWidget);
    expect(find.text('Contexto del debate sintético 2.'), findsOneWidget);
    expect(find.text('Perspectiva A2'), findsOneWidget);
    expect(
      find.textContaining('Material editorial de demostración'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await verChip(tester, 'Todas', paso: -150);
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Debate sintético 1'), findsOneWidget);
  });

  testWidgets('categoría vacía ofrece volver a Todas', (tester) async {
    almacen.token = 'token-ana';
    await abrir(tester);

    await verChip(tester, 'Cultura (0)');
    await tester.tap(find.text('Cultura (0)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no hay debates en esta categoría.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    expect(find.text('Debate sintético 1'), findsOneWidget);
  });

  testWidgets('error del catálogo con reintento', (tester) async {
    almacen.token = 'token-ana';
    servidor.cuando('GET /debates', sinRed);
    await abrir(tester);

    expect(find.textContaining('No se pudo conectar'), findsOneWidget);

    servidor.cuando(
      'GET /debates',
      (_) => RespuestaFalsa(200, [
        {
          for (final k in ['id', 'titulo', 'categoria', 'resumen', 'origen'])
            k: debatesFalsos[0][k],
        },
      ]),
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Debate sintético 1'), findsOneWidget);
  });

  testWidgets('detalle inexistente ofrece volver al catálogo', (tester) async {
    almacen.token = 'token-ana';
    servidor.cuando(
      'GET /debates/{id}',
      (_) => const RespuestaFalsa(404, {'detail': 'x'}),
    );
    await abrir(tester);

    await tester.tap(find.text('Debate sintético 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este debate no existe o ya no está disponible.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Volver al catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('restauración con fallo de red: reintentar conserva el token', (
    tester,
  ) async {
    almacen.token = 'token-ana';
    servidor.cuando('GET /auth/me', sinRed);
    await abrir(tester);

    expect(find.textContaining('No se pudo conectar'), findsOneWidget);
    expect(find.text('Iniciar sesión con otra cuenta'), findsOneWidget);
    expect(almacen.token, 'token-ana');

    servidor.cuando(
      'GET /auth/me',
      (_) => const RespuestaFalsa(200, {
        'id': 1,
        'nombre': 'Ana',
        'email': emailAna,
        'creado_en': '2026-10-22T00:00:00Z',
      }),
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
  });

  testWidgets('token caducado al abrir: lo borra y pide iniciar sesión', (
    tester,
  ) async {
    almacen.token = 'token-caducado';
    await abrir(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(
      find.text('Tu sesión caducó. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
    expect(almacen.token, isNull);
  });

  testWidgets(
    'sesión que caduca en el detalle vuelve al acceso con un solo aviso',
    (tester) async {
      almacen.token = 'token-ana';
      await abrir(tester);
      servidor.tokensValidos.clear();

      await tester.tap(find.text('Debate sintético 1'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(
        find.text('Tu sesión caducó. Inicia sesión de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Contexto'), findsNothing);
    },
  );

  testWidgets('cerrar sesión limpia, vuelve al acceso y Atrás no regresa', (
    tester,
  ) async {
    almacen.token = 'token-ana';
    await abrir(tester);
    await tester.tap(find.text('Debate sintético 1'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cuenta y cierre de sesión'));
    await tester.pumpAndSettle();
    expect(find.text(emailAna), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(almacen.token, isNull);
    expect(Get.isRegistered<DebatesController>(), isFalse);

    // Botón Atrás del sistema: no hay rutas protegidas debajo del acceso.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Debates'), findsNothing);
  });
}

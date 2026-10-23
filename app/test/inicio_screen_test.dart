import 'dart:async';

import 'package:agora_joven/app.dart';
import 'package:agora_joven/controllers/arranque_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets(
    'muestra la bienvenida propia de Ágora Joven al terminar el arranque',
    (tester) async {
      await tester.pumpWidget(const AgoraJovenApp());
      await tester.pumpAndSettle();

      expect(find.text('Ágora Joven'), findsOneWidget);
      expect(
        find.text(
          'Comprende temas públicos, consulta debates ciudadanos y aporta tu voz.',
        ),
        findsOneWidget,
      );
      expect(find.text('Comprende'), findsOneWidget);
      expect(find.text('Consulta'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('muestra el estado de carga mientras el arranque no termina', (
    tester,
  ) async {
    final pendiente = Completer<void>();
    await tester.pumpWidget(
      AgoraJovenApp(
        arranque: ArranqueController(tareas: [() => pendiente.future]),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparando Ágora Joven…'), findsOneWidget);

    pendiente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ágora Joven'), findsOneWidget);
  });

  testWidgets('muestra el error de arranque y permite reintentar', (
    tester,
  ) async {
    var intentos = 0;
    await tester.pumpWidget(
      AgoraJovenApp(
        arranque: ArranqueController(
          tareas: [
            () async {
              intentos++;
              if (intentos == 1) throw Exception('fallo simulado');
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo preparar la aplicación.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(intentos, 2);
    expect(find.text('Ágora Joven'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cambia de pestaña en la navegación principal (Inicio, Debates o Guardados).
Future<void> irAPestana(WidgetTester tester, String pestana) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(pestana),
    ),
  );
  await tester.pumpAndSettle();
}

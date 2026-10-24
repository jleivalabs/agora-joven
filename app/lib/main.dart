import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Directorio de Hive para los debates guardados (datos locales de la app).
    await Hive.initFlutter();
  } catch (_) {
    // Sin almacén local la app funciona; la pantalla Guardados mostrará el error de lectura.
  }
  runApp(const AgoraJovenApp());
}

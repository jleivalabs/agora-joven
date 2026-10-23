import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/arranque_controller.dart';
import 'screens/inicio_screen.dart';
import 'theme/app_theme.dart';

class AgoraJovenApp extends StatelessWidget {
  const AgoraJovenApp({super.key, this.arranque});

  /// Permite inyectar un controlador de arranque en las pruebas.
  final ArranqueController? arranque;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Ágora Joven',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      initialBinding: BindingsBuilder(() {
        Get.put<ArranqueController>(arranque ?? ArranqueController());
      }),
      home: const InicioScreen(),
    );
  }
}

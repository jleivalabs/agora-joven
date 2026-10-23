import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/app_config.dart';
import 'controllers/sesion_controller.dart';
import 'data/api_client.dart';
import 'data/token_storage.dart';
import 'repositories/auth_repository.dart';
import 'repositories/debates_repository.dart';
import 'screens/raiz_screen.dart';
import 'theme/app_theme.dart';

class AgoraJovenApp extends StatelessWidget {
  const AgoraJovenApp({super.key, this.api, this.tokens});

  /// Permiten inyectar un servidor falso y un almacén simulado en las pruebas.
  final ApiClient? api;
  final TokenStorage? tokens;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Ágora Joven',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      initialBinding: BindingsBuilder(() {
        final cliente = api ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);
        Get.put(AuthRepository(cliente, tokens ?? SecureTokenStorage()));
        Get.put(DebatesRepository(cliente));
        Get.put(SesionController(Get.find()));
      }),
      home: const RaizScreen(),
    );
  }
}

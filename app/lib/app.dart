import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/app_config.dart';
import 'controllers/actividad_comunidad.dart';
import 'controllers/guardados_controller.dart';
import 'controllers/sesion_controller.dart';
import 'data/abridor_enlaces.dart';
import 'data/api_client.dart';
import 'data/guardados_local.dart';
import 'data/token_storage.dart';
import 'repositories/aportes_repository.dart';
import 'repositories/asistente_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/borradores_repository.dart';
import 'repositories/solicitudes_repository.dart';
import 'repositories/debates_repository.dart';
import 'repositories/estadisticas_repository.dart';
import 'repositories/guardados_repository.dart';
import 'repositories/investigacion_repository.dart';
import 'screens/raiz_screen.dart';
import 'theme/app_theme.dart';

class AgoraJovenApp extends StatelessWidget {
  const AgoraJovenApp({
    super.key,
    this.api,
    this.tokens,
    this.guardados,
    this.abridor,
  });

  /// Permiten inyectar un servidor falso y un almacén simulado en las pruebas.
  final ApiClient? api;
  final TokenStorage? tokens;
  final AlmacenGuardados? guardados;

  /// Apertura de enlaces externos (navegador del sistema por defecto).
  final AbridorEnlaces? abridor;

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
        Get.put(AportesRepository(cliente));
        Get.put(AsistenteRepository(cliente));
        Get.put(EstadisticasRepository(cliente));
        Get.put(BorradoresRepository(cliente));
        Get.put(SolicitudesRepository(cliente));
        Get.put(InvestigacionRepository(cliente));
        Get.put<AbridorEnlaces>(abridor ?? NavegadorExterno());
        Get.put(ActividadComunidad());
        Get.put(GuardadosRepository(guardados ?? HiveAlmacenGuardados()));
        Get.put(SesionController(Get.find()));
        Get.put(GuardadosController(Get.find(), Get.find()));
      }),
      home: const RaizScreen(),
    );
  }
}

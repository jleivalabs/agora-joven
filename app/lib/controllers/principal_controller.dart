import 'package:get/get.dart';

import 'debates_controller.dart';

enum SeccionPrincipal { inicio, debates, guardados }

/// Pestaña visible de la navegación principal de la sesión.
class PrincipalController extends GetxController {
  final seccion = SeccionPrincipal.inicio.obs;

  void ir(SeccionPrincipal destino) => seccion.value = destino;

  /// Abre el catálogo filtrado por [categoria] (null = Todas).
  void irADebates({String? categoria}) {
    if (Get.isRegistered<DebatesController>()) {
      Get.find<DebatesController>().seleccionar(categoria);
    }
    seccion.value = SeccionPrincipal.debates;
  }
}

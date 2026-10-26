import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/actividad_comunidad.dart';
import '../controllers/inicio_controller.dart';
import '../controllers/principal_controller.dart';
import 'debates_screen.dart';
import 'guardados_screen.dart';
import 'inicio_screen.dart';

/// Navegación principal de la sesión: Inicio, Debates y Guardados.
///
/// Crea los controladores de la sesión al aparecer y los elimina al desaparecer (al cerrar
/// sesión la raíz deja de mostrar esta pantalla), así no quedan datos de la cuenta anterior.
/// Las pestañas se conservan en un IndexedStack para no perder filtros ni desplazamientos.
class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key});

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  late final PrincipalController _principal;

  @override
  void initState() {
    super.initState();
    _principal = Get.put(PrincipalController());
    Get.put(
      InicioController(
        Get.find(),
        Get.find(),
        Get.isRegistered<ActividadComunidad>()
            ? Get.find<ActividadComunidad>()
            : null,
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<InicioController>();
    Get.delete<PrincipalController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final seccion = _principal.seccion.value;
      return Scaffold(
        body: IndexedStack(
          index: seccion.index,
          children: [
            const InicioScreen(),
            const DebatesScreen(),
            GuardadosScreen(
              onIrAlCatalogo: () => _principal.ir(SeccionPrincipal.debates),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: seccion.index,
          onDestinationSelected: (i) =>
              _principal.ir(SeccionPrincipal.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Debates',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmarks_outlined),
              selectedIcon: Icon(Icons.bookmarks),
              label: 'Guardados',
            ),
          ],
        ),
      );
    });
  }
}

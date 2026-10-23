import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sesion_controller.dart';
import '../widgets/estados.dart';
import 'debates_screen.dart';
import 'login_screen.dart';

/// Primera ruta de la app: muestra acceso o catálogo según el estado de sesión.
///
/// Al cambiar de estado se reemplaza el contenido (no se apila), así que tras cerrar sesión
/// el botón Atrás no puede volver a pantallas protegidas.
class RaizScreen extends StatelessWidget {
  const RaizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = Get.find<SesionController>();

    return Obx(() {
      switch (sesion.estado.value) {
        case EstadoSesion.restaurando:
          return const Scaffold(
            body: EstadoCargando(mensaje: 'Preparando Ágora Joven…'),
          );
        case EstadoSesion.errorRestauracion:
          return Scaffold(
            body: SafeArea(
              child: EstadoError(
                mensaje:
                    sesion.errorRestauracion.value ??
                    'No se pudo comprobar tu sesión.',
                onReintentar: sesion.restaurar,
                textoSecundario: 'Iniciar sesión con otra cuenta',
                onSecundario: sesion.cerrarSesion,
              ),
            ),
          );
        case EstadoSesion.sinSesion:
          return const LoginScreen();
        case EstadoSesion.autenticada:
          return const DebatesScreen();
      }
    });
  }
}

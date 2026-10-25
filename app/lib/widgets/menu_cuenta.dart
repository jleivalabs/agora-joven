import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sesion_controller.dart';

/// Menú de la cuenta (nombre, correo propio y "Cerrar sesión"), presente en las tres pestañas.
class MenuCuenta extends StatelessWidget {
  const MenuCuenta({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = Get.find<SesionController>();
    return PopupMenuButton<String>(
      tooltip: 'Cuenta y cierre de sesión',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (opcion) {
        if (opcion == 'salir') sesion.cerrarSesion();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(sesion.usuario.value?.nombre ?? ''),
            subtitle: Text(sesion.usuario.value?.email ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'salir',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}

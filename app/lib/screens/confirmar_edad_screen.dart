import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sesion_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/marca.dart';

/// Textos de la declaración de edad (registro y cuentas existentes).
class EdadTextos {
  EdadTextos._();

  static const aviso =
      'Ágora Joven es solo para personas de 18 años o más. Es una declaración tuya: no '
      'verificamos la edad ni pedimos documentos ni fecha de nacimiento.';
  static const casilla = 'Declaro que tengo 18 años o más.';
}

/// Cuenta existente sin declaración de edad: debe confirmar antes de seguir. No se da por
/// aceptada automáticamente; la otra salida es cerrar sesión.
class ConfirmarEdadScreen extends StatefulWidget {
  const ConfirmarEdadScreen({super.key});

  @override
  State<ConfirmarEdadScreen> createState() => _ConfirmarEdadScreenState();
}

// setState solo para la casilla, estado local de esta pantalla.
class _ConfirmarEdadScreenState extends State<ConfirmarEdadScreen> {
  final _sesion = Get.find<SesionController>();
  bool _marcada = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Obx(() {
            final enviando = _sesion.enviando.value;
            final error = _sesion.errorFormulario.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Marca(subtitulo: 'Antes de continuar'),
                const SizedBox(height: AppSpacing.l),
                Text(
                  'Hola, ${_sesion.usuario.value?.nombre ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s),
                const Text(EdadTextos.aviso),
                const SizedBox(height: AppSpacing.m),
                CheckboxListTile(
                  key: const Key('confirmar-edad-casilla'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _marcada,
                  onChanged: enviando
                      ? null
                      : (v) => setState(() => _marcada = v ?? false),
                  title: const Text(EdadTextos.casilla),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.s),
                  Aviso(texto: error, esError: true),
                ],
                const SizedBox(height: AppSpacing.m),
                FilledButton(
                  key: const Key('confirmar-edad'),
                  onPressed: _marcada && !enviando
                      ? _sesion.confirmarEdad
                      : null,
                  child: enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Enviando confirmación',
                          ),
                        )
                      : const Text('Confirmar y continuar'),
                ),
                const SizedBox(height: AppSpacing.s),
                TextButton(
                  onPressed: enviando ? null : _sesion.cerrarSesion,
                  child: const Text('Cerrar sesión'),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

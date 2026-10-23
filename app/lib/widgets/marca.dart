import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Encabezado de identidad de Ágora Joven para las pantallas de acceso.
class Marca extends StatelessWidget {
  const Marca({super.key, required this.subtitulo});

  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.forum_outlined, size: 48, color: colores.primary),
        const SizedBox(height: AppSpacing.s),
        Text(
          'Ágora Joven',
          style: texto.headlineLarge?.copyWith(
            color: colores.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitulo, style: texto.titleMedium),
      ],
    );
  }
}

/// Mensaje destacado (informativo o de error) dentro de un formulario o detalle.
class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.texto, this.esError = false});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final fondo = esError ? colores.errorContainer : colores.secondaryContainer;
    final frente = esError
        ? colores.onErrorContainer
        : colores.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.info_outline,
            color: frente,
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(texto, style: TextStyle(color: frente)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Estados comunes de las pantallas con datos: cargando, vacío y error.
class EstadoCargando extends StatelessWidget {
  const EstadoCargando({super.key, this.mensaje = 'Cargando…'});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.m),
          Text(mensaje),
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.mensaje,
    this.textoAccion,
    this.onAccion,
  });

  final String mensaje;
  final String? textoAccion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return _EstadoConIcono(
      icono: Icons.inbox_outlined,
      color: Theme.of(context).colorScheme.outline,
      mensaje: mensaje,
      acciones: [
        if (textoAccion != null)
          OutlinedButton(onPressed: onAccion, child: Text(textoAccion!)),
      ],
    );
  }
}

class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
    this.textoSecundario,
    this.onSecundario,
  });

  final String mensaje;
  final VoidCallback onReintentar;
  final String? textoSecundario;
  final VoidCallback? onSecundario;

  @override
  Widget build(BuildContext context) {
    return _EstadoConIcono(
      icono: Icons.cloud_off_outlined,
      color: Theme.of(context).colorScheme.error,
      mensaje: mensaje,
      acciones: [
        FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
        if (textoSecundario != null)
          TextButton(onPressed: onSecundario, child: Text(textoSecundario!)),
      ],
    );
  }
}

class _EstadoConIcono extends StatelessWidget {
  const _EstadoConIcono({
    required this.icono,
    required this.color,
    required this.mensaje,
    required this.acciones,
  });

  final IconData icono;
  final Color color;
  final String mensaje;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: color),
            const SizedBox(height: AppSpacing.m),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.m),
            ...acciones,
          ],
        ),
      ),
    );
  }
}

/// Estado compacto para una sección dentro de una lista desplazable (sin scroll propio).
class EstadoEnLinea extends StatelessWidget {
  const EstadoEnLinea({
    super.key,
    required this.mensaje,
    this.icono = Icons.info_outline,
    this.esError = false,
    this.textoAccion,
    this.onAccion,
  });

  final String mensaje;
  final IconData icono;
  final bool esError;
  final String? textoAccion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Column(
        children: [
          Icon(icono, color: esError ? colores.error : colores.outline),
          const SizedBox(height: AppSpacing.s),
          Text(mensaje, textAlign: TextAlign.center),
          if (textoAccion != null) ...[
            const SizedBox(height: AppSpacing.s),
            OutlinedButton(onPressed: onAccion, child: Text(textoAccion!)),
          ],
        ],
      ),
    );
  }
}

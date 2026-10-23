import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/arranque_controller.dart';
import '../theme/app_theme.dart';

/// Pantalla inicial: muestra la identidad de Ágora Joven según el estado de arranque.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arranque = Get.find<ArranqueController>();

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          switch (arranque.estado.value) {
            case EstadoArranque.cargando:
              return const _Cargando();
            case EstadoArranque.error:
              return _ErrorArranque(
                mensaje: arranque.mensajeError.value ?? 'Error inesperado.',
                onReintentar: arranque.iniciar,
              );
            case EstadoArranque.listo:
              return const _Bienvenida();
          }
        }),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.m),
          Text('Preparando Ágora Joven…'),
        ],
      ),
    );
  }
}

class _ErrorArranque extends StatelessWidget {
  const _ErrorArranque({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        const SizedBox(height: AppSpacing.l),
        Icon(Icons.forum_outlined, size: 56, color: colores.primary),
        const SizedBox(height: AppSpacing.m),
        Text(
          'Ágora Joven',
          style: texto.headlineLarge?.copyWith(
            color: colores.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          'Comprende temas públicos, consulta debates ciudadanos y aporta tu voz.',
          style: texto.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        const _Pilar(
          icono: Icons.menu_book_outlined,
          titulo: 'Comprende',
          descripcion: 'Contexto claro y equilibrado de cada tema público.',
        ),
        const SizedBox(height: AppSpacing.m),
        const _Pilar(
          icono: Icons.groups_outlined,
          titulo: 'Consulta',
          descripcion:
              'Debates por categoría con las perspectivas de otras personas.',
        ),
        const SizedBox(height: AppSpacing.m),
        const _Pilar(
          icono: Icons.record_voice_over_outlined,
          titulo: 'Participa',
          descripcion:
              'Publica preguntas, argumentos o propuestas con respeto.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Versión base en construcción.',
          textAlign: TextAlign.center,
          style: texto.bodySmall?.copyWith(color: colores.outline),
        ),
      ],
    );
  }
}

class _Pilar extends StatelessWidget {
  const _Pilar({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        leading: Icon(icono, color: AppColors.acento),
        title: Text(titulo),
        subtitle: Text(descripcion),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/asistente_controller.dart';
import '../models/asistente.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import '../widgets/texto_markdown_seguro.dart';

/// Sección del detalle con las dos acciones del asistente educativo.
///
/// El resultado se muestra identificado como generado por IA; no se guarda ni se publica.
class SeccionAsistente extends StatelessWidget {
  const SeccionAsistente({super.key, required this.asistente});

  final AsistenteController asistente;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Obx(() {
          final cargando = asistente.estado.value == EstadoAsistente.cargando;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.acento,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text('Asistente educativo', style: texto.titleLarge),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Te ayuda a comprender el debate. Usa IA y puede equivocarse.',
                style: texto.bodySmall,
              ),
              const SizedBox(height: AppSpacing.m),
              for (final accion in AccionAsistente.values) ...[
                OutlinedButton.icon(
                  key: Key('asistente-${accion.name}'),
                  onPressed: cargando
                      ? null
                      : () => asistente.consultar(accion),
                  icon: Icon(
                    accion == AccionAsistente.contexto
                        ? Icons.lightbulb_outline
                        : Icons.balance_outlined,
                  ),
                  label: Text(accion.etiqueta),
                ),
                const SizedBox(height: AppSpacing.s),
              ],
              _Resultado(asistente: asistente),
            ],
          );
        }),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.asistente});

  final AsistenteController asistente;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    switch (asistente.estado.value) {
      case EstadoAsistente.inicial:
        return const SizedBox.shrink();
      case EstadoAsistente.cargando:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            children: [
              const CircularProgressIndicator(
                semanticsLabel: 'Consultando al asistente',
              ),
              const SizedBox(height: AppSpacing.s),
              Text('${asistente.accion.value?.etiqueta ?? 'Consultando'}…'),
            ],
          ),
        );
      case EstadoAsistente.sinAportes:
        return const EstadoEnLinea(
          icono: Icons.forum_outlined,
          mensaje:
              'Este debate todavía no tiene aportes que resumir. Cuando la comunidad '
              'participe, podrás pedir el resumen de perspectivas.',
        );
      case EstadoAsistente.error:
        return EstadoEnLinea(
          esError: true,
          icono: Icons.cloud_off_outlined,
          mensaje:
              asistente.error.value ?? 'No se pudo consultar al asistente.',
          textoAccion: 'Reintentar',
          onAccion: asistente.reintentar,
        );
      case EstadoAsistente.listo:
        final r = asistente.respuesta.value!;
        return Container(
          key: const Key('asistente-resultado'),
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: colores.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: colores.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Generado por IA · ${r.accion.etiqueta}',
                      style: texto.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              // La IA responde en Markdown: se renderiza, sin HTML, imágenes ni enlaces activos.
              TextoMarkdownSeguro(texto: r.texto ?? ''),
              const SizedBox(height: AppSpacing.s),
              if (r.accion == AccionAsistente.perspectivas && r.parcial)
                Text(
                  'Basado en ${r.aportesUsados} de ${r.aportesTotales} aportes '
                  '(los más recientes).',
                  style: texto.bodySmall,
                ),
              if (r.truncado)
                Text(
                  'La respuesta alcanzó el límite de longitud y puede estar incompleta.',
                  style: texto.bodySmall,
                ),
              Text(
                r.aviso ??
                    'Texto generado por IA; puede contener errores. No se publica '
                        'como aporte.',
                style: texto.bodySmall?.copyWith(color: colores.outline),
              ),
            ],
          ),
        );
    }
  }
}

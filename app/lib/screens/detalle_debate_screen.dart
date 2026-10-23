import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/debates_controller.dart';
import '../controllers/detalle_debate_controller.dart';
import '../models/debate.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import '../widgets/marca.dart';

class DetalleDebateScreen extends StatefulWidget {
  const DetalleDebateScreen({
    super.key,
    required this.debateId,
    required this.titulo,
    required this.etiquetaCategoria,
  });

  final int debateId;
  final String titulo;
  final String etiquetaCategoria;

  @override
  State<DetalleDebateScreen> createState() => _DetalleDebateScreenState();
}

class _DetalleDebateScreenState extends State<DetalleDebateScreen> {
  late final DetalleDebateController _detalle;
  late final String _etiqueta = '${widget.debateId}';

  @override
  void initState() {
    super.initState();
    _detalle = Get.put(
      DetalleDebateController(Get.find(), Get.find(), widget.debateId),
      tag: _etiqueta,
    );
  }

  @override
  void dispose() {
    Get.delete<DetalleDebateController>(tag: _etiqueta);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debate')),
      body: Obx(() {
        switch (_detalle.estado.value) {
          case EstadoCarga.cargando:
          case EstadoCarga.vacio:
            return const EstadoCargando(mensaje: 'Cargando debate…');
          case EstadoCarga.error:
            return EstadoError(
              mensaje: _detalle.error.value ?? 'No se pudo cargar el debate.',
              onReintentar: _detalle.cargar,
              textoSecundario: 'Volver al catálogo',
              onSecundario: () => Get.back<void>(),
            );
          case EstadoCarga.listo:
            return _Contenido(
              debate: _detalle.debate.value!,
              etiquetaCategoria: widget.etiquetaCategoria,
            );
        }
      }),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.debate, required this.etiquetaCategoria});

  final DebateDetalle debate;
  final String etiquetaCategoria;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.m),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(etiquetaCategoria)),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(debate.titulo, style: texto.headlineSmall),
        const SizedBox(height: AppSpacing.m),
        Aviso(
          texto:
              '${debate.origen}. Contenido de ejemplo con fines educativos; '
              'no representa posiciones oficiales.',
        ),
        const SizedBox(height: AppSpacing.m),
        Text(debate.resumen, style: texto.titleMedium),
        const SizedBox(height: AppSpacing.l),
        Text('Contexto', style: texto.titleLarge),
        const SizedBox(height: AppSpacing.s),
        Text(debate.contexto, style: texto.bodyLarge),
        const SizedBox(height: AppSpacing.l),
        Text('Perspectivas', style: texto.titleLarge),
        const SizedBox(height: AppSpacing.s),
        for (final p in debate.perspectivas) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.titulo, style: texto.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(p.descripcion),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ],
    );
  }
}

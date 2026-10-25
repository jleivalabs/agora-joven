import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/actividad_aportes.dart';
import '../controllers/aportes_controller.dart';
import '../controllers/asistente_controller.dart';
import '../controllers/debates_controller.dart';
import '../controllers/detalle_debate_controller.dart';
import '../controllers/guardados_controller.dart';
import '../models/aporte.dart';
import '../models/debate.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import '../widgets/marca.dart';
import 'aporte_form_screen.dart';
import 'seccion_asistente.dart';

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
  late final AportesController _aportes;
  late final AsistenteController _asistente;
  late final String _etiqueta = '${widget.debateId}';

  @override
  void initState() {
    super.initState();
    _detalle = Get.put(
      DetalleDebateController(Get.find(), Get.find(), widget.debateId),
      tag: _etiqueta,
    );
    _aportes = Get.put(
      AportesController(
        Get.find(),
        Get.find(),
        widget.debateId,
        actividad: Get.isRegistered<ActividadAportes>()
            ? Get.find<ActividadAportes>()
            : null,
      ),
      tag: _etiqueta,
    );
    _asistente = Get.put(
      AsistenteController(Get.find(), Get.find(), widget.debateId),
      tag: _etiqueta,
    );
  }

  @override
  void dispose() {
    Get.delete<DetalleDebateController>(tag: _etiqueta);
    Get.delete<AportesController>(tag: _etiqueta);
    Get.delete<AsistenteController>(tag: _etiqueta);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debate'),
        actions: [
          _BotonGuardar(
            detalle: _detalle,
            etiquetaCategoria: widget.etiquetaCategoria,
          ),
        ],
      ),
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
              aportes: _aportes,
              asistente: _asistente,
            );
        }
      }),
    );
  }
}

/// Guardar o quitar el debate de guardados. Solo aparece cuando el detalle está cargado.
class _BotonGuardar extends StatelessWidget {
  const _BotonGuardar({required this.detalle, required this.etiquetaCategoria});

  final DetalleDebateController detalle;
  final String etiquetaCategoria;

  @override
  Widget build(BuildContext context) {
    final guardados = Get.find<GuardadosController>();
    return Obx(() {
      final debate = detalle.debate.value;
      if (debate == null) return const SizedBox.shrink();
      if (guardados.pendientes.contains(debate.id)) {
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.m),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
              semanticsLabel: 'Actualizando guardados',
            ),
          ),
        );
      }
      final guardado = guardados.estaGuardado(debate.id);
      return IconButton(
        tooltip: guardado ? 'Quitar de guardados' : 'Guardar debate',
        icon: Icon(guardado ? Icons.bookmark : Icons.bookmark_border),
        onPressed: () async {
          final mensaje = guardado
              ? await guardados.quitar(debate.id)
              : await guardados.guardar(debate, etiquetaCategoria);
          if (mensaje != null && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(mensaje)));
          }
        },
      );
    });
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.debate,
    required this.etiquetaCategoria,
    required this.aportes,
    required this.asistente,
  });

  final DebateDetalle debate;
  final String etiquetaCategoria;
  final AportesController aportes;
  final AsistenteController asistente;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: aportes.cargar,
      child: ListView(
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
          const SizedBox(height: AppSpacing.l),
          SeccionAsistente(asistente: asistente),
          const SizedBox(height: AppSpacing.l),
          _SeccionAportes(debateId: debate.id, aportes: aportes),
        ],
      ),
    );
  }
}

class _SeccionAportes extends StatelessWidget {
  const _SeccionAportes({required this.debateId, required this.aportes});

  final int debateId;
  final AportesController aportes;

  void _abrirFormulario([Aporte? aporte]) {
    Get.to<void>(() => AporteFormScreen(debateId: debateId, aporte: aporte));
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Aportes', style: texto.titleLarge)),
            IconButton(
              tooltip: 'Actualizar aportes',
              icon: const Icon(Icons.refresh),
              onPressed: aportes.cargar,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        FilledButton.icon(
          key: const Key('aporte-nuevo'),
          onPressed: _abrirFormulario,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Publicar un aporte'),
        ),
        const SizedBox(height: AppSpacing.m),
        Obx(() {
          switch (aportes.estado.value) {
            case EstadoCarga.cargando:
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: Center(child: CircularProgressIndicator()),
              );
            case EstadoCarga.error:
              return EstadoEnLinea(
                esError: true,
                icono: Icons.cloud_off_outlined,
                mensaje:
                    aportes.error.value ?? 'No se pudieron cargar los aportes.',
                textoAccion: 'Reintentar',
                onAccion: aportes.cargar,
              );
            case EstadoCarga.vacio:
              return const EstadoEnLinea(
                icono: Icons.forum_outlined,
                mensaje:
                    'Aún no hay aportes. Publica una pregunta, un argumento o '
                    'una propuesta.',
              );
            case EstadoCarga.listo:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in aportes.aportes)
                    _TarjetaAporte(
                      key: ValueKey('aporte-${a.id}'),
                      aporte: a,
                      aportes: aportes,
                      onEditar: () => _abrirFormulario(a),
                    ),
                ],
              );
          }
        }),
      ],
    );
  }
}

class _TarjetaAporte extends StatelessWidget {
  const _TarjetaAporte({
    super.key,
    required this.aporte,
    required this.aportes,
    required this.onEditar,
  });

  final Aporte aporte;
  final AportesController aportes;
  final VoidCallback onEditar;

  Future<void> _confirmarEliminacion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Eliminar este aporte?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final mensaje = await aportes.eliminar(aporte);
    if (mensaje != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  aporte.tipo.etiqueta.toUpperCase(),
                  style: texto.labelSmall?.copyWith(color: AppColors.acento),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    aporte.esPropio
                        ? '${aporte.autorNombre} (tú)'
                        : aporte.autorNombre,
                    style: texto.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(_fecha(aporte.creadoEn), style: texto.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(aporte.texto),
            if (aporte.editado) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Editado', style: texto.bodySmall),
            ],
            // Visibilidad de cortesía: quien autoriza es el servidor (403 si no es el autor).
            if (aporte.esPropio)
              Obx(() {
                if (aportes.eliminando.contains(aporte.id)) {
                  return const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.s),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Eliminando aporte',
                    ),
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onEditar,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmarEliminacion(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar'),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  static String _fecha(DateTime fecha) {
    final f = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
  }
}

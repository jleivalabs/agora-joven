import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/actividad_comunidad.dart';
import '../controllers/admin_solicitudes_controller.dart';
import '../controllers/debates_controller.dart';
import '../models/borrador.dart';
import '../models/debate.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/dialogo_motivo.dart';
import '../widgets/estados.dart';
import 'detalle_debate_screen.dart';

/// Administración: solicitudes de archivo pendientes, por orden de llegada.
class AdminSolicitudesScreen extends StatefulWidget {
  const AdminSolicitudesScreen({super.key});

  @override
  State<AdminSolicitudesScreen> createState() => _AdminSolicitudesScreenState();
}

class _AdminSolicitudesScreenState extends State<AdminSolicitudesScreen> {
  late final AdminSolicitudesController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(
      AdminSolicitudesController(
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
    Get.delete<AdminSolicitudesController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _c.cargar,
          ),
        ],
      ),
      body: Obx(
        () => switch (_c.estado.value) {
          EstadoCarga.cargando || EstadoCarga.vacio => const EstadoCargando(
            mensaje: 'Cargando solicitudes…',
          ),
          EstadoCarga.error => EstadoError(
            mensaje: _c.error.value ?? 'No se pudieron cargar las solicitudes.',
            onReintentar: _c.cargar,
            textoSecundario: 'Volver',
            onSecundario: () => Get.back<void>(),
          ),
          EstadoCarga.listo when _c.pendientes.isEmpty => const EstadoVacio(
            mensaje: 'No hay solicitudes de archivo pendientes.',
          ),
          EstadoCarga.listo => RefreshIndicator(
            onRefresh: _c.cargar,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                Text(
                  'Solicitudes de archivo pendientes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.s),
                for (final s in _c.pendientes)
                  Card(
                    child: ListTile(
                      key: Key('solicitud-${s.id}'),
                      leading: const Icon(Icons.outbox_outlined),
                      title: Text(s.debateTitulo),
                      subtitle: Text(
                        'Solicitada por ${s.solicitanteNombre} el '
                        '${fechaHora(s.creadaEn)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.to<void>(
                        () => AdminSolicitudScreen(solicitudId: s.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

/// Detalle de una solicitud pendiente con las acciones Aprobar y Rechazar.
class AdminSolicitudScreen extends StatelessWidget {
  const AdminSolicitudScreen({super.key, required this.solicitudId});

  final int solicitudId;

  Future<void> _resolver(BuildContext context, {required bool aprobar}) async {
    final c = Get.find<AdminSolicitudesController>();
    final justificacion = await pedirMotivo(
      context,
      titulo: aprobar ? 'Aprobar y archivar' : 'Rechazar solicitud',
      explicacion: aprobar
          ? 'El debate quedará archivado: se conservará con sus aportes para consulta, '
                'pero no admitirá cambios. La persona solicitante verá tu justificación.'
          : 'El debate seguirá activo. La persona solicitante verá tu justificación.',
      etiqueta: 'Justificación',
      accion: aprobar ? 'Aprobar' : 'Rechazar',
    );
    if (justificacion == null) return;
    final resultado = await c.resolver(
      solicitudId,
      aprobar: aprobar,
      justificacion: justificacion,
    );
    if (resultado == null || !context.mounted) return;
    final (resuelta, mensaje) = resultado;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
    if (resuelta) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AdminSolicitudesController>();
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de archivo')),
      body: Obx(() {
        final s = c.buscar(solicitudId);
        if (s == null) {
          return EstadoVacio(
            mensaje: 'Esta solicitud ya no está pendiente.',
            textoAccion: 'Volver',
            onAccion: () => Get.back<void>(),
          );
        }
        final ocupado = c.resolviendo.contains(s.id);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            Text(s.debateTitulo, style: texto.headlineSmall),
            const SizedBox(height: AppSpacing.s),
            Text(
              '${etiquetaCategoria(s.debateCategoria)} · '
              '${plural(s.debateAportes, 'aporte', 'aportes')} · '
              '${s.debateEstado == EstadoDebate.archivado ? 'archivado' : 'activo'}',
              style: texto.labelLarge,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(s.debateResumen),
            const SizedBox(height: AppSpacing.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Get.to<void>(
                  () => DetalleDebateScreen(
                    debateId: s.debateId,
                    titulo: s.debateTitulo,
                    etiquetaCategoria: etiquetaCategoria(s.debateCategoria),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver el debate completo'),
              ),
            ),
            const Divider(height: AppSpacing.l),
            Text('Motivo', style: texto.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(s.motivo, style: texto.bodyLarge),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Solicitada por ${s.solicitanteNombre} el ${fechaHora(s.creadaEn)}',
              style: texto.bodySmall,
            ),
            const SizedBox(height: AppSpacing.l),
            Text(
              'Aprobar archiva el debate; rechazar lo mantiene activo. '
              'En ambos casos la justificación es obligatoria.',
              style: texto.bodySmall,
            ),
            const SizedBox(height: AppSpacing.m),
            if (ocupado)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: [
                  FilledButton.icon(
                    key: const Key('aprobar-solicitud'),
                    onPressed: () => _resolver(context, aprobar: true),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Aprobar'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('rechazar-solicitud'),
                    onPressed: () => _resolver(context, aprobar: false),
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                  ),
                ],
              ),
          ],
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/actividad_comunidad.dart';
import '../controllers/debates_controller.dart';
import '../controllers/mis_debates_controller.dart';
import '../models/borrador.dart';
import '../models/solicitud_archivo.dart';
import '../repositories/solicitudes_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/estados.dart';
import 'crear_debate_screen.dart';
import 'detalle_debate_screen.dart';

/// Debates propios separados en Borradores, Publicados y Archivados.
class MisDebatesScreen extends StatefulWidget {
  const MisDebatesScreen({super.key});

  @override
  State<MisDebatesScreen> createState() => _MisDebatesScreenState();
}

class _MisDebatesScreenState extends State<MisDebatesScreen> {
  late final MisDebatesController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(
      MisDebatesController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.isRegistered<ActividadComunidad>()
            ? Get.find<ActividadComunidad>()
            : null,
        Get.isRegistered<SolicitudesRepository>()
            ? Get.find<SolicitudesRepository>()
            : null,
      ),
    );
  }

  void _avisar(String? mensaje) {
    if (mensaje == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cancelarSolicitud(SolicitudArchivo solicitud) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cancelar la solicitud de archivo?'),
        content: const Text(
          'El debate seguirá activo. Podrás solicitarlo de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    _avisar(await _c.cancelarSolicitud(solicitud.id));
  }

  /// Estado de la última solicitud de archivo de un debate publicado (si aporta información).
  String _lineaSolicitud(SolicitudArchivo? s) => switch (s?.estado) {
    EstadoSolicitud.pendiente => '\nArchivo solicitado: pendiente de revisión',
    EstadoSolicitud.rechazada => '\nSolicitud de archivo rechazada',
    _ => '',
  };

  static String _origen(OrigenArchivo? origen) => switch (origen) {
    OrigenArchivo.solicitud => ' por solicitud aprobada',
    OrigenArchivo.administracion => ' por la administración',
    OrigenArchivo.anterior => ' antes de la revisión de archivos',
    null => '',
  };

  @override
  void dispose() {
    Get.delete<MisDebatesController>();
    super.dispose();
  }

  Future<void> _eliminar(Borrador b) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Eliminar este borrador?'),
        content: const Text(
          'Se borrará definitivamente. No afecta a debates publicados.',
        ),
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
    final mensaje = await _c.eliminarBorrador(b.id);
    _avisar(mensaje);
  }

  void _abrirDebate(MiDebate d) {
    Get.to<void>(
      () => DetalleDebateScreen(
        debateId: d.id,
        titulo: d.titulo,
        etiquetaCategoria: etiquetaCategoria(d.categoria),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final datos = _c.datos.value;
      String pestana(String nombre, int? n) =>
          n == null ? nombre : '$nombre ($n)';
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Mis debates'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppColors.acento,
              tabs: [
                Tab(text: pestana('Borradores', datos?.borradores.length)),
                Tab(text: pestana('Publicados', datos?.publicados.length)),
                Tab(text: pestana('Archivados', datos?.archivados.length)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'crear-desde-mis-debates',
            onPressed: () => Get.to<void>(() => const CrearDebateScreen()),
            icon: const Icon(Icons.add),
            label: const Text('Crear debate'),
          ),
          body: switch (_c.estado.value) {
            EstadoCarga.cargando || EstadoCarga.vacio => const EstadoCargando(
              mensaje: 'Cargando tus debates…',
            ),
            EstadoCarga.error => EstadoError(
              mensaje: _c.error.value ?? 'No se pudieron cargar tus debates.',
              onReintentar: _c.cargar,
              textoSecundario: 'Volver',
              onSecundario: () => Get.back<void>(),
            ),
            EstadoCarga.listo => TabBarView(
              children: [
                _Lista(
                  vacio:
                      'No tienes borradores. Crea un debate y guárdalo para '
                      'retomarlo cuando quieras.',
                  onActualizar: _c.cargar,
                  elementos: [
                    for (final b in datos!.borradores)
                      ListTile(
                        leading: const Icon(Icons.edit_note_outlined),
                        title: Text(
                          (b.titulo?.trim().isNotEmpty ?? false)
                              ? b.titulo!
                              : 'Borrador sin pregunta',
                        ),
                        subtitle: Text(
                          'Paso ${b.paso} de 6 · actualizado el '
                          '${fechaHora(b.actualizadoEn)}',
                        ),
                        trailing: _c.eliminando.contains(b.id)
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                tooltip: 'Eliminar borrador',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _eliminar(b),
                              ),
                        onTap: () => Get.to<void>(
                          () => CrearDebateScreen(borradorId: b.id),
                        ),
                      ),
                  ],
                ),
                _Lista(
                  vacio: 'Todavía no has publicado debates.',
                  onActualizar: _c.cargar,
                  elementos: [
                    for (final d in datos.publicados)
                      ListTile(
                        key: Key('mi-debate-${d.id}'),
                        leading: const Icon(Icons.forum_outlined),
                        title: Text(d.titulo),
                        subtitle: Text(
                          '${etiquetaCategoria(d.categoria)} · '
                          '${plural(d.aportes, 'aporte', 'aportes')}'
                          '${d.editable ? ' · editable' : ' · contenido bloqueado'}'
                          '${_lineaSolicitud(d.solicitudArchivo)}',
                        ),
                        trailing: switch (d.solicitudArchivo) {
                          final s? when s.pendiente =>
                            _c.cancelando.contains(s.id)
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : IconButton(
                                    key: Key('cancelar-solicitud-${s.id}'),
                                    tooltip: 'Cancelar solicitud de archivo',
                                    icon: const Icon(Icons.undo),
                                    onPressed: () => _cancelarSolicitud(s),
                                  ),
                          _ => const Icon(Icons.chevron_right),
                        },
                        onTap: () => _abrirDebate(d),
                      ),
                  ],
                ),
                _Lista(
                  vacio: 'No tienes debates archivados.',
                  onActualizar: _c.cargar,
                  elementos: [
                    for (final d in datos.archivados)
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(d.titulo),
                        subtitle: Text(
                          'Archivado${_origen(d.archivoOrigen)} · '
                          '${plural(d.aportes, 'aporte', 'aportes')}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrirDebate(d),
                      ),
                  ],
                ),
              ],
            ),
          },
        ),
      );
    });
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.vacio,
    required this.elementos,
    required this.onActualizar,
  });

  final String vacio;
  final List<Widget> elementos;
  final Future<void> Function() onActualizar;

  @override
  Widget build(BuildContext context) {
    if (elementos.isEmpty) {
      return EstadoVacio(mensaje: vacio);
    }
    return RefreshIndicator(
      onRefresh: onActualizar,
      child: ListView(
        padding: const EdgeInsets.only(
          bottom: 88,
        ), // espacio para el botón flotante
        children: [for (final e in elementos) Card(child: e)],
      ),
    );
  }
}

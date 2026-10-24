import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/debates_controller.dart';
import '../controllers/guardados_controller.dart';
import '../models/debate_guardado.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import 'detalle_debate_screen.dart';

/// Debates guardados en este dispositivo para la cuenta activa. Se leen localmente, así que la
/// lista está disponible aunque el backend falle; abrir un debate sigue pidiendo su detalle.
class GuardadosScreen extends StatefulWidget {
  const GuardadosScreen({super.key});

  @override
  State<GuardadosScreen> createState() => _GuardadosScreenState();
}

class _GuardadosScreenState extends State<GuardadosScreen> {
  final _guardados = Get.find<GuardadosController>();

  @override
  void initState() {
    super.initState();
    _guardados.cargar();
  }

  Future<void> _quitar(DebateGuardado debate) async {
    final mensaje = await _guardados.quitar(debate.id);
    if (mensaje != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardados')),
      body: Obx(() {
        switch (_guardados.estado.value) {
          case EstadoCarga.cargando:
            return const EstadoCargando(mensaje: 'Cargando guardados…');
          case EstadoCarga.error:
            return EstadoError(
              mensaje:
                  _guardados.error.value ??
                  'No se pudieron leer tus guardados.',
              onReintentar: _guardados.cargar,
              textoSecundario: 'Volver al catálogo',
              onSecundario: () => Get.back<void>(),
            );
          case EstadoCarga.vacio:
            return EstadoVacio(
              mensaje:
                  'Aún no has guardado debates. Abre uno del catálogo y pulsa '
                  'el marcador para guardarlo aquí.',
              textoAccion: 'Ir al catálogo',
              onAccion: () => Get.back<void>(),
            );
          case EstadoCarga.listo:
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.m),
              itemCount: _guardados.guardados.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (_, i) {
                final debate = _guardados.guardados[i];
                return _TarjetaGuardado(
                  debate: debate,
                  pendiente: _guardados.pendientes.contains(debate.id),
                  onQuitar: () => _quitar(debate),
                );
              },
            );
        }
      }),
    );
  }
}

class _TarjetaGuardado extends StatelessWidget {
  const _TarjetaGuardado({
    required this.debate,
    required this.pendiente,
    required this.onQuitar,
  });

  final DebateGuardado debate;
  final bool pendiente;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final f = debate.guardadoEn.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        title: Text(debate.titulo, style: texto.titleMedium),
        subtitle: Text(
          '${debate.etiquetaCategoria} · guardado el '
          '${dos(f.day)}/${dos(f.month)}/${f.year}',
        ),
        trailing: pendiente
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Quitar de guardados',
                icon: const Icon(Icons.bookmark_remove_outlined),
                onPressed: onQuitar,
              ),
        onTap: () => Get.to<void>(
          () => DetalleDebateScreen(
            debateId: debate.id,
            titulo: debate.titulo,
            etiquetaCategoria: debate.etiquetaCategoria,
          ),
        ),
      ),
    );
  }
}

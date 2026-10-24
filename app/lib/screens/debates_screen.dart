import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/debates_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/debate.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import 'detalle_debate_screen.dart';
import 'guardados_screen.dart';

/// Catálogo de debates. Crea su controlador al aparecer y lo elimina al desaparecer
/// (por ejemplo al cerrar sesión), de modo que no quedan datos del usuario anterior.
class DebatesScreen extends StatefulWidget {
  const DebatesScreen({super.key});

  @override
  State<DebatesScreen> createState() => _DebatesScreenState();
}

class _DebatesScreenState extends State<DebatesScreen> {
  late final DebatesController _debates;
  final _sesion = Get.find<SesionController>();

  @override
  void initState() {
    super.initState();
    _debates = Get.put(DebatesController(Get.find(), _sesion));
  }

  @override
  void dispose() {
    Get.delete<DebatesController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debates'),
        actions: [
          IconButton(
            tooltip: 'Guardados',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Get.to<void>(() => const GuardadosScreen()),
          ),
          _MenuCuenta(sesion: _sesion),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Obx(
              () => Text(
                'Hola, ${_sesion.usuario.value?.nombre ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          _FiltroCategorias(debates: _debates),
          const Divider(height: 1),
          Expanded(child: Obx(() => _contenido())),
        ],
      ),
    );
  }

  Widget _contenido() {
    switch (_debates.estado.value) {
      case EstadoCarga.cargando:
        return const EstadoCargando(mensaje: 'Cargando debates…');
      case EstadoCarga.error:
        return EstadoError(
          mensaje: _debates.error.value ?? 'No se pudieron cargar los debates.',
          onReintentar: _debates.cargar,
        );
      case EstadoCarga.vacio:
        return EstadoVacio(
          mensaje: 'Todavía no hay debates en esta categoría.',
          textoAccion: 'Ver todas',
          onAccion: () => _debates.seleccionar(null),
        );
      case EstadoCarga.listo:
        return RefreshIndicator(
          onRefresh: _debates.cargar,
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.m),
            itemCount: _debates.debates.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.m),
            itemBuilder: (_, i) => _TarjetaDebate(
              debate: _debates.debates[i],
              etiqueta: _debates.etiqueta(_debates.debates[i].categoria),
            ),
          ),
        );
    }
  }
}

class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta({required this.sesion});

  final SesionController sesion;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Cuenta y cierre de sesión',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (opcion) {
        if (opcion == 'salir') sesion.cerrarSesion();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(sesion.usuario.value?.nombre ?? ''),
            subtitle: Text(sesion.usuario.value?.email ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'salir',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}

class _FiltroCategorias extends StatelessWidget {
  const _FiltroCategorias({required this.debates});

  final DebatesController debates;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Obx(() {
        final seleccion = debates.seleccion.value;
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          children: [
            _Chip(
              texto: 'Todas',
              seleccionado: seleccion == null,
              onTap: () => debates.seleccionar(null),
            ),
            for (final c in debates.categorias)
              _Chip(
                texto: '${c.etiqueta} (${c.total})',
                seleccionado: seleccion == c.codigo,
                onTap: () => debates.seleccionar(c.codigo),
              ),
          ],
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionado,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _TarjetaDebate extends StatelessWidget {
  const _TarjetaDebate({required this.debate, required this.etiqueta});

  final DebateResumen debate;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to<void>(
          () => DetalleDebateScreen(
            debateId: debate.id,
            titulo: debate.titulo,
            etiquetaCategoria: etiqueta,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta.toUpperCase(),
                style: texto.labelSmall?.copyWith(color: AppColors.acento),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(debate.titulo, style: texto.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                debate.resumen,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: texto.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

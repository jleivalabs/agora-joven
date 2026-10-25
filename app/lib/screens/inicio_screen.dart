import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/debates_controller.dart';
import '../controllers/guardados_controller.dart';
import '../controllers/inicio_controller.dart';
import '../controllers/principal_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/aporte.dart';
import '../models/debate.dart';
import '../models/estadisticas.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/estados.dart';
import '../widgets/menu_cuenta.dart';
import '../widgets/tarjetas_estadistica.dart';
import 'detalle_debate_screen.dart';

/// Dashboard de la sesión: "La comunidad" y "Mi participación".
///
/// Todas las cifras vienen del servidor; los guardados, del repositorio local existente.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inicio = Get.find<InicioController>();
    final sesion = Get.find<SesionController>();
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar cifras',
            icon: const Icon(Icons.refresh),
            onPressed: inicio.cargar,
          ),
          const MenuCuenta(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: inicio.cargar,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            Obx(
              () => Text(
                'Hola, ${sesion.usuario.value?.nombre ?? ''}',
                style: texto.headlineSmall?.copyWith(
                  color: AppColors.primario,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Así va la conversación en Ágora Joven.',
              style: texto.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.l),
            const _TituloSeccion(
              icono: Icons.groups_outlined,
              titulo: 'La comunidad',
            ),
            const SizedBox(height: AppSpacing.s),
            // Los datos se leen dentro del Obx para que una recarga con cifras nuevas repinte.
            Obx(() {
              final datos = inicio.comunidad.value;
              return _SeccionConEstado(
                estado: inicio.estadoComunidad.value,
                error: inicio.errorComunidad.value,
                onReintentar: inicio.cargarComunidad,
                mensajeCarga: 'Cargando cifras de la comunidad…',
                contenido: () => _Comunidad(datos: datos!),
              );
            }),
            const SizedBox(height: AppSpacing.l),
            const _TituloSeccion(
              icono: Icons.person_outline,
              titulo: 'Mi participación',
            ),
            const SizedBox(height: AppSpacing.s),
            Obx(() {
              final datos = inicio.mias.value;
              final comunidad = inicio.comunidad.value;
              return _SeccionConEstado(
                estado: inicio.estadoMias.value,
                error: inicio.errorMias.value,
                onReintentar: inicio.cargarMias,
                mensajeCarga: 'Cargando tu participación…',
                contenido: () => _MiParticipacion(
                  datos: datos!,
                  etiqueta: (c) => comunidad?.etiqueta(c) ?? c,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.m),
            const _AccesoGuardados(),
          ],
        ),
      ),
    );
  }
}

void _abrirDebate(DebateBreve debate, String etiqueta) {
  Get.to<void>(
    () => DetalleDebateScreen(
      debateId: debate.id,
      titulo: debate.titulo,
      etiquetaCategoria: etiqueta,
    ),
  );
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.icono, required this.titulo});

  final IconData icono;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icono, color: AppColors.acento),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

/// Carga, error con reintento o contenido. Un error nunca se muestra como cero.
class _SeccionConEstado extends StatelessWidget {
  const _SeccionConEstado({
    required this.estado,
    required this.error,
    required this.onReintentar,
    required this.mensajeCarga,
    required this.contenido,
  });

  final EstadoCarga estado;
  final String? error;
  final VoidCallback onReintentar;
  final String mensajeCarga;
  final Widget Function() contenido;

  @override
  Widget build(BuildContext context) {
    switch (estado) {
      case EstadoCarga.cargando:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.s),
              Text(mensajeCarga),
            ],
          ),
        );
      case EstadoCarga.error:
        return Card(
          child: EstadoEnLinea(
            esError: true,
            icono: Icons.cloud_off_outlined,
            mensaje: error ?? 'No se pudieron cargar estas cifras.',
            textoAccion: 'Reintentar',
            onAccion: onReintentar,
          ),
        );
      case EstadoCarga.vacio:
      case EstadoCarga.listo:
        return contenido();
    }
  }
}

class _Comunidad extends StatelessWidget {
  const _Comunidad({required this.datos});

  final EstadisticasComunidad datos;

  @override
  Widget build(BuildContext context) {
    final principal = Get.find<PrincipalController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RejillaEstadisticas(
          children: [
            TarjetaEstadistica(
              valor: datos.totalDebates,
              titulo: 'Debates publicados',
              explicacion: 'En el catálogo actual',
              icono: Icons.forum_outlined,
              onTap: () => principal.irADebates(),
            ),
            TarjetaEstadistica(
              valor: datos.totalAportes,
              titulo: 'Aportes',
              explicacion: 'Preguntas, argumentos y propuestas',
              icono: Icons.chat_bubble_outline,
            ),
            TarjetaEstadistica(
              valor: datos.participantes,
              titulo: 'Participantes',
              explicacion: 'Cuentas con al menos un aporte',
              icono: Icons.people_outline,
            ),
            TarjetaEstadistica(
              valor: datos.totalSinAportes,
              titulo: 'Debates sin aportes',
              explicacion: 'Esperan una primera voz',
              icono: Icons.campaign_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        _PorCategoria(categorias: datos.categoriasPorCantidad),
        const SizedBox(height: AppSpacing.m),
        _ListaDebates(
          titulo: 'Actividad reciente',
          explicacion: 'Debates ordenados por su aporte más reciente.',
          vacio: 'Todavía no hay aportes en ningún debate.',
          elementos: [
            for (final a in datos.actividadReciente)
              _ElementoDebate(
                debate: a.debate,
                etiqueta: datos.etiqueta(a.debate.categoria),
                detalle:
                    '${plural(a.aportes, 'aporte', 'aportes')} · último el '
                    '${fechaHora(a.ultimoAporteEn)}',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        _ListaDebates(
          titulo: 'Esperan tu primer aporte',
          explicacion: datos.totalSinAportes > datos.sinAportes.length
              ? 'Primeros ${datos.sinAportes.length} de '
                    '${datos.totalSinAportes} debates sin aportes.'
              : 'Debates que todavía no tienen aportes.',
          vacio: 'Todos los debates tienen al menos un aporte.',
          elementos: [
            for (final d in datos.sinAportes)
              _ElementoDebate(
                debate: d,
                etiqueta: datos.etiqueta(d.categoria),
                detalle: 'Sé la primera persona en aportar',
              ),
          ],
        ),
      ],
    );
  }
}

/// Distribución por categoría, de más a menos debates (empates por nombre): texto con la cifra
/// y una barra proporcional. Cada fila abre el catálogo filtrado.
class _PorCategoria extends StatelessWidget {
  const _PorCategoria({required this.categorias});

  final List<Categoria> categorias;

  @override
  Widget build(BuildContext context) {
    final principal = Get.find<PrincipalController>();
    final texto = Theme.of(context).textTheme;
    final maximo = categorias.fold<int>(0, (m, c) => c.total > m ? c.total : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Text('Debates por categoría', style: texto.titleMedium),
            ),
            for (final c in categorias)
              InkWell(
                onTap: () => principal.irADebates(categoria: c.codigo),
                child: Semantics(
                  label:
                      '${c.etiqueta}: ${plural(c.total, 'debate', 'debates')}. '
                      'Abrir el catálogo filtrado.',
                  button: true,
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(c.etiqueta)),
                            Text(
                              '${c.total}',
                              style: texto.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maximo == 0 ? 0 : c.total / maximo,
                            minHeight: 8,
                            color: AppColors.primario,
                            backgroundColor: AppColors.primario.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ElementoDebate {
  const _ElementoDebate({
    required this.debate,
    required this.etiqueta,
    required this.detalle,
  });

  final DebateBreve debate;
  final String etiqueta;
  final String detalle;
}

class _ListaDebates extends StatelessWidget {
  const _ListaDebates({
    required this.titulo,
    required this.explicacion,
    required this.vacio,
    required this.elementos,
  });

  final String titulo;
  final String explicacion;
  final String vacio;
  final List<_ElementoDebate> elementos;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: texto.titleMedium),
                  Text(explicacion, style: texto.bodySmall),
                ],
              ),
            ),
            if (elementos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Text(vacio),
              ),
            for (final e in elementos)
              ListTile(
                title: Text(e.debate.titulo),
                subtitle: Text('${e.etiqueta} · ${e.detalle}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrirDebate(e.debate, e.etiqueta),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiParticipacion extends StatelessWidget {
  const _MiParticipacion({required this.datos, required this.etiqueta});

  final EstadisticasPersonales datos;
  final String Function(String codigo) etiqueta;

  @override
  Widget build(BuildContext context) {
    final principal = Get.find<PrincipalController>();
    final texto = Theme.of(context).textTheme;
    if (datos.totalAportes == 0) {
      return Card(
        child: EstadoEnLinea(
          icono: Icons.record_voice_over_outlined,
          mensaje:
              'Todavía no has publicado aportes. Elige un debate y comparte una '
              'pregunta, un argumento o una propuesta.',
          textoAccion: 'Explorar debates',
          onAccion: () => principal.irADebates(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RejillaEstadisticas(
          children: [
            TarjetaEstadistica(
              valor: datos.totalAportes,
              titulo: 'Mis aportes',
              explicacion: 'Preguntas, argumentos y propuestas',
              icono: Icons.edit_note_outlined,
            ),
            TarjetaEstadistica(
              valor: datos.debatesParticipados,
              titulo: 'Debates en los que participé',
              explicacion: 'Con al menos un aporte tuyo',
              icono: Icons.forum_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final t in TipoAporte.values)
              Chip(
                avatar: Icon(_iconoTipo(t), size: 18),
                label: Text('${_pluralTipo(t)}: ${datos.porTipo[t] ?? 0}'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: Text(
                    'Mis aportes recientes',
                    style: texto.titleMedium,
                  ),
                ),
                for (final a in datos.aportesRecientes)
                  ListTile(
                    leading: Icon(_iconoTipo(a.tipo)),
                    title: Text(
                      a.texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${a.tipo.etiqueta} · ${a.debate.titulo} · '
                      '${fechaHora(a.creadoEn)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _abrirDebate(a.debate, etiqueta(a.debate.categoria)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconoTipo(TipoAporte tipo) => switch (tipo) {
    TipoAporte.pregunta => Icons.help_outline,
    TipoAporte.argumento => Icons.balance_outlined,
    TipoAporte.propuesta => Icons.lightbulb_outline,
  };

  static String _pluralTipo(TipoAporte tipo) => switch (tipo) {
    TipoAporte.pregunta => 'Preguntas',
    TipoAporte.argumento => 'Argumentos',
    TipoAporte.propuesta => 'Propuestas',
  };
}

/// Acceso a los guardados del dispositivo (repositorio local existente).
class _AccesoGuardados extends StatelessWidget {
  const _AccesoGuardados();

  @override
  Widget build(BuildContext context) {
    final guardados = Get.find<GuardadosController>();
    final principal = Get.find<PrincipalController>();
    return Obx(() {
      final subtitulo = switch (guardados.estado.value) {
        EstadoCarga.cargando => 'Cargando…',
        EstadoCarga.error => 'No se pudieron leer tus guardados.',
        EstadoCarga.vacio => 'Aún no has guardado debates.',
        EstadoCarga.listo =>
          '${plural(guardados.guardados.length, 'debate guardado', 'debates guardados')} en este dispositivo',
      };
      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.bookmarks_outlined,
            color: AppColors.acento,
          ),
          title: const Text('Mis guardados'),
          subtitle: Text(subtitulo),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => principal.ir(SeccionPrincipal.guardados),
        ),
      );
    });
  }
}

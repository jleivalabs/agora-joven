import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/debates_controller.dart';
import '../controllers/historial_controller.dart';
import '../models/borrador.dart';
import '../models/version_debate.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/estados.dart';
import '../widgets/marca.dart';
import '../widgets/tarjeta_referencia.dart';

/// Versiones publicadas de un debate, de la más reciente a la primera. Nunca muestra borradores.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, required this.debateId});

  final int debateId;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late final String _etiqueta = 'historial-${widget.debateId}';
  late final HistorialController _c = Get.put(
    HistorialController(Get.find(), Get.find(), widget.debateId),
    tag: _etiqueta,
  );

  @override
  void dispose() {
    Get.delete<HistorialController>(tag: _etiqueta);
    super.dispose();
  }

  String _subtitulo(VersionResumen v) {
    final partes = [
      etiquetaTipoVersion(v.tipo),
      fechaHora(v.creadaEn),
      if (v.autorNombre != null) 'por ${v.autorNombre}',
    ];
    final cambios = v.camposCambiados.isEmpty
        ? ''
        : '\nCambió: ${v.camposCambiados.map(etiquetaCampo).join(', ')}';
    final motivo = v.motivo == null ? '' : '\nMotivo: ${v.motivo}';
    return '${partes.join(' · ')}$cambios$motivo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial del debate')),
      body: Obx(
        () => switch (_c.estado.value) {
          EstadoCarga.cargando => const EstadoCargando(
            mensaje: 'Cargando historial…',
          ),
          EstadoCarga.error => EstadoError(
            mensaje: _c.error.value ?? 'No se pudo cargar el historial.',
            onReintentar: _c.cargar,
            textoSecundario: 'Volver',
            onSecundario: () => Get.back<void>(),
          ),
          EstadoCarga.vacio => const EstadoVacio(
            mensaje: 'Este debate todavía no tiene versiones registradas.',
          ),
          EstadoCarga.listo => RefreshIndicator(
            onRefresh: _c.cargar,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                const Aviso(
                  texto:
                      'Cada versión conserva el contenido publicado en ese momento. Las '
                      'versiones no se modifican ni se borran.',
                ),
                const SizedBox(height: AppSpacing.s),
                for (final v in _c.versiones)
                  Card(
                    child: ListTile(
                      key: Key('version-${v.numero}'),
                      leading: Icon(
                        v.esActual ? Icons.check_circle_outline : Icons.history,
                        color: AppColors.primario,
                      ),
                      title: Text(
                        'Versión ${v.numero}${v.esActual ? ' (vigente)' : ''}',
                      ),
                      subtitle: Text(_subtitulo(v)),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Get.to<void>(
                        () => VersionScreen(
                          debateId: widget.debateId,
                          numero: v.numero,
                        ),
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

/// Contenido de una versión y sus diferencias por campo respecto a la anterior.
///
/// [referenciaDeAporteAntiguo]: se abrió desde un aporte anterior al historial; la versión que
/// vio su autor es desconocida y esta instantánea es solo una referencia.
class VersionScreen extends StatefulWidget {
  const VersionScreen({
    super.key,
    required this.debateId,
    required this.numero,
    this.referenciaDeAporteAntiguo = false,
  });

  final int debateId;
  final int numero;
  final bool referenciaDeAporteAntiguo;

  @override
  State<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends State<VersionScreen> {
  late final String _etiqueta = 'version-${widget.debateId}-${widget.numero}';
  late final VersionController _c = Get.put(
    VersionController(Get.find(), Get.find(), widget.debateId, widget.numero),
    tag: _etiqueta,
  );

  @override
  void dispose() {
    Get.delete<VersionController>(tag: _etiqueta);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Versión ${widget.numero}')),
      body: Obx(() {
        switch (_c.estado.value) {
          case EstadoCarga.cargando:
          case EstadoCarga.vacio:
            return const EstadoCargando(mensaje: 'Cargando versión…');
          case EstadoCarga.error:
            return EstadoError(
              mensaje: _c.error.value ?? 'No se pudo cargar la versión.',
              onReintentar: _c.cargar,
              textoSecundario: 'Volver',
              onSecundario: () => Get.back<void>(),
            );
          case EstadoCarga.listo:
            final v = _c.version.value!;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                if (widget.referenciaDeAporteAntiguo) ...[
                  const Aviso(
                    key: Key('aviso-version-desconocida'),
                    texto:
                        'Este aporte es anterior al historial: no se sabe qué versión vio '
                        'su autor. Esta instantánea es solo una referencia.',
                  ),
                  const SizedBox(height: AppSpacing.s),
                ],
                Aviso(
                  key: Key(
                    v.esActual
                        ? 'aviso-version-vigente'
                        : 'aviso-version-historica',
                  ),
                  texto: v.esActual
                      ? 'Versión ${v.numero}: es el contenido vigente del debate.'
                      : 'Versión histórica ${v.numero}, del ${fechaHora(v.creadaEn)}. '
                            'No es el contenido vigente del debate.',
                ),
                if (v.tipo == TipoVersion.registroInicial) ...[
                  const SizedBox(height: AppSpacing.s),
                  const Aviso(
                    texto:
                        'Estado registrado al incorporar el historial. No se conservaron '
                        'versiones anteriores, ni quién ni cuándo cambió el contenido antes.',
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                Text(
                  [
                    etiquetaTipoVersion(v.tipo),
                    fechaHora(v.creadaEn),
                    if (v.autorNombre != null) 'por ${v.autorNombre}',
                  ].join(' · '),
                  style: texto.labelLarge,
                ),
                if (v.motivo != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('Motivo: ${v.motivo}'),
                ],
                if (v.cambios.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    'Cambios respecto a la versión ${v.numero - 1}',
                    style: texto.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  for (final c in v.cambios) _Cambio(cambio: c),
                ],
                const SizedBox(height: AppSpacing.l),
                Text('Contenido de esta versión', style: texto.titleLarge),
                const SizedBox(height: AppSpacing.s),
                Text(
                  '${etiquetaCategoria(v.categoria)}'
                  '${v.ambito == null ? '' : ' · ${v.ambito}'}',
                  style: texto.labelLarge,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(v.titulo, style: texto.headlineSmall),
                const SizedBox(height: AppSpacing.s),
                Text(v.resumen, style: texto.titleMedium),
                const SizedBox(height: AppSpacing.m),
                Text('Contexto', style: texto.titleMedium),
                Text(v.contexto, style: texto.bodyLarge),
                const SizedBox(height: AppSpacing.m),
                Text('Perspectivas', style: texto.titleMedium),
                for (final p in v.perspectivas)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('• ${p.titulo}: ${p.descripcion}'),
                  ),
                if (v.objetivo != null) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text('Objetivo', style: texto.titleMedium),
                  Text(v.objetivo!, style: texto.bodyLarge),
                ],
                if (v.referencias.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  Text('Fuentes de esta versión', style: texto.titleMedium),
                  Text(avisoReferencias, style: texto.bodySmall),
                  for (final r in v.referencias)
                    TarjetaReferencia(
                      referencia: r,
                      otrasEnLista: {for (final x in v.referencias) x.doi},
                    ),
                ],
              ],
            );
        }
      }),
    );
  }
}

/// Un campo cambiado: antes y después, con texto (no solo color) para indicar cada uno.
class _Cambio extends StatelessWidget {
  const _Cambio({required this.cambio});

  final CambioCampo cambio;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiquetaCampo(cambio.campo), style: texto.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Text('Antes', style: texto.labelLarge),
            Text(cambio.antes),
            const SizedBox(height: AppSpacing.s),
            Text('Después', style: texto.labelLarge),
            Text(cambio.despues),
          ],
        ),
      ),
    );
  }
}

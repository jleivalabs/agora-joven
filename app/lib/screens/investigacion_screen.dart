import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/crear_debate_controller.dart';
import '../controllers/debates_controller.dart';
import '../controllers/investigacion_controller.dart';
import '../models/referencia.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import '../widgets/marca.dart';
import '../widgets/tarjeta_referencia.dart';

/// Fuentes e IA para el borrador abierto (7C). Todo es opcional y nada se aplica sin confirmar.
class InvestigacionScreen extends StatefulWidget {
  const InvestigacionScreen({super.key, required this.crear});

  final CrearDebateController crear;

  @override
  State<InvestigacionScreen> createState() => _InvestigacionScreenState();
}

class _InvestigacionScreenState extends State<InvestigacionScreen> {
  late final InvestigacionController _c = Get.put(
    InvestigacionController(Get.find(), Get.find(), Get.find(), widget.crear),
  );
  Worker? _mensajes;

  @override
  void initState() {
    super.initState();
    _mensajes = ever<String?>(_c.mensaje, (m) {
      if (m == null || !mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));
    });
  }

  @override
  void dispose() {
    _mensajes?.dispose();
    Get.delete<InvestigacionController>();
    super.dispose();
  }

  Future<bool> _confirmarEnvio({
    required String titulo,
    required String destino,
    required String enviado,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        scrollable: true,
        content: Text(
          'Se enviará a $destino:\n\n$enviado\n\nNo se envían tu nombre, tu correo ni '
          'aportes de otras personas. El resultado no se aplica a tu borrador sin tu '
          'confirmación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-envio'),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Consultar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _buscar() async {
    if (await _confirmarEnvio(
      titulo: 'Buscar referencias',
      destino: 'Crossref (servicio externo de metadatos bibliográficos)',
      enviado: '"${_c.textoBusqueda}"',
    )) {
      await _c.buscar();
    }
  }

  Future<void> _redactar() async {
    if (await _confirmarEnvio(
      titulo: 'Redactar con IA',
      destino: 'Gemini (Google), sin búsqueda en internet',
      enviado:
          'categoría, ámbito, pregunta, resumen, contexto, perspectivas y objetivo de '
          'tu borrador, y el título, la fecha y el tipo de las referencias que '
          'seleccionaste (no sus resúmenes)',
    )) {
      await _c.redactar();
    }
  }

  Future<void> _aceptar(SugerenciaIA s) async {
    final resultado = await showDialog<_Aceptacion>(
      context: context,
      builder: (_) => _DialogoAceptar(
        sugerencia: s,
        contextoActual: widget.crear.contexto.value,
      ),
    );
    if (resultado == null) return;
    await _c.aceptar(
      s,
      modo: resultado.modo,
      valorVisto: resultado.valorVisto,
      texto: resultado.texto,
      titulo: resultado.titulo,
      descripcion: resultado.descripcion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuentes e IA')),
      body: Obx(() {
        switch (_c.carga.value) {
          case EstadoCarga.cargando:
          case EstadoCarga.vacio:
            return const EstadoCargando(mensaje: 'Preparando…');
          case EstadoCarga.error:
            return EstadoError(
              mensaje:
                  _c.errorCarga.value ??
                  'No se pudo preparar la investigación.',
              onReintentar: _c.cargar,
              textoSecundario: 'Volver',
              onSecundario: () => Get.back<void>(),
            );
          case EstadoCarga.listo:
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                const Aviso(
                  texto:
                      'Todo es opcional: tu borrador funciona sin esto. Nada se aplica sin tu '
                      'confirmación y nada se publica desde aquí.',
                ),
                const SizedBox(height: AppSpacing.l),
                _SeccionReferencias(c: _c, onBuscar: _buscar),
                const SizedBox(height: AppSpacing.l),
                _SeccionRedaccion(
                  c: _c,
                  onRedactar: _redactar,
                  onAceptar: _aceptar,
                ),
              ],
            );
        }
      }),
    );
  }
}

class _SeccionReferencias extends StatelessWidget {
  const _SeccionReferencias({required this.c, required this.onBuscar});

  final InvestigacionController c;
  final VoidCallback onBuscar;

  // Obx propio: un Obx exterior no sigue lo que se lee al construir este widget.
  @override
  Widget build(BuildContext context) => Obx(() => _construir(context));

  Widget _construir(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final servicio = c.estadoServicio.value;
    final maximo = servicio?.maxReferencias ?? 8;
    final seleccionadas = {for (final r in c.referencias) r.doi};
    final ocupado = c.ocupado.value;
    final busqueda = c.busqueda.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Referencias bibliográficas', style: texto.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        const Text(avisoReferencias),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Los resúmenes de las obras no se procesan ni se publican hasta aprobar una política '
          'de licencias.',
          style: texto.bodySmall,
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          'En tu borrador (${c.referencias.length} de $maximo)',
          style: texto.titleMedium,
        ),
        if (c.referencias.isEmpty)
          const Text('Todavía no seleccionaste referencias.')
        else
          for (final r in c.referencias)
            TarjetaReferencia(
              referencia: r,
              otrasEnLista: seleccionadas,
              acciones: [
                TextButton.icon(
                  key: Key('quitar-${r.doi}'),
                  onPressed: ocupado != null ? null : () => c.quitar(r),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Quitar'),
                ),
              ],
            ),
        const SizedBox(height: AppSpacing.m),
        if (servicio != null && !servicio.busquedaDisponible)
          const Aviso(
            texto: 'La búsqueda de referencias no está configurada en este servidor.',
          )
        else
          FilledButton.icon(
            key: const Key('buscar-referencias'),
            onPressed: ocupado != null ? null : onBuscar,
            icon: ocupado == 'buscar'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Buscando',
                    ),
                  )
                : const Icon(Icons.search),
            label: const Text('Buscar referencias'),
          ),
        if (c.errorBusqueda.value != null) ...[
          const SizedBox(height: AppSpacing.s),
          Aviso(texto: c.errorBusqueda.value!, esError: true),
          TextButton(
            onPressed: ocupado != null ? null : onBuscar,
            child: const Text('Reintentar'),
          ),
        ],
        if (busqueda != null) ...[
          const SizedBox(height: AppSpacing.m),
          Text(
            'Resultados para "${busqueda.consulta}"',
            style: texto.titleMedium,
          ),
          if (busqueda.referencias.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Text(
                'Sin resultados en Crossref. Prueba a precisar la pregunta o el ámbito.',
                key: Key('sin-resultados'),
              ),
            ),
          for (final r in busqueda.referencias)
            TarjetaReferencia(
              referencia: r,
              otrasEnLista: {for (final x in busqueda.referencias) x.doi},
              acciones: [
                if (seleccionadas.contains(r.doi))
                  const Chip(label: Text('En tu borrador'))
                else
                  TextButton.icon(
                    key: Key('anadir-${r.doi}'),
                    onPressed: ocupado != null || c.referencias.length >= maximo
                        ? null
                        : () => c.agregar(r),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir al borrador'),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _SeccionRedaccion extends StatelessWidget {
  const _SeccionRedaccion({
    required this.c,
    required this.onRedactar,
    required this.onAceptar,
  });

  final InvestigacionController c;
  final VoidCallback onRedactar;
  final ValueChanged<SugerenciaIA> onAceptar;

  // Obx propio: un Obx exterior no sigue lo que se lee al construir este widget.
  @override
  Widget build(BuildContext context) => Obx(() => _construir(context));

  Widget _construir(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final disponible = c.estadoServicio.value?.redaccionDisponible ?? false;
    final ocupado = c.ocupado.value;
    final redaccion = c.redaccion.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Redactar con IA', style: texto.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Sugerencias de contexto, perspectivas y preguntas a partir de tu borrador. La IA no '
          'consulta internet ni lee las obras: no puede confirmar datos.',
        ),
        const SizedBox(height: AppSpacing.m),
        if (!disponible)
          const Aviso(
            key: Key('redaccion-desactivada'),
            texto: 'La redacción con IA está desactivada en este servidor.',
          )
        else
          OutlinedButton.icon(
            key: const Key('redactar'),
            onPressed: ocupado != null ? null : onRedactar,
            icon: ocupado == 'redactar'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Redactando',
                    ),
                  )
                : const Icon(Icons.edit_note),
            label: const Text('Pedir sugerencias'),
          ),
        if (c.errorRedaccion.value != null) ...[
          const SizedBox(height: AppSpacing.s),
          Aviso(texto: c.errorRedaccion.value!, esError: true),
          TextButton(
            onPressed: ocupado != null ? null : onRedactar,
            child: const Text('Reintentar'),
          ),
        ],
        if (redaccion != null) ...[
          const SizedBox(height: AppSpacing.m),
          if (c.redaccionDesactualizada)
            const Aviso(
              key: Key('redaccion-desactualizada'),
              texto:
                  'Basado en el texto anterior de tu borrador: lo cambiaste después de pedir '
                  'las sugerencias. Revísalas antes de aplicar alguna.',
            ),
          for (final s in redaccion.pendientes)
            _TarjetaSugerencia(
              sugerencia: s,
              ocupado: ocupado != null,
              onAceptar: () => onAceptar(s),
              onDescartar: () => c.descartar(s),
            ),
          if (redaccion.pendientes.isEmpty)
            const Text('No quedan sugerencias pendientes.'),
          if (redaccion.limitaciones.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text('Limitaciones', style: texto.titleMedium),
            for (final l in redaccion.limitaciones) Text('• $l'),
          ],
        ],
        if (c.evidencias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          Text('Sugerencias que aceptaste', style: texto.titleMedium),
          for (final e in c.evidencias)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(e.textoAceptado),
              subtitle: Text(
                [
                  'Procedencia: sugerencia de IA',
                  if (e.campo == 'preguntas') 'nota privada del borrador',
                  if (e.editada) 'editada por ti',
                  if (e.requiereRevision) 'relación con la fuente por revisar',
                ].join(' · '),
              ),
            ),
        ],
      ],
    );
  }
}

class _TarjetaSugerencia extends StatelessWidget {
  const _TarjetaSugerencia({
    required this.sugerencia,
    required this.ocupado,
    required this.onAceptar,
    required this.onDescartar,
  });

  final SugerenciaIA sugerencia;
  final bool ocupado;
  final VoidCallback onAceptar;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final s = sugerencia;
    final texto = Theme.of(context).textTheme;
    final etiqueta = switch (s.tipo) {
      TipoSugerencia.contexto => 'Contexto',
      TipoSugerencia.perspectiva => 'Perspectiva',
      TipoSugerencia.pregunta => 'Pregunta pendiente',
      TipoSugerencia.afirmacion => 'Afirmación',
    };
    return Card(
      key: Key('sugerencia-${s.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta.toUpperCase(), style: texto.labelSmall),
            Text(s.aviso, style: texto.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            if (s.titulo != null) Text(s.titulo!, style: texto.titleMedium),
            Text(s.texto ?? s.descripcion ?? ''),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                TextButton(
                  key: Key('aceptar-${s.id}'),
                  onPressed: ocupado ? null : onAceptar,
                  child: const Text('Revisar y aceptar'),
                ),
                TextButton(
                  key: Key('descartar-${s.id}'),
                  onPressed: ocupado ? null : onDescartar,
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Aceptacion {
  const _Aceptacion({
    required this.modo,
    required this.valorVisto,
    this.texto,
    this.titulo,
    this.descripcion,
  });

  final String modo;
  final String valorVisto;
  final String? texto;
  final String? titulo;
  final String? descripcion;
}

/// Edición opcional y confirmación. Para el contexto muestra cómo quedará el campo antes de
/// aplicarlo (añadir al final o sustituir).
class _DialogoAceptar extends StatefulWidget {
  const _DialogoAceptar({
    required this.sugerencia,
    required this.contextoActual,
  });

  final SugerenciaIA sugerencia;
  final String contextoActual;

  @override
  State<_DialogoAceptar> createState() => _DialogoAceptarState();
}

// setState solo para el formulario local del diálogo.
class _DialogoAceptarState extends State<_DialogoAceptar> {
  late final _texto = TextEditingController(
    text: widget.sugerencia.texto ?? widget.sugerencia.descripcion ?? '',
  );
  late final _titulo = TextEditingController(
    text: widget.sugerencia.titulo ?? '',
  );
  String _modo = 'anadir';

  bool get _esPerspectiva =>
      widget.sugerencia.tipo == TipoSugerencia.perspectiva;
  bool get _cambiaContexto =>
      widget.sugerencia.tipo == TipoSugerencia.contexto ||
      widget.sugerencia.tipo == TipoSugerencia.afirmacion;

  @override
  void dispose() {
    _texto.dispose();
    _titulo.dispose();
    super.dispose();
  }

  String get _resultado {
    final nuevo = _texto.text.trim();
    final actual = widget.contextoActual;
    return _modo == 'sustituir' || actual.isEmpty ? nuevo : '$actual\n\n$nuevo';
  }

  void _confirmar() {
    final original = widget.sugerencia;
    final textoEditado = _texto.text.trim();
    Navigator.of(context).pop(
      _Aceptacion(
        modo: _modo,
        valorVisto: widget.contextoActual,
        texto: _esPerspectiva || textoEditado == original.texto
            ? null
            : textoEditado,
        titulo: _esPerspectiva ? _titulo.text.trim() : null,
        descripcion: _esPerspectiva ? textoEditado : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Revisar sugerencia'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.sugerencia.aviso, style: texto.bodySmall),
          const SizedBox(height: AppSpacing.s),
          if (_esPerspectiva) ...[
            TextField(
              key: const Key('sugerencia-titulo'),
              controller: _titulo,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
          ],
          TextField(
            key: const Key('sugerencia-texto'),
            controller: _texto,
            minLines: 2,
            maxLines: 8,
            maxLength: _esPerspectiva ? 600 : 1500,
            decoration: InputDecoration(
              labelText: _esPerspectiva
                  ? 'Descripción'
                  : 'Texto (puedes editarlo)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_cambiaContexto) ...[
            RadioGroup<String>(
              groupValue: _modo,
              onChanged: (v) => setState(() => _modo = v ?? 'anadir'),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    key: Key('modo-anadir'),
                    value: 'anadir',
                    title: Text('Añadir al final del contexto'),
                  ),
                  RadioListTile<String>(
                    key: Key('modo-sustituir'),
                    value: 'sustituir',
                    title: Text('Sustituir el contexto actual'),
                  ),
                ],
              ),
            ),
            Text('Así quedará el contexto:', style: texto.labelLarge),
            Container(
              key: const Key('vista-previa'),
              padding: const EdgeInsets.all(AppSpacing.s),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(_resultado),
            ),
            if (_modo == 'sustituir' && widget.contextoActual.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Se reemplazará el texto que escribiste.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
          if (widget.sugerencia.tipo == TipoSugerencia.pregunta)
            Text(
              'Se guardará como nota privada del borrador; no se publica.',
              style: texto.bodySmall,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-sugerencia'),
          onPressed: _texto.text.trim().isEmpty ? null : _confirmar,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

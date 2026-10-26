import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/actividad_comunidad.dart';
import '../controllers/crear_debate_controller.dart';
import '../controllers/debates_controller.dart';
import '../controllers/sesion_controller.dart';
import '../models/borrador.dart';
import '../models/debate.dart';
import '../theme/app_theme.dart';
import '../widgets/estados.dart';
import '../widgets/marca.dart';
import 'detalle_debate_screen.dart';

/// Asistente guiado para crear un debate (nuevo o desde un borrador) o editar uno propio.
class CrearDebateScreen extends StatefulWidget {
  const CrearDebateScreen({super.key, this.borradorId, this.debateEditado});

  final int? borradorId;
  final DebateDetalle? debateEditado;

  @override
  State<CrearDebateScreen> createState() => _CrearDebateScreenState();
}

class _CrearDebateScreenState extends State<CrearDebateScreen> {
  static var _contador = 0;
  final _etiqueta = 'crear-${_contador++}';
  late final CrearDebateController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(
      CrearDebateController(
        Get.find(),
        Get.find(),
        Get.find(),
        borradorInicial: widget.borradorId,
        debateEditado: widget.debateEditado,
        actividad: Get.isRegistered<ActividadComunidad>()
            ? Get.find<ActividadComunidad>()
            : null,
      ),
      tag: _etiqueta,
    );
  }

  @override
  void dispose() {
    Get.delete<CrearDebateController>(tag: _etiqueta);
    super.dispose();
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardarYSalir() async {
    if (await _c.guardar() && mounted) {
      _avisar('Borrador guardado. Puedes retomarlo en Mis debates.');
      Navigator.of(context).pop();
    }
  }

  /// Al salir con cambios sin guardar se pregunta; nunca se descartan en silencio.
  Future<void> _alSalir() async {
    if (!_c.haySinGuardar) {
      Navigator.of(context).pop();
      return;
    }
    final eleccion = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Tienes cambios sin guardar'),
        content: Text(
          _c.modoEdicion
              ? 'Si sales ahora, los cambios en el debate se perderán.'
              : 'Puedes guardarlos en el borrador o descartarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop('seguir'),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop('descartar'),
            child: const Text('Descartar'),
          ),
          if (!_c.modoEdicion)
            FilledButton(
              onPressed: () => Navigator.of(contexto).pop('guardar'),
              child: const Text('Guardar y salir'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (eleccion) {
      case 'descartar':
        Navigator.of(context).pop();
      case 'guardar':
        await _guardarYSalir();
    }
  }

  Future<void> _publicar() async {
    if (_c.modoEdicion) {
      final editado = await _c.guardarEdicion();
      if (editado != null && mounted) {
        _avisar('Cambios guardados.');
        Navigator.of(context).pop(editado);
      }
      return;
    }
    final debate = await _c.publicar();
    if (debate != null && mounted) {
      _avisar('Debate publicado.');
      Get.off<void>(
        () => DetalleDebateScreen(
          debateId: debate.id,
          titulo: debate.titulo,
          etiquetaCategoria: etiquetaCategoria(debate.categoria),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _alSalir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_c.modoEdicion ? 'Editar debate' : 'Crear debate'),
          leading: IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.close),
            onPressed: _alSalir,
          ),
          actions: [
            if (!_c.modoEdicion)
              // Icono con descripción: un botón de texto no cabe en móviles estrechos
              // con texto ampliado.
              Obx(
                () => IconButton(
                  key: const Key('guardar-y-salir'),
                  tooltip: 'Guardar y salir',
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _c.guardando.value ? null : _guardarYSalir,
                ),
              ),
          ],
        ),
        body: Obx(() {
          switch (_c.estado.value) {
            case EstadoCarga.cargando:
            case EstadoCarga.vacio:
              return const EstadoCargando(mensaje: 'Recuperando tu borrador…');
            case EstadoCarga.error:
              return EstadoError(
                mensaje: _c.errorCarga.value ?? 'No se pudo abrir el borrador.',
                onReintentar: _c.cargar,
                textoSecundario: 'Volver',
                onSecundario: () => Navigator.of(context).pop(),
              );
            case EstadoCarga.listo:
              return _Asistente(c: _c, onPublicar: _publicar);
          }
        }),
      ),
    );
  }
}

class _Asistente extends StatelessWidget {
  const _Asistente({required this.c, required this.onPublicar});

  final CrearDebateController c;
  final VoidCallback onPublicar;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final paso = c.paso.value;
      final total = PasoCreacion.values.length;
      final ocupado = c.guardando.value || c.publicando.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Semantics(
              label: 'Paso ${paso.numero} de $total: ${paso.titulo}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paso ${paso.numero} de $total · ${paso.titulo}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(value: paso.numero / total),
                ],
              ),
            ),
          ),
          if (c.errorGuardado.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Aviso(texto: c.errorGuardado.value!, esError: true),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: ocupado ? null : c.guardar,
                      child: const Text('Reintentar guardado'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey(paso),
              padding: const EdgeInsets.all(AppSpacing.m),
              child: switch (paso) {
                PasoCreacion.tema => _PasoTema(c: c),
                PasoCreacion.pregunta => _PasoPregunta(c: c),
                PasoCreacion.contexto => _PasoContexto(c: c),
                PasoCreacion.perspectivas => _PasoPerspectivas(c: c),
                PasoCreacion.objetivo => _PasoObjetivo(c: c),
                PasoCreacion.revision => _PasoRevision(c: c),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  if (paso.index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ocupado ? null : c.anterior,
                        child: const Text('Atrás'),
                      ),
                    ),
                  if (paso.index > 0) const SizedBox(width: AppSpacing.s),
                  Expanded(
                    flex: 2,
                    child: paso == PasoCreacion.revision
                        ? FilledButton(
                            key: const Key('crear-publicar'),
                            onPressed: ocupado ? null : onPublicar,
                            child: ocupado
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    c.modoEdicion
                                        ? 'Guardar cambios'
                                        : 'Publicar debate',
                                  ),
                          )
                        : FilledButton(
                            key: const Key('crear-siguiente'),
                            onPressed: ocupado ? null : c.siguiente,
                            child: ocupado
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Siguiente'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Campo de texto ligado al controlador, con el error junto al campo.
class _Campo extends StatefulWidget {
  const _Campo({
    required this.clave,
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
    required this.error,
    this.ayuda,
    this.maximo,
    this.lineas = 1,
  });

  final String clave;
  final String etiqueta;
  final String valor;
  final ValueChanged<String> alCambiar;
  final String? error;
  final String? ayuda;
  final int? maximo;
  final int lineas;

  @override
  State<_Campo> createState() => _CampoState();
}

class _CampoState extends State<_Campo> {
  late final _texto = TextEditingController(text: widget.valor);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: Key('campo-${widget.clave}'),
      controller: _texto,
      onChanged: widget.alCambiar,
      minLines: widget.lineas,
      maxLines: widget.lineas == 1 ? 1 : widget.lineas + 4,
      maxLength: widget.maximo,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        helperMaxLines: 4,
        errorText: widget.error,
        errorMaxLines: 3,
        alignLabelWithHint: widget.lineas > 1,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _Explicacion extends StatelessWidget {
  const _Explicacion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.m),
    child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _PasoTema extends StatelessWidget {
  const _PasoTema({required this.c});

  final CrearDebateController c;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Explicacion(
            'Elige la categoría del catálogo y a quién afecta el tema.',
          ),
          DropdownButtonFormField<String>(
            key: const Key('campo-categoria'),
            initialValue: c.categoria.value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Categoría',
              errorText: c.errores['categoria'],
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final (codigo, etiqueta) in categoriasDebate)
                DropdownMenuItem(value: codigo, child: Text(etiqueta)),
            ],
            onChanged: c.cambiarCategoria,
          ),
          const SizedBox(height: AppSpacing.m),
          _Campo(
            clave: 'ambito',
            etiqueta: 'Ámbito o comunidad afectada',
            ayuda: 'Ej.: estudiantes de colegios públicos de Quito.',
            valor: c.ambito.value,
            alCambiar: c.cambiarAmbito,
            error: c.errores['ambito'],
            maximo: LimitesDebate.ambito.$2,
          ),
        ],
      ),
    );
  }
}

class _PasoPregunta extends StatelessWidget {
  const _PasoPregunta({required this.c});

  final CrearDebateController c;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Explicacion(
            'Formula una pregunta abierta, que admita varias respuestas razonables.',
          ),
          _Campo(
            clave: 'titulo',
            etiqueta: 'Pregunta del debate',
            ayuda:
                'Ejemplos: «¿Debería…?», «¿Cómo podríamos…?», «¿Qué prioridad '
                'debería tener…?».',
            valor: c.titulo.value,
            alCambiar: c.cambiarTitulo,
            error: c.errores['titulo'],
            maximo: LimitesDebate.titulo.$2,
            lineas: 2,
          ),
        ],
      ),
    );
  }
}

class _PasoContexto extends StatelessWidget {
  const _PasoContexto({required this.c});

  final CrearDebateController c;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Explicacion(
            'El resumen aparece en el catálogo; la descripción explica el problema.',
          ),
          _Campo(
            clave: 'resumen',
            etiqueta: 'Resumen para el catálogo',
            valor: c.resumen.value,
            alCambiar: c.cambiarResumen,
            error: c.errores['resumen'],
            maximo: LimitesDebate.resumen.$2,
            lineas: 3,
          ),
          const SizedBox(height: AppSpacing.m),
          _Campo(
            clave: 'contexto',
            etiqueta: 'Descripción del problema',
            ayuda: 'Qué ocurre, a quién afecta y por qué se discute.',
            valor: c.contexto.value,
            alCambiar: c.cambiarContexto,
            error: c.errores['contexto'],
            maximo: LimitesDebate.contexto.$2,
            lineas: 6,
          ),
        ],
      ),
    );
  }
}

class _PasoPerspectivas extends StatelessWidget {
  const _PasoPerspectivas({required this.c});

  final CrearDebateController c;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Explicacion(
            'Presenta entre 2 y 5 alternativas distintas, cada una con su explicación.',
          ),
          if (c.errores['perspectivas'] != null) ...[
            Aviso(texto: c.errores['perspectivas']!, esError: true),
            const SizedBox(height: AppSpacing.m),
          ],
          for (var i = 0; i < c.perspectivas.length; i++)
            Card(
              key: ValueKey('perspectiva-${c.idsPerspectivas[i]}'),
              margin: const EdgeInsets.only(bottom: AppSpacing.m),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Perspectiva ${i + 1}',
                            style: texto.titleSmall,
                          ),
                        ),
                        if (c.perspectivas.length >
                            LimitesDebate.minPerspectivas)
                          IconButton(
                            tooltip: 'Quitar perspectiva ${i + 1}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => c.quitarPerspectiva(i),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _Campo(
                      clave: 'perspectiva-$i-titulo',
                      etiqueta: 'Título',
                      valor: c.perspectivas[i].titulo,
                      alCambiar: (v) => c.cambiarPerspectiva(i, titulo: v),
                      error: c.errores['perspectiva.$i.titulo'],
                      maximo: LimitesDebate.perspectivaTitulo.$2,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    _Campo(
                      clave: 'perspectiva-$i-descripcion',
                      etiqueta: 'Explicación',
                      valor: c.perspectivas[i].descripcion,
                      alCambiar: (v) => c.cambiarPerspectiva(i, descripcion: v),
                      error: c.errores['perspectiva.$i.descripcion'],
                      maximo: LimitesDebate.perspectivaDescripcion.$2,
                      lineas: 3,
                    ),
                  ],
                ),
              ),
            ),
          if (c.perspectivas.length < LimitesDebate.maxPerspectivas)
            OutlinedButton.icon(
              key: const Key('agregar-perspectiva'),
              onPressed: c.agregarPerspectiva,
              icon: const Icon(Icons.add),
              label: const Text('Añadir perspectiva'),
            ),
        ],
      ),
    );
  }
}

class _PasoObjetivo extends StatelessWidget {
  const _PasoObjetivo({required this.c});

  final CrearDebateController c;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Explicacion(
            '¿Qué se busca aclarar o decidir con este debate?',
          ),
          _Campo(
            clave: 'objetivo',
            etiqueta: 'Objetivo del debate',
            valor: c.objetivo.value,
            alCambiar: c.cambiarObjetivo,
            error: c.errores['objetivo'],
            maximo: LimitesDebate.objetivo.$2,
            lineas: 3,
          ),
        ],
      ),
    );
  }
}

class _PasoRevision extends StatelessWidget {
  const _PasoRevision({required this.c});

  final CrearDebateController c;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final nombre = Get.find<SesionController>().usuario.value?.nombre ?? '';
    return Obx(() {
      final errores = c.validarTodo();
      final pendientes = c.pasosConErrores(errores);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.errorPublicar.value != null) ...[
            Aviso(texto: c.errorPublicar.value!, esError: true),
            const SizedBox(height: AppSpacing.m),
          ],
          if (pendientes.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antes de publicar, completa:',
                      style: texto.titleSmall,
                    ),
                    for (final p in pendientes)
                      TextButton.icon(
                        onPressed: () => c.irA(p),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text('Paso ${p.numero}: ${p.titulo}'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
          ],
          Aviso(
            texto: c.modoEdicion
                ? 'Solo puedes editar mientras el debate no tenga aportes.'
                : 'Se publicará con tu nombre visible ($nombre) como debate creado '
                      'por la comunidad. No será material verificado por Ágora Joven.',
          ),
          const SizedBox(height: AppSpacing.m),
          Text('Vista previa', style: texto.titleLarge),
          const SizedBox(height: AppSpacing.s),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${etiquetaCategoria(c.categoria.value)} · ${c.ambito.value}',
                    style: texto.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(c.titulo.value, style: texto.headlineSmall),
                  const SizedBox(height: AppSpacing.s),
                  Text(c.resumen.value, style: texto.titleSmall),
                  const SizedBox(height: AppSpacing.m),
                  Text('Contexto', style: texto.titleMedium),
                  Text(c.contexto.value),
                  const SizedBox(height: AppSpacing.m),
                  Text('Perspectivas', style: texto.titleMedium),
                  for (final p in c.perspectivas)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text('• ${p.titulo}: ${p.descripcion}'),
                    ),
                  const SizedBox(height: AppSpacing.m),
                  Text('Objetivo', style: texto.titleMedium),
                  Text(c.objetivo.value),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

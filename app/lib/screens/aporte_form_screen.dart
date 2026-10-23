import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/aportes_controller.dart';
import '../models/aporte.dart';
import '../theme/app_theme.dart';
import '../widgets/marca.dart';

/// Crear o editar un aporte. Si el envío falla, el texto escrito se conserva.
class AporteFormScreen extends StatefulWidget {
  const AporteFormScreen({super.key, required this.debateId, this.aporte});

  final int debateId;

  /// Aporte a editar; null para crear uno nuevo.
  final Aporte? aporte;

  @override
  State<AporteFormScreen> createState() => _AporteFormScreenState();
}

class _AporteFormScreenState extends State<AporteFormScreen> {
  static const _minimo = 10;
  static const _maximo = 1000;

  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _texto = TextEditingController(
    text: widget.aporte?.texto ?? '',
  );
  late final AportesController _aportes = Get.find(tag: '${widget.debateId}');
  late TipoAporte _tipo = widget.aporte?.tipo ?? TipoAporte.pregunta;

  bool get _editando => widget.aporte != null;

  @override
  void initState() {
    super.initState();
    _aportes.prepararFormulario();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  String? _validar(String? valor) {
    final largo = (valor ?? '').trim().length;
    if (largo < _minimo) return 'Escribe al menos $_minimo caracteres.';
    if (largo > _maximo) return 'Máximo $_maximo caracteres.';
    return null;
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formulario.currentState!.validate()) return;
    final ok = _editando
        ? await _aportes.editar(widget.aporte!, _tipo, _texto.text)
        : await _aportes.publicar(_tipo, _texto.text);
    // Solo se cierra si la operación pertenece a esta sesión y la pantalla sigue abierta.
    if (ok && mounted) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar aporte' : 'Nuevo aporte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Form(
            key: _formulario,
            child: Obx(() {
              final enviando = _aportes.enviando.value;
              final error = _aportes.errorFormulario.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Aviso(texto: error, esError: true),
                    const SizedBox(height: AppSpacing.m),
                  ],
                  Text('Tipo', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.s),
                  SegmentedButton<TipoAporte>(
                    key: const Key('aporte-tipo'),
                    segments: [
                      for (final t in TipoAporte.values)
                        ButtonSegment(value: t, label: Text(t.etiqueta)),
                    ],
                    selected: {_tipo},
                    showSelectedIcon: false,
                    onSelectionChanged: enviando
                        ? null
                        : (s) => setState(() => _tipo = s.first),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextFormField(
                    key: const Key('aporte-texto'),
                    controller: _texto,
                    enabled: !enviando,
                    minLines: 4,
                    maxLines: 10,
                    maxLength: _maximo,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Tu aporte',
                      helperText:
                          'Entre 10 y 1000 caracteres. Escribe con respeto.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: _validar,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton(
                    key: const Key('aporte-enviar'),
                    onPressed: enviando ? null : _enviar,
                    child: enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Enviando aporte',
                            ),
                          )
                        : Text(_editando ? 'Guardar cambios' : 'Publicar'),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

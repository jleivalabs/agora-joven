import 'package:flutter/material.dart';

import '../models/solicitud_archivo.dart';
import '../theme/app_theme.dart';

/// Pide un texto obligatorio (motivo o justificación) con los límites del servidor.
/// Devuelve el texto sin espacios exteriores, o null si se cancela.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  required String explicacion,
  required String etiqueta,
  required String accion,
}) => showDialog<String>(
  context: context,
  builder: (_) => _DialogoMotivo(
    titulo: titulo,
    explicacion: explicacion,
    etiqueta: etiqueta,
    accion: accion,
  ),
);

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({
    required this.titulo,
    required this.explicacion,
    required this.etiqueta,
    required this.accion,
  });

  final String titulo;
  final String explicacion;
  final String etiqueta;
  final String accion;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

// setState solo para el error del campo, estado local del formulario.
class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _texto = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _aceptar() {
    final valor = _texto.text.trim();
    if (valor.length < LimitesMotivo.minimo) {
      setState(
        () => _error = 'Escribe al menos ${LimitesMotivo.minimo} caracteres.',
      );
      return;
    }
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.explicacion),
          const SizedBox(height: AppSpacing.m),
          TextField(
            key: const Key('campo-motivo'),
            controller: _texto,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: LimitesMotivo.maximo,
            decoration: InputDecoration(
              labelText: widget.etiqueta,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirmar-motivo'),
          onPressed: _aceptar,
          child: Text(widget.accion),
        ),
      ],
    );
  }
}

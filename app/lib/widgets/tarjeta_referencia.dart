import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../data/abridor_enlaces.dart';
import '../models/referencia.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Aviso común: localizar una referencia no la convierte en prueba de nada.
const avisoReferencias =
    'Referencias localizadas en Crossref. Que una obra aparezca aquí, tenga DOI o un tipo '
    'declarado no certifica su calidad ni respalda por sí solo ninguna afirmación.';

/// Abre el enlace HTTPS construido desde el DOI, solo al pulsar. Si no se puede abrir, ofrece
/// copiarlo.
Future<void> abrirReferencia(BuildContext context, Referencia r) async {
  final enlace = r.enlace;
  final abierto =
      enlace != null &&
      Get.isRegistered<AbridorEnlaces>() &&
      await Get.find<AbridorEnlaces>().abrir(enlace);
  if (abierto || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('No se pudo abrir el navegador.'),
        action: enlace == null
            ? null
            : SnackBarAction(
                label: 'Copiar enlace',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: enlace.toString())),
              ),
      ),
    );
}

/// Metadatos de una referencia como texto plano, con acciones opcionales.
class TarjetaReferencia extends StatelessWidget {
  const TarjetaReferencia({
    super.key,
    required this.referencia,
    this.acciones = const [],
    this.otrasEnLista = const {},
  });

  final Referencia referencia;
  final List<Widget> acciones;

  /// DOI de las demás referencias mostradas, para señalar versiones de la misma obra.
  final Set<String> otrasEnLista;

  @override
  Widget build(BuildContext context) {
    final r = referencia;
    final texto = Theme.of(context).textTheme;
    final mismaObra = r.mismaObraQue.where(otrasEnLista.contains).toList();
    final detalles = [
      if (r.autores.isNotEmpty)
        r.autores.length > 3
            ? '${r.autores.take(3).join(', ')} y otros'
            : r.autores.join(', '),
      ?r.fechaPublicacion,
      ?r.publicacion,
    ];
    return Card(
      key: Key('referencia-${r.doi}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.titulo, style: texto.titleMedium),
            if (detalles.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(detalles.join(' · '), style: texto.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${etiquetaTipoReferencia(r.tipo)} · DOI ${r.doi}',
              style: texto.bodySmall,
            ),
            Text(
              'Localizada en Crossref el ${fechaHora(r.consultadaEn)}',
              style: texto.bodySmall,
            ),
            if (mismaObra.isNotEmpty)
              Text(
                'Versión de la misma obra que ${mismaObra.join(', ')}: no son fuentes '
                'independientes.',
                style: texto.bodySmall,
              ),
            Wrap(
              spacing: AppSpacing.s,
              children: [
                TextButton.icon(
                  key: Key('abrir-${r.doi}'),
                  onPressed: () => abrirReferencia(context, r),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir en el navegador'),
                ),
                ...acciones,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

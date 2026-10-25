import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme/app_theme.dart';

/// Muestra Markdown de una fuente no confiable (respuestas de la IA) con el tema de la app.
///
/// - Usa `MarkdownBody`: se ajusta a su contenido, sin scroll propio ni altura fija.
/// - No carga imágenes: el constructor por defecto del paquete usaría `Image.network`; aquí se
///   sustituye por un texto con la descripción.
/// - Los enlaces se muestran como texto con estilo, pero no se abren (sin `onTapLink`).
/// - El HTML incrustado no se interpreta ni se ejecuta: el paquete no renderiza HTML (un bloque
///   HTML se omite).
class TextoMarkdownSeguro extends StatelessWidget {
  const TextoMarkdownSeguro({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estilo = tema.textTheme;
    final base = estilo.bodyMedium?.copyWith(height: 1.45);

    return MarkdownBody(
      data: texto,
      selectable: true,
      imageBuilder: (uri, title, alt) => Text(
        '[Imagen no mostrada${alt == null || alt.isEmpty ? '' : ': $alt'}]',
        style: estilo.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      ),
      styleSheet: MarkdownStyleSheet.fromTheme(tema).copyWith(
        p: base,
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        // Jerarquía visible pero contenida dentro de la tarjeta del asistente.
        h1: estilo.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        h2: estilo.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        h3: estilo.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        h4: estilo.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        h1Padding: const EdgeInsets.only(top: AppSpacing.s),
        h2Padding: const EdgeInsets.only(top: AppSpacing.s),
        h3Padding: const EdgeInsets.only(top: AppSpacing.xs),
        listBullet: base,
        listIndent: AppSpacing.l,
        blockSpacing: AppSpacing.s,
        a: base?.copyWith(
          color: tema.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        blockquoteDecoration: BoxDecoration(
          color: tema.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace en el navegador externo, solo por acción explícita de la persona.
///
/// Únicamente HTTPS: cualquier otro esquema se rechaza sin intentar abrirlo. Devuelve false si
/// no se pudo abrir (sin navegador, enlace no válido…); la pantalla ofrece entonces copiarlo.
abstract class AbridorEnlaces {
  Future<bool> abrir(Uri enlace);
}

class NavegadorExterno implements AbridorEnlaces {
  @override
  Future<bool> abrir(Uri enlace) async {
    if (enlace.scheme != 'https' || enlace.host.isEmpty) return false;
    try {
      return await launchUrl(enlace, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

import 'package:get/get.dart';

/// Aviso de que cambió el contenido de la comunidad: un aporte (publicar, editar, eliminar) o un
/// debate (publicar, editar, archivar), siempre después de que el servidor lo confirme.
/// El dashboard, el catálogo y "Mis debates" lo escuchan para actualizarse.
class ActividadComunidad extends GetxService {
  final cambios = 0.obs;

  void avisar() => cambios.value++;
}

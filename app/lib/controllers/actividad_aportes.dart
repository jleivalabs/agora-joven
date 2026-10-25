import 'package:get/get.dart';

/// Aviso de que cambiaron los aportes (publicar, editar o eliminar confirmados por el servidor).
/// El dashboard lo escucha para actualizar sus cifras.
class ActividadAportes extends GetxService {
  final cambios = 0.obs;

  void avisar() => cambios.value++;
}

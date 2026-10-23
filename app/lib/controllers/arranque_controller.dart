import 'package:get/get.dart';

enum EstadoArranque { cargando, listo, error }

/// Tarea de preparación que se ejecuta antes de mostrar la app.
///
/// En el Bloque 0 no hay tareas reales; los bloques siguientes añadirán aquí
/// la apertura de Hive y la restauración de la sesión.
typedef TareaArranque = Future<void> Function();

/// Estado de arranque de la app, compartido por las pantallas mediante GetX.
class ArranqueController extends GetxController {
  ArranqueController({this.tareas = const []});

  final List<TareaArranque> tareas;

  final estado = EstadoArranque.cargando.obs;
  final mensajeError = RxnString();

  @override
  void onInit() {
    super.onInit();
    iniciar();
  }

  Future<void> iniciar() async {
    estado.value = EstadoArranque.cargando;
    mensajeError.value = null;
    try {
      for (final tarea in tareas) {
        await tarea();
      }
      estado.value = EstadoArranque.listo;
    } catch (_) {
      mensajeError.value = 'No se pudo preparar la aplicación.';
      estado.value = EstadoArranque.error;
    }
  }
}

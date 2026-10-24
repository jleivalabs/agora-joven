import '../data/guardados_local.dart';
import '../models/debate.dart';
import '../models/debate_guardado.dart';

/// Debates guardados en el dispositivo para cada cuenta. No usa la red.
class GuardadosRepository {
  GuardadosRepository(this._almacen);

  final AlmacenGuardados _almacen;

  /// Más recientes primero.
  Future<List<DebateGuardado>> listar(int usuarioId) async {
    final lista = await _almacen.leer(usuarioId);
    return lista..sort((a, b) => b.guardadoEn.compareTo(a.guardadoEn));
  }

  /// Guarda solo los datos editoriales mínimos del debate.
  Future<DebateGuardado> guardar(
    int usuarioId,
    DebateResumen debate,
    String etiquetaCategoria,
  ) async {
    final guardado = DebateGuardado(
      id: debate.id,
      titulo: debate.titulo,
      categoria: debate.categoria,
      etiquetaCategoria: etiquetaCategoria,
      guardadoEn: DateTime.now().toUtc(),
    );
    await _almacen.guardar(usuarioId, guardado);
    return guardado;
  }

  Future<void> quitar(int usuarioId, int debateId) =>
      _almacen.quitar(usuarioId, debateId);
}

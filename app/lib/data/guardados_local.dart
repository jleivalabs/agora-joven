import 'package:hive/hive.dart';

import '../models/debate_guardado.dart';

/// Error al leer o escribir los guardados en el dispositivo.
class ErrorAlmacenLocal implements Exception {
  const ErrorAlmacenLocal(this.operacion);

  final String operacion;

  @override
  String toString() => 'ErrorAlmacenLocal($operacion)';
}

/// Fuente de datos local de debates guardados, separada por usuario.
abstract class AlmacenGuardados {
  /// Guardados de [usuarioId]. Los registros con forma inesperada se omiten, sin borrarlos.
  Future<List<DebateGuardado>> leer(int usuarioId);

  /// Guarda o sustituye (la clave es el id del debate: no hay duplicados).
  Future<void> guardar(int usuarioId, DebateGuardado debate);

  Future<void> quitar(int usuarioId, int debateId);
}

/// Implementación con Hive: una caja por usuario (`guardados_<id>`), clave = id del debate.
///
/// Requiere haber llamado antes a `Hive.initFlutter()` (en la app) o `Hive.init(dir)` (pruebas).
/// Las cajas no se borran al cerrar sesión: los guardados se conservan para esa cuenta.
class HiveAlmacenGuardados implements AlmacenGuardados {
  static String nombreCaja(int usuarioId) => 'guardados_$usuarioId';

  Future<Box<Map>> _caja(int usuarioId) async {
    final nombre = nombreCaja(usuarioId);
    if (Hive.isBoxOpen(nombre)) return Hive.box<Map>(nombre);
    return Hive.openBox<Map>(nombre);
  }

  @override
  Future<List<DebateGuardado>> leer(int usuarioId) async {
    try {
      final caja = await _caja(usuarioId);
      final guardados = <DebateGuardado>[];
      for (final valor in caja.values) {
        try {
          guardados.add(DebateGuardado.desdeMapa(valor));
        } on FormatException {
          // Registro dañado: se omite de la lista, pero no se borra.
        }
      }
      return guardados;
    } catch (_) {
      throw const ErrorAlmacenLocal('leer');
    }
  }

  @override
  Future<void> guardar(int usuarioId, DebateGuardado debate) async {
    try {
      final caja = await _caja(usuarioId);
      await caja.put(debate.id, debate.aMapa());
    } catch (_) {
      throw const ErrorAlmacenLocal('guardar');
    }
  }

  @override
  Future<void> quitar(int usuarioId, int debateId) async {
    try {
      final caja = await _caja(usuarioId);
      await caja.delete(debateId);
    } catch (_) {
      throw const ErrorAlmacenLocal('quitar');
    }
  }
}

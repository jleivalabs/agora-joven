import 'dart:io';

import 'package:agora_joven/data/guardados_local.dart';
import 'package:agora_joven/models/debate_guardado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Persistencia real con Hive en un directorio temporal (sin Flutter ni plataforma).
void main() {
  late Directory directorio;
  late HiveAlmacenGuardados almacen;

  DebateGuardado debate(int id, {String titulo = 'Debate'}) => DebateGuardado(
    id: id,
    titulo: '$titulo $id',
    categoria: 'educacion',
    etiquetaCategoria: 'Educación',
    guardadoEn: DateTime.utc(2026, 10, 23, 10, id),
  );

  /// Simula el cierre completo de la app: cierra Hive y lo vuelve a abrir en el mismo directorio.
  Future<void> reabrir() async {
    await Hive.close();
    Hive.init(directorio.path);
  }

  setUp(() async {
    directorio = await Directory.systemTemp.createTemp('agora_hive_');
    Hive.init(directorio.path);
    almacen = HiveAlmacenGuardados();
  });

  tearDown(() async {
    await Hive.close();
    await directorio.delete(recursive: true);
  });

  test('los guardados sobreviven a cerrar y reabrir Hive', () async {
    await almacen.guardar(1, debate(3));
    await almacen.guardar(1, debate(7));

    await reabrir();
    final leidos = await HiveAlmacenGuardados().leer(1);

    expect(leidos.map((d) => d.id), unorderedEquals([3, 7]));
    final tres = leidos.firstWhere((d) => d.id == 3);
    expect(tres.titulo, 'Debate 3');
    expect(tres.etiquetaCategoria, 'Educación');
    expect(tres.guardadoEn, DateTime.utc(2026, 10, 23, 10, 3));
  });

  test('cada cuenta tiene su propia caja', () async {
    await almacen.guardar(1, debate(3));
    await almacen.guardar(2, debate(5));

    await reabrir();

    expect((await almacen.leer(1)).map((d) => d.id), [3]);
    expect((await almacen.leer(2)).map((d) => d.id), [5]);
    expect(await almacen.leer(99), isEmpty);
  });

  test('guardar dos veces el mismo debate no lo duplica', () async {
    await almacen.guardar(1, debate(3, titulo: 'Antes'));
    await almacen.guardar(1, debate(3, titulo: 'Después'));

    final leidos = await almacen.leer(1);
    expect(leidos, hasLength(1));
    expect(leidos.single.titulo, 'Después 3');
  });

  test('quitar elimina solo ese debate y persiste', () async {
    await almacen.guardar(1, debate(3));
    await almacen.guardar(1, debate(4));
    await almacen.quitar(1, 3);

    await reabrir();

    expect((await almacen.leer(1)).map((d) => d.id), [4]);
  });

  test('solo se guardan los campos editoriales mínimos', () async {
    await almacen.guardar(1, debate(3));

    final caja = await Hive.openBox<Map>(HiveAlmacenGuardados.nombreCaja(1));
    expect(
      caja.get(3)!.keys,
      unorderedEquals([
        'id',
        'titulo',
        'categoria',
        'etiqueta_categoria',
        'guardado_en',
      ]),
    );
  });

  test('un registro dañado se omite al leer pero no se borra', () async {
    await almacen.guardar(1, debate(3));
    final caja = await Hive.openBox<Map>(HiveAlmacenGuardados.nombreCaja(1));
    await caja.put(8, {'id': 'no-es-un-numero'});

    final leidos = await almacen.leer(1);

    expect(leidos.map((d) => d.id), [3]);
    expect(caja.containsKey(8), isTrue);
  });
}

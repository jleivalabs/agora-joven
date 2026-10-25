import 'package:agora_joven/models/debate.dart';
import 'package:agora_joven/models/estadisticas.dart';
import 'package:agora_joven/utils/formato.dart';
import 'package:flutter_test/flutter_test.dart';

EstadisticasComunidad conCategorias(Map<String, int> totales) =>
    EstadisticasComunidad(
      totalDebates: totales.values.fold(0, (a, b) => a + b),
      porCategoria: [
        for (final e in totales.entries)
          Categoria(
            codigo: e.key.toLowerCase(),
            etiqueta: e.key,
            total: e.value,
          ),
      ],
      totalAportes: 0,
      participantes: 0,
      totalSinAportes: 0,
      sinAportes: const [],
      actividadReciente: const [],
    );

void main() {
  test(
    'orden alfabético español: sin tildes ni mayúsculas, ñ después de n',
    () {
      final palabras = [
        'Ñandú',
        'educación',
        'Ambiente',
        'Nube',
        'Educa',
        'Árbol',
        'nzeta',
      ];

      expect([...palabras]..sort(compararEs), [
        'Ambiente',
        'Árbol',
        'Educa',
        'educación',
        'Nube',
        'nzeta',
        'Ñandú',
      ]);
    },
  );

  test('con los datos actuales del catálogo', () {
    // Recuento real del catálogo editorial (backend/app/datos/debates.json), en el orden en que
    // lo envía el servidor.
    final comunidad = conCategorias({
      'Educación': 3,
      'Ambiente': 3,
      'Movilidad': 3,
      'Empleo': 2,
      'Salud': 2,
      'Tecnología': 3,
      'Cultura': 2,
      'Participación': 2,
    });

    expect(comunidad.categoriasPorCantidad.map((c) => c.etiqueta), [
      'Ambiente',
      'Educación',
      'Movilidad',
      'Tecnología',
      'Cultura',
      'Empleo',
      'Participación',
      'Salud',
    ]);
  });

  test('cantidades distintas primero, empates por nombre', () {
    final comunidad = conCategorias({
      'Salud': 1,
      'Ambiente': 0,
      'Tecnología': 5,
      'Educación': 2,
      'Empleo': 2,
      'Cultura': 0,
    });

    expect(
      comunidad.categoriasPorCantidad.map((c) => '${c.etiqueta} ${c.total}'),
      [
        'Tecnología 5',
        'Educación 2',
        'Empleo 2',
        'Salud 1',
        'Ambiente 0',
        'Cultura 0',
      ],
    );
    // El orden original que envía el servidor no se modifica.
    expect(comunidad.porCategoria.first.etiqueta, 'Salud');
  });
}

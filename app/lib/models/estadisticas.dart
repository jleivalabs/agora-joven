import '../utils/formato.dart';
import 'aporte.dart';
import 'debate.dart';

/// Identificación mínima de un debate en los listados del dashboard.
class DebateBreve {
  const DebateBreve({
    required this.id,
    required this.titulo,
    required this.categoria,
  });

  final int id;
  final String titulo;
  final String categoria;

  factory DebateBreve.fromJson(Map<String, dynamic> json) => DebateBreve(
    id: json['id'] as int,
    titulo: json['titulo'] as String,
    categoria: json['categoria'] as String,
  );
}

class DebateConActividad {
  const DebateConActividad({
    required this.debate,
    required this.aportes,
    required this.ultimoAporteEn,
  });

  final DebateBreve debate;
  final int aportes;
  final DateTime ultimoAporteEn;

  factory DebateConActividad.fromJson(Map<String, dynamic> json) =>
      DebateConActividad(
        debate: DebateBreve.fromJson(json['debate'] as Map<String, dynamic>),
        aportes: json['aportes'] as int,
        ultimoAporteEn: DateTime.parse(json['ultimo_aporte_en'] as String),
      );
}

/// Cifras públicas agregadas que calcula el servidor (sin identidades).
class EstadisticasComunidad {
  const EstadisticasComunidad({
    required this.totalDebates,
    this.debatesArchivados = 0,
    required this.porCategoria,
    required this.totalAportes,
    required this.participantes,
    required this.totalSinAportes,
    required this.sinAportes,
    required this.actividadReciente,
  });

  /// Debates publicados activos (sin archivados ni borradores).
  final int totalDebates;
  final int debatesArchivados;

  /// Debates publicados activos por categoría.
  final List<Categoria> porCategoria;
  final int totalAportes;

  /// Cuentas distintas con al menos un aporte (no las cuentas registradas).
  final int participantes;
  final int totalSinAportes;

  /// Primeros debates sin aportes, en el orden del catálogo.
  final List<DebateBreve> sinAportes;

  /// Debates por la fecha de su aporte más reciente.
  final List<DebateConActividad> actividadReciente;

  /// Categorías de más a menos debates publicados; en empate, por nombre visible
  /// (orden alfabético español). En 7A cuenta todos los debates del catálogo actual.
  List<Categoria> get categoriasPorCantidad => [...porCategoria]
    ..sort((a, b) {
      final porTotal = b.total.compareTo(a.total);
      return porTotal != 0 ? porTotal : compararEs(a.etiqueta, b.etiqueta);
    });

  String etiqueta(String codigo) =>
      porCategoria
          .where((c) => c.codigo == codigo)
          .map((c) => c.etiqueta)
          .firstOrNull ??
      codigo;

  factory EstadisticasComunidad.fromJson(Map<String, dynamic> json) {
    final sin = json['sin_aportes'] as Map<String, dynamic>;
    return EstadisticasComunidad(
      totalDebates: json['total_debates'] as int,
      debatesArchivados: (json['debates_archivados'] as int?) ?? 0,
      porCategoria: [
        for (final c in json['por_categoria'] as List)
          Categoria.fromJson(c as Map<String, dynamic>),
      ],
      totalAportes: json['total_aportes'] as int,
      participantes: json['participantes'] as int,
      totalSinAportes: sin['total'] as int,
      sinAportes: [
        for (final d in sin['debates'] as List)
          DebateBreve.fromJson(d as Map<String, dynamic>),
      ],
      actividadReciente: [
        for (final a in json['actividad_reciente'] as List)
          DebateConActividad.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}

class MiAporteReciente {
  const MiAporteReciente({
    required this.id,
    required this.tipo,
    required this.texto,
    required this.creadoEn,
    required this.debate,
  });

  final int id;
  final TipoAporte tipo;
  final String texto;
  final DateTime creadoEn;
  final DebateBreve debate;

  factory MiAporteReciente.fromJson(Map<String, dynamic> json) =>
      MiAporteReciente(
        id: json['id'] as int,
        tipo: TipoAporte.desdeCodigo(json['tipo'] as String),
        texto: json['texto'] as String,
        creadoEn: DateTime.parse(json['creado_en'] as String),
        debate: DebateBreve.fromJson(json['debate'] as Map<String, dynamic>),
      );
}

/// Participación de la cuenta de la sesión (el servidor usa el usuario del token).
class EstadisticasPersonales {
  const EstadisticasPersonales({
    required this.totalAportes,
    required this.porTipo,
    required this.debatesParticipados,
    required this.aportesRecientes,
    this.misDebates = const MisDebatesTotales(),
  });

  final int totalAportes;
  final Map<TipoAporte, int> porTipo;
  final int debatesParticipados;
  final List<MiAporteReciente> aportesRecientes;
  final MisDebatesTotales misDebates;

  factory EstadisticasPersonales.fromJson(Map<String, dynamic> json) {
    final tipos = json['por_tipo'] as Map<String, dynamic>;
    return EstadisticasPersonales(
      totalAportes: json['total_aportes'] as int,
      porTipo: {for (final t in TipoAporte.values) t: tipos[t.name] as int},
      debatesParticipados: json['debates_participados'] as int,
      aportesRecientes: [
        for (final a in json['aportes_recientes'] as List)
          MiAporteReciente.fromJson(a as Map<String, dynamic>),
      ],
      misDebates: json['mis_debates'] == null
          ? const MisDebatesTotales()
          : MisDebatesTotales.fromJson(
              json['mis_debates'] as Map<String, dynamic>,
            ),
    );
  }
}

/// Cuántos debates propios hay en cada estado (borradores privados incluidos).
class MisDebatesTotales {
  const MisDebatesTotales({
    this.borradores = 0,
    this.publicados = 0,
    this.archivados = 0,
  });

  final int borradores;
  final int publicados;
  final int archivados;

  factory MisDebatesTotales.fromJson(Map<String, dynamic> json) =>
      MisDebatesTotales(
        borradores: json['borradores'] as int,
        publicados: json['publicados'] as int,
        archivados: json['archivados'] as int,
      );
}

enum AccionAsistente {
  contexto('Explicar el contexto'),
  perspectivas('Resumir perspectivas de los aportes');

  const AccionAsistente(this.etiqueta);

  final String etiqueta;
}

/// Resultado del asistente. Es texto generado por IA: no se guarda ni se publica como aporte.
class RespuestaAsistente {
  const RespuestaAsistente({
    required this.accion,
    required this.sinAportes,
    required this.texto,
    required this.aviso,
    required this.aportesUsados,
    required this.aportesTotales,
    required this.parcial,
    required this.truncado,
  });

  final AccionAsistente accion;

  /// No había aportes que resumir: el servidor no llamó a la IA.
  final bool sinAportes;
  final String? texto;
  final String? aviso;
  final int aportesUsados;
  final int aportesTotales;
  final bool parcial;
  final bool truncado;

  factory RespuestaAsistente.fromJson(Map<String, dynamic> json) {
    final estado = json['estado'] as String;
    if (estado != 'generado' && estado != 'sin_aportes') {
      throw FormatException('Estado del asistente desconocido: $estado');
    }
    return RespuestaAsistente(
      accion: AccionAsistente.values.firstWhere(
        (a) => a.name == json['accion'],
        orElse: () => throw const FormatException('Acción desconocida'),
      ),
      sinAportes: estado == 'sin_aportes',
      texto: json['texto'] as String?,
      aviso: json['aviso'] as String?,
      aportesUsados: json['aportes_usados'] as int,
      aportesTotales: json['aportes_totales'] as int,
      parcial: json['parcial'] as bool,
      truncado: json['truncado'] as bool,
    );
  }
}

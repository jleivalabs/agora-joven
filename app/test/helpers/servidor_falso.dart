import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_joven/data/api_client.dart';
import 'package:agora_joven/data/guardados_local.dart';
import 'package:agora_joven/data/token_storage.dart';
import 'package:agora_joven/models/debate_guardado.dart';
import 'package:dio/dio.dart';

const emailAna = 'ana@example.com';
const passwordAna = 'clave-de-prueba-123';
const emailBeto = 'beto@example.com';

/// Cuenta con rol de administración en el servidor falso (misma contraseña de prueba).
const emailRosa = 'rosa@example.com';

class RespuestaFalsa {
  const RespuestaFalsa(this.codigo, [this.cuerpo]);

  final int codigo;
  final Object? cuerpo;
}

typedef Manejador = FutureOr<RespuestaFalsa> Function(RequestOptions peticion);

/// Backend falso que se conecta a Dio como adaptador HTTP: la app usa su ApiClient real.
///
/// Por defecto imita el contrato del backend con datos sintéticos (no el catálogo real).
/// Cada ruta se puede sustituir con [cuando] para forzar errores o retrasos.
class ServidorFalso implements HttpClientAdapter {
  ServidorFalso() {
    // Versión 1 de cada debate editorial (antes de que una prueba añada otros).
    versiones.addAll([for (final d in debates) _versionDe(d, 1, 'catalogo')]);
    _rutasPorDefecto();
    _rutasDeAportes();
    _rutaDelAsistente();
    _rutasDeEstadisticas();
    _rutasDeBorradores();
    _rutasDeSolicitudes();
  }

  final _rutas = <String, Manejador>{};
  final peticiones = <RequestOptions>[];
  final tokensValidos = <String, int>{'token-ana': 1, 'token-beto': 2};
  final usuarios = <String, Map<String, Object>>{
    emailAna: {
      'id': 1,
      'nombre': 'Ana',
      'email': emailAna,
      'password': passwordAna,
    },
    emailBeto: {
      'id': 2,
      'nombre': 'Beto',
      'email': emailBeto,
      'password': passwordAna,
    },
    emailRosa: {
      'id': 3,
      'nombre': 'Rosa',
      'email': emailRosa,
      'password': passwordAna,
      'rol': 'administrador',
    },
  };

  /// Solicitudes de archivo (con `solicitante_id` y `revisor_id`, que no ve el solicitante).
  final solicitudes = <Map<String, Object?>>[];

  /// Debates de esta instancia: copia de [debatesFalsos] más los que se publiquen.
  final debates = [
    for (final d in debatesFalsos)
      {
        ...d,
        'procedencia': 'editorial',
        'estado': 'publicado',
        'autor_id': null,
        'version_actual': 1,
        'con_participacion': false,
      },
  ];

  /// Versiones publicadas (7B.1): solo se insertan.
  final versiones = <Map<String, Object?>>[];

  /// Aclaraciones de los autores (7B.1): solo se insertan.
  final aclaraciones = <Map<String, Object?>>[];

  Map<String, Object?> _versionDe(
    Map<String, Object?> d,
    int numero,
    String tipo, {
    int? autorId,
    String? motivo,
  }) => {
    'debate_id': d['id'],
    'numero': numero,
    'tipo': tipo,
    for (final c in _camposContenido) c: d[c],
    'creada_en': '2026-10-24T12:0$numero:00Z',
    'autor_id': autorId,
    'motivo': motivo,
  };

  /// Borradores privados (con `autor_id`, que nunca se envía al cliente).
  final borradores = <Map<String, Object?>>[];
  int _siguienteBorrador = 0;

  /// Aportes guardados en el servidor falso (con `autor_id`, que nunca se envía al cliente).
  final aportes = <Map<String, Object?>>[];
  int _siguienteAporte = 0;
  int _siguienteToken = 0;

  ApiClient cliente() =>
      ApiClient(baseUrl: 'http://servidor.falso', adaptador: this);

  /// Sustituye el manejador de una ruta, por ejemplo `cuando('GET /debates', ...)`.
  /// Las rutas con id usan `{id}`: `GET /debates/{id}`, `PATCH /aportes/{id}`.
  void cuando(String ruta, Manejador manejador) => _rutas[ruta] = manejador;

  /// Manejador actual de una ruta (para restaurarlo tras simular un fallo).
  Manejador? manejador(String ruta) => _rutas[ruta];

  int contar(String ruta) => peticiones.where((p) => _clave(p) == ruta).length;

  String _clave(RequestOptions p) {
    final ruta = p.path.replaceAll(RegExp(r'/\d+(?=/|$)'), '/{id}');
    return '${p.method} $ruta';
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    peticiones.add(options);
    final manejador = _rutas[_clave(options)];
    final respuesta = manejador == null
        ? const RespuestaFalsa(404, {'detail': 'Not Found'})
        : await manejador(options);
    return ResponseBody.fromString(
      respuesta.cuerpo == null ? '' : jsonEncode(respuesta.cuerpo),
      respuesta.codigo,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  int? usuarioDelToken(RequestOptions p) {
    final cabecera = p.headers['Authorization'] as String?;
    if (cabecera == null || !cabecera.startsWith('Bearer ')) return null;
    return tokensValidos[cabecera.substring(7)];
  }

  static int idDe(RequestOptions p) =>
      int.parse(RegExp(r'/(\d+)').firstMatch(p.path)!.group(1)!);

  /// Guarda un aporte directamente en el servidor (como si lo hubiera publicado [autorId]).
  Map<String, Object?> sembrarAporte({
    required int autorId,
    int debateId = 1,
    String tipo = 'pregunta',
    String texto = 'Aporte sembrado para la prueba.',
    int? version = 1,
  }) {
    // Un aporte marca la participación permanente del debate (como el backend).
    debates
        .where((d) => d['id'] == debateId)
        .forEach((d) => d['con_participacion'] = true);
    final aporte = <String, Object?>{
      'version': version,
      'id': ++_siguienteAporte,
      'debate_id': debateId,
      'autor_id': autorId,
      'tipo': tipo,
      'texto': texto,
      'creado_en':
          '2026-10-22T10:00:${_siguienteAporte.toString().padLeft(2, '0')}Z',
      'editado_en': null,
    };
    aportes.add(aporte);
    return aporte;
  }

  Map<String, Object?> _aporteSalida(Map<String, Object?> a, int usuarioId) {
    final autor = usuarios.values.firstWhere((u) => u['id'] == a['autor_id']);
    return {
      for (final k in [
        'id',
        'debate_id',
        'tipo',
        'texto',
        'creado_en',
        'editado_en',
      ])
        k: a[k],
      'autor_nombre': autor['nombre'],
      'es_propio': a['autor_id'] == usuarioId,
      'version': a['version'],
    };
  }

  static Object? cuerpo(RequestOptions p) =>
      p.data is String ? jsonDecode(p.data as String) : p.data;

  void _rutasPorDefecto() {
    cuando('POST /auth/registro', (p) {
      final datos = cuerpo(p) as Map;
      final email = (datos['email'] as String).trim().toLowerCase();
      if (usuarios.containsKey(email)) {
        return const RespuestaFalsa(400, {
          'detail': 'Ya existe una cuenta con ese correo.',
        });
      }
      final id = usuarios.length + 1;
      usuarios[email] = {
        'id': id,
        'nombre': datos['nombre'] as String,
        'email': email,
        'password': datos['password'] as String,
      };
      return RespuestaFalsa(201, {
        'id': id,
        'nombre': datos['nombre'],
        'email': email,
        'creado_en': '2026-10-22T00:00:00Z',
      });
    });
    cuando('POST /auth/login', (p) {
      final datos = cuerpo(p) as Map;
      final usuario = usuarios[(datos['email'] as String).trim().toLowerCase()];
      if (usuario == null || usuario['password'] != datos['password']) {
        return const RespuestaFalsa(401, {
          'detail': 'Correo o contraseña incorrectos.',
        });
      }
      final token = usuario['id'] == 1
          ? 'token-ana'
          : 'token-${++_siguienteToken}';
      tokensValidos[token] = usuario['id'] as int;
      return RespuestaFalsa(200, {
        'access_token': token,
        'token_type': 'bearer',
        'expira_en': 3600,
      });
    });
    cuando('GET /auth/me', (p) {
      final id = usuarioDelToken(p);
      if (id == null) return _noAutorizado;
      final u = usuarios.values.firstWhere((u) => u['id'] == id);
      return RespuestaFalsa(200, {
        'id': id,
        'nombre': u['nombre'],
        'email': u['email'],
        'creado_en': '2026-10-22T00:00:00Z',
        'rol': u['rol'] ?? 'usuario',
      });
    });
    cuando('GET /debates/categorias', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      return RespuestaFalsa(200, [
        for (final c in categoriasFalsas)
          {
            'categoria': c.$1,
            'etiqueta': c.$2,
            'total': debates
                .where(
                  (d) => d['categoria'] == c.$1 && d['estado'] == 'publicado',
                )
                .length,
          },
      ]);
    });
    cuando('GET /debates', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      final categoria = p.queryParameters['categoria'] as String?;
      if (categoria != null &&
          !categoriasFalsas.any((c) => c.$1 == categoria)) {
        return const RespuestaFalsa(422, {'detail': []});
      }
      return RespuestaFalsa(200, [
        for (final d in debates)
          if (d['estado'] == 'publicado' &&
              (categoria == null || d['categoria'] == categoria))
            resumenDe(d),
      ]);
    });
    cuando('GET /debates/{id}', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      final id = idDe(p);
      final d = debates.where((d) => d['id'] == id).firstOrNull;
      if (d == null) {
        return const RespuestaFalsa(404, {'detail': 'Debate no encontrado.'});
      }
      return RespuestaFalsa(200, detalleDe(d, usuarioDelToken(p)!));
    });
  }

  void _rutasDeAportes() {
    cuando('GET /debates/{id}/aportes', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final debateId = idDe(p);
      final lista = aportes.where((a) => a['debate_id'] == debateId).toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      return RespuestaFalsa(200, [
        for (final a in lista) _aporteSalida(a, usuario),
      ]);
    });
    cuando('POST /debates/{id}/aportes', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      if (_archivado(idDe(p))) return _conflicto;
      final datos = cuerpo(p) as Map;
      final texto = (datos['texto'] as String).trim();
      final version = datos['version'] as int?;
      if (texto.length < 10 || texto.length > 1000 || version == null) {
        return const RespuestaFalsa(422, {'detail': []});
      }
      final debate = debates.firstWhere((d) => d['id'] == idDe(p));
      if (debate['version_actual'] != version) {
        return RespuestaFalsa(409, {
          'detail': {
            'codigo': 'version_desactualizada',
            'mensaje': 'x',
            'version_actual': debate['version_actual'],
          },
        });
      }
      final a = sembrarAporte(
        autorId: usuario,
        debateId: idDe(p),
        tipo: datos['tipo'] as String,
        texto: texto,
        version: version,
      );
      return RespuestaFalsa(201, _aporteSalida(a, usuario));
    });
    cuando('PATCH /aportes/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final a = aportes.where((a) => a['id'] == idDe(p)).firstOrNull;
      if (a == null) {
        return const RespuestaFalsa(404, {'detail': 'Aporte no encontrado.'});
      }
      if (a['autor_id'] != usuario) {
        return const RespuestaFalsa(403, {'detail': 'x'});
      }
      final datos = cuerpo(p) as Map;
      a.addAll({...datos, 'editado_en': '2026-10-22T11:00:00Z'});
      return RespuestaFalsa(200, _aporteSalida(a, usuario));
    });
    cuando('DELETE /aportes/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final a = aportes.where((a) => a['id'] == idDe(p)).firstOrNull;
      if (a == null) {
        return const RespuestaFalsa(404, {'detail': 'Aporte no encontrado.'});
      }
      if (a['autor_id'] != usuario) {
        return const RespuestaFalsa(403, {'detail': 'x'});
      }
      aportes.remove(a);
      return const RespuestaFalsa(204);
    });
  }

  /// Asistente SIMULADO: respuestas fijas, sin IA. Imita el contrato del backend.
  void _rutaDelAsistente() {
    cuando('POST /asistente/debates/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final debateId = idDe(p);
      final accion = (cuerpo(p) as Map)['accion'] as String;
      final total = aportes.where((a) => a['debate_id'] == debateId).length;
      if (accion == 'perspectivas' && total == 0) {
        return RespuestaFalsa(200, {
          'debate_id': debateId,
          'accion': accion,
          'estado': 'sin_aportes',
          'texto': null,
          'aviso': null,
          'aportes_usados': 0,
          'aportes_totales': 0,
          'parcial': false,
          'truncado': false,
        });
      }
      final usados = accion == 'perspectivas' ? (total > 2 ? 2 : total) : 0;
      return RespuestaFalsa(200, {
        'debate_id': debateId,
        'accion': accion,
        'estado': 'generado',
        'texto': 'Texto simulado de $accion.',
        'aviso': 'Texto generado por IA con fines educativos.',
        'aportes_usados': usados,
        'aportes_totales': accion == 'perspectivas' ? total : 0,
        'parcial': usados < (accion == 'perspectivas' ? total : 0),
        'truncado': false,
      });
    });
  }

  /// Estadísticas calculadas a partir de los datos del servidor falso (mismo contrato).
  void _rutasDeEstadisticas() {
    Map<String, Object> breve(Map<String, Object?> d) => {
      'id': d['id']!,
      'titulo': d['titulo']!,
      'categoria': d['categoria']!,
    };
    Map<String, Object?> debateDe(Object? id) =>
        debates.firstWhere((d) => d['id'] == id);
    final activos = debates.where((d) => d['estado'] == 'publicado');

    cuando('GET /estadisticas/comunidad', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      final conAportes = aportes.map((a) => a['debate_id']).toSet();
      final sin = [
        for (final d in activos)
          if (!conAportes.contains(d['id'])) d,
      ];
      final actividad =
          [
            for (final id in conAportes)
              {
                'debate': breve(debateDe(id)),
                'aportes': aportes.where((a) => a['debate_id'] == id).length,
                'ultimo_aporte_en':
                    (aportes
                            .where((a) => a['debate_id'] == id)
                            .map((a) => a['creado_en'] as String)
                            .toList()
                          ..sort())
                        .last,
              },
          ]..sort(
            (a, b) => (b['ultimo_aporte_en'] as String).compareTo(
              a['ultimo_aporte_en'] as String,
            ),
          );
      return RespuestaFalsa(200, {
        'total_debates': activos.length,
        'debates_archivados': debates.length - activos.length,
        'por_categoria': [
          for (final c in categoriasFalsas)
            {
              'categoria': c.$1,
              'etiqueta': c.$2,
              'total': activos.where((d) => d['categoria'] == c.$1).length,
            },
        ],
        'total_aportes': aportes.length,
        'participantes': aportes.map((a) => a['autor_id']).toSet().length,
        'sin_aportes': {
          'total': sin.length,
          'debates': [for (final d in sin.take(5)) breve(d)],
        },
        'actividad_reciente': actividad.take(5).toList(),
      });
    });

    cuando('GET /estadisticas/mias', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final mios = aportes.where((a) => a['autor_id'] == usuario).toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      int contar(String tipo) => mios.where((a) => a['tipo'] == tipo).length;
      return RespuestaFalsa(200, {
        'total_aportes': mios.length,
        'por_tipo': {
          'pregunta': contar('pregunta'),
          'argumento': contar('argumento'),
          'propuesta': contar('propuesta'),
        },
        'debates_participados': mios.map((a) => a['debate_id']).toSet().length,
        'mis_debates': {
          'borradores': borradores
              .where((b) => b['autor_id'] == usuario && b['debate_id'] == null)
              .length,
          'publicados': debates
              .where(
                (d) => d['autor_id'] == usuario && d['estado'] == 'publicado',
              )
              .length,
          'archivados': debates
              .where(
                (d) => d['autor_id'] == usuario && d['estado'] == 'archivado',
              )
              .length,
        },
        'aportes_recientes': [
          for (final a in mios.take(5))
            {
              'id': a['id'],
              'tipo': a['tipo'],
              'texto': a['texto'],
              'creado_en': a['creado_en'],
              'editado_en': a['editado_en'],
              'debate': breve(debateDe(a['debate_id'])),
            },
        ],
      });
    });
  }

  bool _archivado(int debateId) =>
      debates.any((d) => d['id'] == debateId && d['estado'] == 'archivado');

  String? _nombre(Object? usuarioId) => usuarioId == null
      ? null
      : usuarios.values.firstWhere((u) => u['id'] == usuarioId)['nombre']
            as String;

  Map<String, Object?> resumenDe(Map<String, Object?> d) => {
    for (final k in [
      'id',
      'titulo',
      'categoria',
      'resumen',
      'origen',
      'procedencia',
      'estado',
    ])
      k: d[k],
    'autor_nombre': _nombre(d['autor_id']),
  };

  Map<String, Object?> detalleDe(Map<String, Object?> d, int usuario) {
    final propio = d['autor_id'] == usuario;
    final nAportes = aportes.where((a) => a['debate_id'] == d['id']).length;
    return {
      ...resumenDe(d),
      'contexto': d['contexto'],
      'perspectivas': d['perspectivas'],
      'actualizado_en': d['actualizado_en'],
      'ambito': d['ambito'],
      'objetivo': d['objetivo'],
      'publicado_en': d['publicado_en'],
      'archivado_en': d['archivado_en'],
      'aportes': nAportes,
      'es_propio': propio,
      'editable':
          propio &&
          d['estado'] == 'publicado' &&
          nAportes == 0 &&
          d['con_participacion'] != true &&
          d['bloqueo_historico'] != true,
      'archivo_origen': d['archivo_origen'],
      'solicitud_archivo': propio ? _ultimaSolicitud(d['id'], usuario) : null,
      'version_actual': d['version_actual'],
      'motivo_bloqueo': d['con_participacion'] == true || nAportes > 0
          ? 'participacion'
          : d['bloqueo_historico'] == true
          ? 'historico'
          : null,
      'aclaraciones': [
        for (final a in aclaraciones)
          if (a['debate_id'] == d['id'])
            {
              'id': a['id'],
              'texto': a['texto'],
              'autor_nombre': _nombre(a['autor_id']),
              'creada_en': a['creada_en'],
            },
      ],
    };
  }

  bool _esAdmin(int usuario) => usuarios.values.any(
    (u) => u['id'] == usuario && u['rol'] == 'administrador',
  );

  Map<String, Object?> _solicitudPropia(Map<String, Object?> s) => {
    for (final k in [
      'id',
      'debate_id',
      'motivo',
      'estado',
      'creada_en',
      'resuelta_en',
    ])
      k: s[k],
    'respuesta': s['justificacion'],
  };

  Map<String, Object?>? _ultimaSolicitud(Object? debateId, int usuario) {
    final propias = solicitudes.where(
      (s) => s['debate_id'] == debateId && s['solicitante_id'] == usuario,
    );
    return propias.isEmpty ? null : _solicitudPropia(propias.last);
  }

  Map<String, Object?> _solicitudAdmin(Map<String, Object?> s) {
    final d = debates.firstWhere((d) => d['id'] == s['debate_id']);
    return {
      for (final k in [
        'id',
        'estado',
        'motivo',
        'creada_en',
        'resuelta_en',
        'justificacion',
      ])
        k: s[k],
      'solicitante_nombre': _nombre(s['solicitante_id']),
      'revisor_nombre': _nombre(s['revisor_id']),
      'debate': {
        'id': d['id'],
        'titulo': d['titulo'],
        'categoria': d['categoria'],
      },
      'debate_estado': d['estado'],
      'debate_resumen': d['resumen'],
      'debate_aportes': aportes.where((a) => a['debate_id'] == d['id']).length,
    };
  }

  /// Rutas de solicitudes de archivo y administración (mismas reglas que el backend).
  void _rutasDeSolicitudes() {
    const prohibido = RespuestaFalsa(403, {'detail': 'x'});
    const noEncontrada = RespuestaFalsa(404, {'detail': 'x'});
    String? motivoValido(RequestOptions p, String campo) {
      final datos = cuerpo(p);
      final valor = datos is Map ? (datos[campo] as String?)?.trim() : null;
      return valor == null || valor.length < 10 ? null : valor;
    }

    cuando('POST /debates/{id}/solicitud-archivo', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final d = debates.where((d) => d['id'] == idDe(p)).firstOrNull;
      if (d == null) return noEncontrada;
      if (d['autor_id'] != usuario) return prohibido;
      if (d['estado'] != 'publicado') return _conflicto;
      final motivo = motivoValido(p, 'motivo');
      if (motivo == null) return const RespuestaFalsa(422, {'detail': []});
      final pendiente = solicitudes
          .where((s) => s['debate_id'] == d['id'] && s['estado'] == 'pendiente')
          .firstOrNull;
      if (pendiente != null) {
        return RespuestaFalsa(200, _solicitudPropia(pendiente));
      }
      final nueva = <String, Object?>{
        'id': solicitudes.length + 1,
        'debate_id': d['id'],
        'solicitante_id': usuario,
        'motivo': motivo,
        'estado': 'pendiente',
        'creada_en': '2026-10-24T14:00:00Z',
        'resuelta_en': null,
        'revisor_id': null,
        'justificacion': null,
      };
      solicitudes.add(nueva);
      return RespuestaFalsa(201, _solicitudPropia(nueva));
    });
    cuando('POST /solicitudes-archivo/{id}/cancelar', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final s = solicitudes
          .where((s) => s['id'] == idDe(p) && s['solicitante_id'] == usuario)
          .firstOrNull;
      if (s == null) return noEncontrada;
      if (s['estado'] == 'pendiente') {
        s['estado'] = 'cancelada';
        s['resuelta_en'] = '2026-10-24T14:30:00Z';
      } else if (s['estado'] != 'cancelada') {
        return _conflicto;
      }
      return RespuestaFalsa(200, _solicitudPropia(s));
    });
    cuando('GET /admin/solicitudes-archivo', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      if (!_esAdmin(usuario)) return prohibido;
      return RespuestaFalsa(200, [
        for (final s in solicitudes)
          if (s['estado'] == 'pendiente') _solicitudAdmin(s),
      ]);
    });
    for (final accion in ['aprobar', 'rechazar']) {
      cuando('POST /admin/solicitudes-archivo/{id}/$accion', (p) {
        final usuario = usuarioDelToken(p);
        if (usuario == null) return _noAutorizado;
        if (!_esAdmin(usuario)) return prohibido;
        final s = solicitudes.where((s) => s['id'] == idDe(p)).firstOrNull;
        if (s == null) return noEncontrada;
        final justificacion = motivoValido(p, 'justificacion');
        if (justificacion == null) {
          return const RespuestaFalsa(422, {'detail': []});
        }
        if (s['estado'] != 'pendiente') return _conflicto;
        s
          ..['estado'] = accion == 'aprobar' ? 'aprobada' : 'rechazada'
          ..['revisor_id'] = usuario
          ..['justificacion'] = justificacion
          ..['resuelta_en'] = '2026-10-24T15:00:00Z';
        if (accion == 'aprobar') {
          debates.firstWhere((d) => d['id'] == s['debate_id'])
            ..['estado'] = 'archivado'
            ..['archivado_en'] = '2026-10-24T15:00:00Z'
            ..['archivo_origen'] = 'solicitud';
        }
        return RespuestaFalsa(200, _solicitudAdmin(s));
      });
    }
  }

  Map<String, Object?> _borradorSalida(Map<String, Object?> b) => {
    for (final e in b.entries)
      if (e.key != 'autor_id') e.key: e.value,
  };

  static const _camposContenido = [
    'categoria',
    'ambito',
    'titulo',
    'resumen',
    'contexto',
    'perspectivas',
    'objetivo',
  ];

  /// Validación mínima del contenido completo (los límites exactos se prueban en el backend).
  List<String> _faltantes(Map b) => [
    for (final c in _camposContenido)
      if (b[c] == null || (b[c] is String && (b[c] as String).trim().isEmpty))
        c,
    if ((b['perspectivas'] as List? ?? const []).length < 2) 'perspectivas',
  ];

  /// Rutas del Bloque 7B: borradores privados, publicación idempotente, edición y archivo.
  void _rutasDeBorradores() {
    Map<String, Object?>? propio(RequestOptions p, int usuario) => borradores
        .where((b) => b['id'] == idDe(p) && b['autor_id'] == usuario)
        .firstOrNull;
    const noEncontrado = RespuestaFalsa(404, {
      'detail': 'Borrador no encontrado.',
    });

    cuando('POST /borradores', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final b = <String, Object?>{
        for (final c in _camposContenido) c: null,
        'perspectivas': null,
        'paso': 1,
        'creado_en': '2026-10-24T10:00:00Z',
        'debate_id': null,
        ...(cuerpo(p) as Map).cast<String, Object?>(),
        'id': ++_siguienteBorrador,
        'autor_id': usuario,
        'actualizado_en':
            '2026-10-24T10:00:${_siguienteBorrador.toString().padLeft(2, '0')}Z',
      };
      borradores.add(b);
      return RespuestaFalsa(201, _borradorSalida(b));
    });
    cuando('GET /borradores/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final b = propio(p, usuario);
      return b == null ? noEncontrado : RespuestaFalsa(200, _borradorSalida(b));
    });
    cuando('PATCH /borradores/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final b = propio(p, usuario);
      if (b == null) return noEncontrado;
      if (b['debate_id'] != null) return _conflicto;
      b.addAll((cuerpo(p) as Map).cast<String, Object?>());
      return RespuestaFalsa(200, _borradorSalida(b));
    });
    cuando('DELETE /borradores/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final b = propio(p, usuario);
      if (b == null) return noEncontrado;
      if (b['debate_id'] != null) return _conflicto;
      borradores.remove(b);
      return const RespuestaFalsa(204);
    });
    cuando('POST /borradores/{id}/publicar', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final b = propio(p, usuario);
      if (b == null) return noEncontrado;
      final existente = b['debate_id'];
      if (existente != null) {
        return RespuestaFalsa(
          200,
          resumenDe(debates.firstWhere((d) => d['id'] == existente)),
        );
      }
      final faltan = _faltantes(b);
      if (faltan.isNotEmpty) {
        return RespuestaFalsa(422, {
          'detail': [
            for (final c in faltan)
              {
                'loc': ['body', c],
                'msg': 'x',
                'type': 'missing',
              },
          ],
        });
      }
      final d = <String, Object?>{
        for (final c in _camposContenido) c: b[c],
        'id': 100 + debates.length,
        'origen': 'Debate creado por una persona usuaria',
        'procedencia': 'usuario',
        'estado': 'publicado',
        'autor_id': usuario,
        'actualizado_en': '2026-10-24T12:00:00Z',
        'publicado_en': '2026-10-24T12:00:00Z',
        'archivado_en': null,
        'version_actual': 1,
        'con_participacion': false,
      };
      debates.add(d);
      versiones.add(_versionDe(d, 1, 'publicacion', autorId: usuario));
      b['debate_id'] = d['id'];
      return RespuestaFalsa(201, resumenDe(d));
    });
    cuando('PUT /debates/{id}', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final d = debates.where((d) => d['id'] == idDe(p)).firstOrNull;
      if (d == null) return const RespuestaFalsa(404, {'detail': 'x'});
      if (d['autor_id'] != usuario) {
        return const RespuestaFalsa(403, {'detail': 'x'});
      }
      final datos = (cuerpo(p) as Map).cast<String, Object?>();
      final motivo = (datos.remove('motivo') as String?)?.trim() ?? '';
      if (motivo.length < 10) return const RespuestaFalsa(422, {'detail': []});
      if (d['estado'] != 'publicado' ||
          d['con_participacion'] == true ||
          d['bloqueo_historico'] == true ||
          aportes.any((a) => a['debate_id'] == d['id'])) {
        return _conflicto;
      }
      final cambia = _camposContenido.any(
        (c) => jsonEncode(d[c]) != jsonEncode(datos[c]),
      );
      if (cambia) {
        d.addAll(datos);
        final numero = (d['version_actual'] as int) + 1;
        d['version_actual'] = numero;
        versiones.add(
          _versionDe(d, numero, 'edicion', autorId: usuario, motivo: motivo),
        );
      }
      return RespuestaFalsa(200, detalleDe(d, usuario));
    });
    Map<String, Object?> versionSalida(Map<String, Object?> v) {
      final anterior = versiones
          .where(
            (w) =>
                w['debate_id'] == v['debate_id'] &&
                w['numero'] == (v['numero'] as int) - 1,
          )
          .firstOrNull;
      final cambios = [
        if (anterior != null)
          for (final c in _camposContenido)
            if (jsonEncode(anterior[c]) != jsonEncode(v[c]))
              {'campo': c, 'antes': anterior[c], 'despues': v[c]},
      ];
      final debate = debates.firstWhere((d) => d['id'] == v['debate_id']);
      return {
        ...v,
        'autor_nombre': _nombre(v['autor_id']),
        'campos_cambiados': [for (final c in cambios) c['campo']],
        'es_actual': debate['version_actual'] == v['numero'],
        'cambios': cambios,
      };
    }

    cuando('GET /debates/{id}/versiones', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      final id = idDe(p);
      if (!debates.any((d) => d['id'] == id)) {
        return const RespuestaFalsa(404, {'detail': 'x'});
      }
      final propias = versiones.where((v) => v['debate_id'] == id).toList()
        ..sort((a, b) => (b['numero'] as int).compareTo(a['numero'] as int));
      return RespuestaFalsa(200, [for (final v in propias) versionSalida(v)]);
    });
    cuando('GET /debates/{id}/versiones/{id}', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      final numero = int.parse(p.path.split('/').last);
      final v = versiones
          .where((v) => v['debate_id'] == idDe(p) && v['numero'] == numero)
          .firstOrNull;
      if (v == null) return const RespuestaFalsa(404, {'detail': 'x'});
      return RespuestaFalsa(200, versionSalida(v));
    });
    cuando('POST /debates/{id}/aclaraciones', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      final d = debates.where((d) => d['id'] == idDe(p)).firstOrNull;
      if (d == null) return const RespuestaFalsa(404, {'detail': 'x'});
      if (d['autor_id'] != usuario) {
        return const RespuestaFalsa(403, {'detail': 'x'});
      }
      final texto = ((cuerpo(p) as Map)['texto'] as String? ?? '').trim();
      if (texto.length < 10 || texto.length > 1000) {
        return const RespuestaFalsa(422, {'detail': []});
      }
      if (d['estado'] != 'publicado') return _conflicto;
      final a = <String, Object?>{
        'id': aclaraciones.length + 1,
        'debate_id': d['id'],
        'autor_id': usuario,
        'texto': texto,
        'creada_en': '2026-10-24T16:00:00Z',
      };
      aclaraciones.add(a);
      return RespuestaFalsa(201, {
        'id': a['id'],
        'texto': texto,
        'autor_nombre': _nombre(usuario),
        'creada_en': a['creada_en'],
      });
    });
    // Archivo directo: solo administración (también 403 para la cuenta autora).
    cuando('POST /debates/{id}/archivar', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      if (!_esAdmin(usuario)) return const RespuestaFalsa(403, {'detail': 'x'});
      final d = debates.where((d) => d['id'] == idDe(p)).firstOrNull;
      if (d == null) return const RespuestaFalsa(404, {'detail': 'x'});
      final datos = cuerpo(p);
      final motivo = datos is Map ? (datos['motivo'] as String?) ?? '' : '';
      if (motivo.trim().length < 10) {
        return const RespuestaFalsa(422, {'detail': []});
      }
      if (d['estado'] != 'publicado') return _conflicto;
      d['estado'] = 'archivado';
      d['archivado_en'] = '2026-10-24T13:00:00Z';
      d['archivo_origen'] = 'administracion';
      for (final s in solicitudes) {
        if (s['debate_id'] == d['id'] && s['estado'] == 'pendiente') {
          s
            ..['estado'] = 'aprobada'
            ..['revisor_id'] = usuario
            ..['justificacion'] =
                'La administración archivó el debate directamente.';
        }
      }
      return RespuestaFalsa(200, detalleDe(d, usuario));
    });
    cuando('GET /mis-debates', (p) {
      final usuario = usuarioDelToken(p);
      if (usuario == null) return _noAutorizado;
      Map<String, Object?> mio(Map<String, Object?> d) {
        final n = aportes.where((a) => a['debate_id'] == d['id']).length;
        return {
          for (final k in [
            'id',
            'titulo',
            'categoria',
            'estado',
            'publicado_en',
            'archivado_en',
          ])
            k: d[k],
          'aportes': n,
          'editable': d['estado'] == 'publicado' && n == 0,
          'archivo_origen': d['archivo_origen'],
          'solicitud_archivo': _ultimaSolicitud(d['id'], usuario),
        };
      }

      final propios = debates.where((d) => d['autor_id'] == usuario);
      return RespuestaFalsa(200, {
        'borradores': [
          for (final b in borradores.reversed)
            if (b['autor_id'] == usuario && b['debate_id'] == null)
              _borradorSalida(b),
        ],
        'publicados': [
          for (final d in propios)
            if (d['estado'] == 'publicado') mio(d),
        ],
        'archivados': [
          for (final d in propios)
            if (d['estado'] == 'archivado') mio(d),
        ],
      });
    });
  }

  static const _conflicto = RespuestaFalsa(409, {'detail': 'Conflicto.'});

  static const _noAutorizado = RespuestaFalsa(401, {
    'detail': 'Sesión no válida o caducada. Inicia sesión de nuevo.',
  });
}

/// Simula que no hay red (Dio lo clasifica como connectionError).
Never sinRed(RequestOptions p) => throw DioException.connectionError(
  requestOptions: p,
  reason: 'sin red (simulado)',
);

/// Simula que el servidor no responde a tiempo.
Never sinRespuestaATiempo(RequestOptions p) =>
    throw DioException.receiveTimeout(
      timeout: const Duration(seconds: 15),
      requestOptions: p,
    );

const categoriasFalsas = [
  ('educacion', 'Educación'),
  ('ambiente', 'Ambiente'),
  ('movilidad', 'Movilidad'),
  ('cultura', 'Cultura'), // sin debates: sirve para el estado vacío
];

/// 20 debates sintéticos repartidos en tres categorías.
final debatesFalsos = [
  for (var i = 1; i <= 20; i++)
    {
      'id': i,
      'titulo': 'Debate sintético $i',
      'categoria': categoriasFalsas[i % 3].$1,
      'resumen': 'Resumen del debate sintético $i.',
      'origen': 'Material editorial de demostración',
      'contexto': 'Contexto del debate sintético $i.',
      'perspectivas': [
        {
          'titulo': 'Perspectiva A$i',
          'descripcion': 'Descripción de la perspectiva A.',
        },
        {
          'titulo': 'Perspectiva B$i',
          'descripcion': 'Descripción de la perspectiva B.',
        },
      ],
      'actualizado_en': '2026-10-22T00:00:00Z',
    },
];

/// Almacén de token en memoria que puede fallar a demanda.
class AlmacenFalso implements TokenStorage {
  AlmacenFalso([this.token]);

  String? token;
  bool fallarEscritura = false;
  int borrados = 0;

  @override
  Future<String?> leer() async => token;

  @override
  Future<void> guardar(String nuevo) async {
    if (fallarEscritura) throw Exception('Keystore no disponible (simulado)');
    token = nuevo;
  }

  @override
  Future<void> borrar() async {
    borrados++;
    token = null;
  }
}

/// Almacén de guardados en memoria, con fallos y esperas controlables.
class AlmacenGuardadosFalso implements AlmacenGuardados {
  final cajas = <int, Map<int, DebateGuardado>>{};
  bool fallarLectura = false;
  bool fallarEscritura = false;

  /// Si se asigna, la próxima escritura espera a que se complete.
  Completer<void>? esperaEscritura;
  Completer<void>? esperaLectura;

  @override
  Future<List<DebateGuardado>> leer(int usuarioId) async {
    final espera = esperaLectura;
    esperaLectura = null;
    if (espera != null) await espera.future;
    if (fallarLectura) throw const ErrorAlmacenLocal('leer');
    return [...?cajas[usuarioId]?.values];
  }

  @override
  Future<void> guardar(int usuarioId, DebateGuardado debate) async {
    final espera = esperaEscritura;
    esperaEscritura = null;
    if (espera != null) await espera.future;
    if (fallarEscritura) throw const ErrorAlmacenLocal('guardar');
    (cajas[usuarioId] ??= {})[debate.id] = debate;
  }

  @override
  Future<void> quitar(int usuarioId, int debateId) async {
    final espera = esperaEscritura;
    esperaEscritura = null;
    if (espera != null) await espera.future;
    if (fallarEscritura) throw const ErrorAlmacenLocal('quitar');
    cajas[usuarioId]?.remove(debateId);
  }
}

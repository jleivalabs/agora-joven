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
    _rutasPorDefecto();
    _rutasDeAportes();
    _rutaDelAsistente();
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
  };

  /// Aportes guardados en el servidor falso (con `autor_id`, que nunca se envía al cliente).
  final aportes = <Map<String, Object?>>[];
  int _siguienteAporte = 0;
  int _siguienteToken = 0;

  ApiClient cliente() =>
      ApiClient(baseUrl: 'http://servidor.falso', adaptador: this);

  /// Sustituye el manejador de una ruta, por ejemplo `cuando('GET /debates', ...)`.
  /// Las rutas con id usan `{id}`: `GET /debates/{id}`, `PATCH /aportes/{id}`.
  void cuando(String ruta, Manejador manejador) => _rutas[ruta] = manejador;

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
  }) {
    final aporte = <String, Object?>{
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
      });
    });
    cuando('GET /debates/categorias', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      return RespuestaFalsa(200, [
        for (final c in categoriasFalsas)
          {
            'categoria': c.$1,
            'etiqueta': c.$2,
            'total': debatesFalsos.where((d) => d['categoria'] == c.$1).length,
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
        for (final d in debatesFalsos)
          if (categoria == null || d['categoria'] == categoria)
            {
              for (final k in [
                'id',
                'titulo',
                'categoria',
                'resumen',
                'origen',
              ])
                k: d[k],
            },
      ]);
    });
    cuando('GET /debates/{id}', (p) {
      if (usuarioDelToken(p) == null) return _noAutorizado;
      final id = idDe(p);
      final d = debatesFalsos.where((d) => d['id'] == id);
      if (d.isEmpty) {
        return const RespuestaFalsa(404, {'detail': 'Debate no encontrado.'});
      }
      return RespuestaFalsa(200, d.first);
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
      final datos = cuerpo(p) as Map;
      final texto = (datos['texto'] as String).trim();
      if (texto.length < 10 || texto.length > 1000) {
        return const RespuestaFalsa(422, {'detail': []});
      }
      final a = sembrarAporte(
        autorId: usuario,
        debateId: idDe(p),
        tipo: datos['tipo'] as String,
        texto: texto,
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

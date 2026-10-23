import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_joven/data/api_client.dart';
import 'package:agora_joven/data/token_storage.dart';
import 'package:dio/dio.dart';

const emailAna = 'ana@example.com';
const passwordAna = 'clave-de-prueba-123';

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
  }

  final _rutas = <String, Manejador>{};
  final peticiones = <RequestOptions>[];
  final tokensValidos = <String, int>{'token-ana': 1};
  final usuarios = <String, Map<String, Object>>{
    emailAna: {
      'id': 1,
      'nombre': 'Ana',
      'email': emailAna,
      'password': passwordAna,
    },
  };
  int _siguienteToken = 0;

  ApiClient cliente() =>
      ApiClient(baseUrl: 'http://servidor.falso', adaptador: this);

  /// Sustituye el manejador de una ruta, por ejemplo `cuando('GET /debates', ...)`.
  /// Las rutas con id usan `{id}`: `GET /debates/{id}`.
  void cuando(String ruta, Manejador manejador) => _rutas[ruta] = manejador;

  int contar(String ruta) => peticiones.where((p) => _clave(p) == ruta).length;

  String _clave(RequestOptions p) {
    final ruta = p.path.replaceAll(RegExp(r'/\d+$'), '/{id}');
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
      jsonEncode(respuesta.cuerpo),
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
      final id = int.parse(p.path.split('/').last);
      final d = debatesFalsos.where((d) => d['id'] == id);
      if (d.isEmpty) {
        return const RespuestaFalsa(404, {'detail': 'Debate no encontrado.'});
      }
      return RespuestaFalsa(200, d.first);
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

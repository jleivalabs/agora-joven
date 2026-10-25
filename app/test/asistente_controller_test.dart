import 'dart:async';

import 'package:agora_joven/controllers/asistente_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/models/asistente.dart';
import 'package:agora_joven/repositories/asistente_repository.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

/// Asistente con servidor SIMULADO: ninguna prueba usa IA real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late SesionController sesion;
  late AsistenteController asistente;

  setUp(() async {
    Get.testMode = true;
    servidor = ServidorFalso();
    final cliente = servidor.cliente();
    sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
    asistente = AsistenteController(AsistenteRepository(cliente), sesion, 1);
    await sesion.iniciarSesion(emailAna, passwordAna);
  });
  tearDown(Get.reset);

  RespuestaFalsa generado(String accion) => RespuestaFalsa(200, {
    'debate_id': 1,
    'accion': accion,
    'estado': 'generado',
    'texto': 'Respuesta de $accion.',
    'aviso': 'IA',
    'aportes_usados': 0,
    'aportes_totales': 0,
    'parcial': false,
    'truncado': false,
  });

  test('explicar el contexto muestra el texto generado', () async {
    await asistente.consultar(AccionAsistente.contexto);

    expect(asistente.estado.value, EstadoAsistente.listo);
    expect(asistente.respuesta.value!.texto, 'Texto simulado de contexto.');
    expect(ServidorFalso.cuerpo(servidor.peticiones.last), {
      'accion': 'contexto',
    });
    expect(
      servidor.peticiones.last.receiveTimeout,
      const Duration(seconds: 40),
    );
  });

  test('perspectivas sin aportes: estado informativo, sin texto', () async {
    await asistente.consultar(AccionAsistente.perspectivas);

    expect(asistente.estado.value, EstadoAsistente.sinAportes);
    expect(asistente.respuesta.value!.texto, isNull);
  });

  test('perspectivas parciales: indica cuántos aportes se usaron', () async {
    for (var i = 0; i < 3; i++) {
      servidor.sembrarAporte(autorId: 2, texto: 'Aporte número $i con texto.');
    }
    await asistente.consultar(AccionAsistente.perspectivas);

    final r = asistente.respuesta.value!;
    expect(r.parcial, isTrue);
    expect((r.aportesUsados, r.aportesTotales), (2, 3));
  });

  test('errores con mensaje propio y reintento explícito', () async {
    final casos = {
      503: 'no está disponible',
      502: 'no pudo generar',
      429: 'límite de uso',
    };
    for (final caso in casos.entries) {
      servidor.cuando(
        'POST /asistente/debates/{id}',
        (_) => RespuestaFalsa(caso.key),
      );
      await asistente.consultar(AccionAsistente.contexto);
      expect(asistente.estado.value, EstadoAsistente.error);
      expect(
        asistente.error.value,
        contains(caso.value),
        reason: 'HTTP ${caso.key}',
      );
    }

    servidor.cuando('POST /asistente/debates/{id}', sinRed);
    await asistente.consultar(AccionAsistente.contexto);
    expect(asistente.error.value, contains('No se pudo conectar'));
    final antes = servidor.contar('POST /asistente/debates/{id}');

    servidor.cuando(
      'POST /asistente/debates/{id}',
      (_) => generado('contexto'),
    );
    await asistente.reintentar();
    expect(servidor.contar('POST /asistente/debates/{id}'), antes + 1);
    expect(asistente.estado.value, EstadoAsistente.listo);
  });

  test('no envía consultas duplicadas mientras hay una en curso', () async {
    final respuesta = Completer<RespuestaFalsa>();
    servidor.cuando('POST /asistente/debates/{id}', (_) => respuesta.future);

    final primera = asistente.consultar(AccionAsistente.contexto);
    final segunda = asistente.consultar(AccionAsistente.perspectivas);
    respuesta.complete(generado('contexto'));
    await Future.wait([primera, segunda]);

    expect(servidor.contar('POST /asistente/debates/{id}'), 1);
    expect(asistente.respuesta.value!.accion, AccionAsistente.contexto);
  });

  test('respuesta tardía tras cambiar de sesión se descarta', () async {
    final respuesta = Completer<RespuestaFalsa>();
    servidor.cuando('POST /asistente/debates/{id}', (_) => respuesta.future);

    final consulta = asistente.consultar(AccionAsistente.contexto);
    await sesion.cerrarSesion();
    await sesion.iniciarSesion(emailBeto, passwordAna);
    respuesta.complete(generado('contexto'));
    await consulta;

    expect(asistente.respuesta.value, isNull);
    expect(asistente.estado.value, isNot(EstadoAsistente.listo));
    expect(sesion.usuario.value!.nombre, 'Beto');
  });

  test('respuesta tardía tras cerrar la pantalla se descarta', () async {
    final respuesta = Completer<RespuestaFalsa>();
    servidor.cuando('POST /asistente/debates/{id}', (_) => respuesta.future);

    final consulta = asistente.consultar(AccionAsistente.contexto);
    asistente.onClose();
    respuesta.complete(const RespuestaFalsa(503));
    await consulta;

    expect(asistente.error.value, isNull);
    expect(asistente.respuesta.value, isNull);
  });

  test('un 401 cierra la sesión sin mostrar error del asistente', () async {
    servidor.tokensValidos.clear();

    await asistente.consultar(AccionAsistente.contexto);

    expect(sesion.estado.value, EstadoSesion.sinSesion);
    expect(asistente.estado.value, EstadoAsistente.cargando);
    expect(asistente.error.value, isNull);
  });

  test('una respuesta con forma inesperada es un error controlado', () async {
    servidor.cuando(
      'POST /asistente/debates/{id}',
      (_) => const RespuestaFalsa(200, {'estado': 'raro'}),
    );

    await asistente.consultar(AccionAsistente.contexto);

    expect(asistente.estado.value, EstadoAsistente.error);
    expect(asistente.error.value, contains('respuesta inesperada'));
  });
}

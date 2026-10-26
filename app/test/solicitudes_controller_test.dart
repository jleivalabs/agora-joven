import 'dart:async';

import 'package:agora_joven/controllers/admin_solicitudes_controller.dart';
import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/detalle_debate_controller.dart';
import 'package:agora_joven/controllers/mis_debates_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/borradores_repository.dart';
import 'package:agora_joven/repositories/debates_repository.dart';
import 'package:agora_joven/repositories/solicitudes_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

/// Solicitudes de archivo y administración: duplicados, conflictos y cambios de sesión.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late SesionController sesion;
  late SolicitudesRepository solicitudes;
  late DebatesRepository debates;

  setUp(() {
    Get.testMode = true;
    servidor = ServidorFalso();
    final cliente = servidor.cliente();
    sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
    solicitudes = SolicitudesRepository(cliente);
    debates = DebatesRepository(cliente);
    servidor.debates.add({
      ...servidor.debates.first,
      'id': 300,
      'procedencia': 'usuario',
      'autor_id': 1,
    });
  });
  tearDown(Get.reset);

  void sembrarPendiente() => servidor.solicitudes.add({
    'id': 1,
    'debate_id': 300,
    'solicitante_id': 1,
    'motivo': 'Motivo de la solicitud sembrada.',
    'estado': 'pendiente',
    'creada_en': '2026-10-24T14:00:00Z',
    'resuelta_en': null,
    'revisor_id': null,
    'justificacion': null,
  });

  Future<DetalleDebateController> detalleDeAna() async {
    await sesion.iniciarSesion(emailAna, passwordAna);
    final c = DetalleDebateController(
      debates,
      sesion,
      300,
      solicitudes: solicitudes,
    )..onInit();
    await pumpEventQueue();
    return c;
  }

  Future<AdminSolicitudesController> administracion() async {
    await sesion.iniciarSesion(emailRosa, passwordAna);
    final c = AdminSolicitudesController(solicitudes, sesion)..onInit();
    await pumpEventQueue();
    return c;
  }

  group('autor', () {
    test('solicitar dos veces seguidas envía una sola petición', () async {
      final c = await detalleDeAna();
      expect(c.esAdministrador, isFalse);

      final primera = c.solicitarArchivo('Motivo suficiente para archivar.');
      final segunda = c.solicitarArchivo('Motivo suficiente para archivar.');

      expect(
        await segunda,
        isNull,
      ); // ignorada mientras la primera está en curso
      expect(await primera, contains('Solicitud enviada'));
      expect(servidor.contar('POST /debates/{id}/solicitud-archivo'), 1);
      expect(c.debate.value!.solicitudArchivo!.pendiente, isTrue);
      expect(c.debate.value!.archivado, isFalse);
    });

    test(
      'el autor no puede archivar directamente: el servidor responde 403',
      () async {
        final c = await detalleDeAna();

        final mensaje = await c.archivarComoAdministracion(
          'Intento de archivo directo del autor.',
        );

        expect(mensaje, 'Esta acción está reservada a la administración.');
        expect(servidor.debates.last['estado'], 'publicado');
      },
    );

    test('cancelar una solicitud ya resuelta recarga el estado real', () async {
      sembrarPendiente();
      final c = await detalleDeAna();
      servidor.solicitudes.single['estado'] =
          'rechazada'; // otra persona la resolvió

      expect(await c.cancelarSolicitud(), 'La solicitud ya se había resuelto.');
      await pumpEventQueue();
      expect(c.debate.value!.solicitudArchivo!.estado.name, 'rechazada');
    });

    test('Mis debates cancela la solicitud una sola vez', () async {
      sembrarPendiente();
      await sesion.iniciarSesion(emailAna, passwordAna);
      final mis = MisDebatesController(
        debates,
        BorradoresRepository(servidor.cliente()),
        sesion,
        null,
        solicitudes,
      )..onInit();
      await pumpEventQueue();
      expect(
        mis.datos.value!.publicados.single.solicitudArchivo!.pendiente,
        isTrue,
      );

      final a = mis.cancelarSolicitud(1);
      final b = mis.cancelarSolicitud(1);
      expect(await b, isNull);
      expect(await a, 'Solicitud de archivo cancelada.');
      expect(servidor.contar('POST /solicitudes-archivo/{id}/cancelar'), 1);
      expect(
        mis.datos.value!.publicados.single.solicitudArchivo!.pendiente,
        isFalse,
      );
    });
  });

  group('administración', () {
    test(
      'lista pendientes y una resolución doble envía una sola petición',
      () async {
        sembrarPendiente();
        final c = await administracion();
        expect(c.pendientes.single.solicitanteNombre, 'Ana');

        final a = c.resolver(
          1,
          aprobar: true,
          justificacion: 'Justificación válida.',
        );
        final b = c.resolver(
          1,
          aprobar: false,
          justificacion: 'Justificación válida.',
        );

        expect(await b, isNull);
        expect((await a)!.$1, isTrue);
        expect(
          servidor.contar('POST /admin/solicitudes-archivo/{id}/aprobar'),
          1,
        );
        expect(
          servidor.contar('POST /admin/solicitudes-archivo/{id}/rechazar'),
          0,
        );
        expect(c.pendientes, isEmpty);
        expect(servidor.debates.last['estado'], 'archivado');
      },
    );

    test(
      'si otra persona ya la resolvió, avisa y actualiza la lista',
      () async {
        sembrarPendiente();
        final c = await administracion();
        servidor.solicitudes.single['estado'] = 'rechazada';

        final (resuelta, mensaje) = (await c.resolver(
          1,
          aprobar: true,
          justificacion: 'Justificación válida.',
        ))!;

        expect(resuelta, isTrue);
        expect(mensaje, contains('ya se había resuelto'));
        expect(c.pendientes, isEmpty);
        expect(servidor.debates.last['estado'], 'publicado');
      },
    );

    test(
      'una cuenta sin rol recibe el error de permisos del servidor',
      () async {
        await sesion.iniciarSesion(emailAna, passwordAna);
        final c = AdminSolicitudesController(solicitudes, sesion)..onInit();
        await pumpEventQueue();

        expect(c.estado.value, EstadoCarga.error);
        expect(c.error.value, 'Tu cuenta no tiene permisos de administración.');
      },
    );

    test('una lista tardía no se aplica tras cambiar de sesión', () async {
      sembrarPendiente();
      final respuesta = Completer<RespuestaFalsa>();
      servidor.cuando(
        'GET /admin/solicitudes-archivo',
        (_) => respuesta.future,
      );
      await sesion.iniciarSesion(emailRosa, passwordAna);
      final c = AdminSolicitudesController(solicitudes, sesion)..onInit();
      await pumpEventQueue();

      await sesion.cerrarSesion();
      await sesion.iniciarSesion(emailAna, passwordAna);
      respuesta.complete(
        RespuestaFalsa(200, [
          {
            'id': 1,
            'estado': 'pendiente',
            'motivo': 'x',
            'creada_en': '2026-10-24T14:00:00Z',
            'resuelta_en': null,
            'justificacion': null,
            'solicitante_nombre': 'Ana',
            'revisor_nombre': null,
            'debate': {'id': 300, 'titulo': 't', 'categoria': 'salud'},
            'debate_estado': 'publicado',
            'debate_resumen': 'r',
            'debate_aportes': 0,
          },
        ]),
      );
      await pumpEventQueue();

      expect(c.pendientes, isEmpty);
      expect(c.estado.value, EstadoCarga.cargando);
    });

    test('archivo directo de la administración con motivo', () async {
      await sesion.iniciarSesion(emailRosa, passwordAna);
      final c = DetalleDebateController(debates, sesion, 300)..onInit();
      await pumpEventQueue();
      expect(c.esAdministrador, isTrue);

      expect(
        await c.archivarComoAdministracion('Motivo interno del archivo.'),
        'Debate archivado. Sigue disponible para consulta.',
      );
      expect(c.debate.value!.archivado, isTrue);
      expect(c.debate.value!.archivoOrigen!.name, 'administracion');
    });
  });
}

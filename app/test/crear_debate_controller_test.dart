import 'dart:async';

import 'package:agora_joven/controllers/actividad_comunidad.dart';
import 'package:agora_joven/controllers/crear_debate_controller.dart';
import 'package:agora_joven/controllers/debates_controller.dart';
import 'package:agora_joven/controllers/mis_debates_controller.dart';
import 'package:agora_joven/controllers/sesion_controller.dart';
import 'package:agora_joven/models/debate.dart';
import 'package:agora_joven/repositories/auth_repository.dart';
import 'package:agora_joven/repositories/borradores_repository.dart';
import 'package:agora_joven/repositories/debates_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/servidor_falso.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ServidorFalso servidor;
  late SesionController sesion;
  late BorradoresRepository borradores;
  late DebatesRepository debates;

  setUp(() async {
    Get.testMode = true;
    servidor = ServidorFalso();
    final cliente = servidor.cliente();
    sesion = SesionController(AuthRepository(cliente, AlmacenFalso()));
    borradores = BorradoresRepository(cliente);
    debates = DebatesRepository(cliente);
    await sesion.iniciarSesion(emailAna, passwordAna);
  });
  tearDown(Get.reset);

  CrearDebateController nuevo({
    int? borradorId,
    DebateDetalle? editado,
    ActividadComunidad? actividad,
  }) => CrearDebateController(
    borradores,
    debates,
    sesion,
    borradorInicial: borradorId,
    debateEditado: editado,
    actividad: actividad,
  )..onInit();

  void completar(CrearDebateController c) {
    c
      ..cambiarCategoria('movilidad')
      ..cambiarAmbito('Estudiantes de la ciudad')
      ..cambiarTitulo('¿Debería ampliarse el horario del bus?')
      ..cambiarResumen(
        'Quienes estudian de noche tienen pocas opciones para volver.',
      )
      ..cambiarContexto(
        'El servicio termina antes que algunas clases nocturnas y hay quienes caminan '
        'largas distancias o pagan transporte privado para volver.',
      )
      ..cambiarPerspectiva(0, titulo: 'Ampliar el horario')
      ..cambiarPerspectiva(
        0,
        descripcion: 'Mejora la seguridad de quienes estudian.',
      )
      ..cambiarPerspectiva(1, titulo: 'Mantenerlo')
      ..cambiarPerspectiva(
        1,
        descripcion: 'Los recursos irían a otras rutas diurnas.',
      )
      ..cambiarObjetivo('Aclarar si conviene ampliar el horario y cómo.');
  }

  group('borrador', () {
    test(
      'un paso incompleto se guarda pero no avanza; los errores van al campo',
      () async {
        final c = nuevo();
        c.cambiarAmbito('Barrio norte');

        await c.siguiente();

        expect(c.paso.value, PasoCreacion.tema);
        expect(c.errores['categoria'], 'Elige una categoría.');
        expect(c.borradorId, isNotNull); // se creó el borrador incompleto
        expect(servidor.borradores.single['ambito'], 'Barrio norte');
        expect(servidor.borradores.single['autor_id'], 1);
      },
    );

    test(
      'avanzar guarda el paso y los datos; retroceder los conserva',
      () async {
        final c = nuevo();
        c
          ..cambiarCategoria('salud')
          ..cambiarAmbito('Colegios públicos');

        await c.siguiente();
        expect(c.paso.value, PasoCreacion.pregunta);
        expect(servidor.borradores.single['paso'], 2);

        c.anterior();
        expect(c.paso.value, PasoCreacion.tema);
        expect(c.ambito.value, 'Colegios públicos');
      },
    );

    test('retomar un borrador recupera campos y paso', () async {
      final primero = nuevo();
      completar(primero);
      await primero.siguiente(); // paso 2 guardado
      final id = primero.borradorId!;

      final retomado = nuevo(borradorId: id);
      await pumpEventQueue();

      expect(retomado.estado.value, EstadoCarga.listo);
      expect(retomado.paso.value, PasoCreacion.pregunta);
      expect(retomado.titulo.value, '¿Debería ampliarse el horario del bus?');
      expect(retomado.perspectivas.map((p) => p.titulo), [
        'Ampliar el horario',
        'Mantenerlo',
      ]);
      expect(retomado.haySinGuardar, isFalse);
    });

    test(
      'si guardar falla no avanza, conserva los datos y se puede reintentar',
      () async {
        final c = nuevo();
        c
          ..cambiarCategoria('salud')
          ..cambiarAmbito('Colegios públicos');
        final original = servidor.manejador('POST /borradores')!;
        servidor.cuando('POST /borradores', sinRed);

        await c.siguiente();

        expect(c.paso.value, PasoCreacion.tema);
        expect(
          c.errorGuardado.value,
          contains('No se pudo guardar el borrador'),
        );
        expect(c.ambito.value, 'Colegios públicos');
        expect(c.haySinGuardar, isTrue);
        expect(servidor.borradores, isEmpty);

        servidor.cuando('POST /borradores', original);
        expect(await c.guardar(), isTrue);
        expect(c.errorGuardado.value, isNull);
        expect(c.haySinGuardar, isFalse);
        expect(servidor.borradores.single['ambito'], 'Colegios públicos');
      },
    );

    test('perspectivas: mínimo 2, máximo 5', () {
      final c = nuevo();
      c.quitarPerspectiva(0);
      expect(c.perspectivas.length, 2);
      for (var i = 0; i < 5; i++) {
        c.agregarPerspectiva();
      }
      expect(c.perspectivas.length, 5);
      expect(c.idsPerspectivas.toSet().length, 5);
    });
  });

  group('publicar', () {
    test('incompleto: no llama al servidor y marca los pasos', () async {
      final c = nuevo();
      c.cambiarCategoria('salud');

      expect(await c.publicar(), isNull);

      expect(c.errorPublicar.value, contains('Revisa los pasos marcados'));
      expect(c.pasosConErrores(c.errores), contains(PasoCreacion.pregunta));
      expect(servidor.contar('POST /borradores/{id}/publicar'), 0);
    });

    test('válido: publica el mismo borrador y avisa a la comunidad', () async {
      final actividad = ActividadComunidad();
      final c = nuevo(actividad: actividad);
      completar(c);

      final debate = await c.publicar();

      expect(debate, isNotNull);
      expect(debate!.esDeUsuario, isTrue);
      expect(debate.autorNombre, 'Ana');
      expect(servidor.borradores.single['debate_id'], debate.id);
      expect(actividad.cambios.value, greaterThan(0));
    });

    test('si se pierde la respuesta, repetir no duplica el debate', () async {
      final c = nuevo();
      completar(c);
      var intentos = 0;
      final real = servidor;
      servidor.cuando('POST /borradores/{id}/publicar', (p) {
        intentos++;
        // El servidor publica, pero la primera respuesta no llega a la app.
        final b = real.borradores.single;
        if (b['debate_id'] == null) {
          real.debates.add({
            'id': 500,
            'titulo': b['titulo'],
            'categoria': b['categoria'],
            'resumen': b['resumen'],
            'origen': 'Debate creado por una persona usuaria',
            'procedencia': 'usuario',
            'estado': 'publicado',
            'autor_id': 1,
          });
          b['debate_id'] = 500;
        }
        if (intentos == 1) sinRespuestaATiempo(p);
        return RespuestaFalsa(200, real.resumenDe(real.debates.last));
      });

      expect(await c.publicar(), isNull);
      expect(c.errorPublicar.value, contains('Tu borrador está guardado'));
      final segundo = await c.publicar();

      expect(segundo!.id, 500);
      expect(
        real.debates.where((d) => d['procedencia'] == 'usuario').length,
        1,
      );
    });

    test(
      'una publicación tardía no se aplica tras cambiar de sesión',
      () async {
        final c = nuevo();
        completar(c);
        await c.guardar();
        final respuesta = Completer<RespuestaFalsa>();
        servidor.cuando(
          'POST /borradores/{id}/publicar',
          (_) => respuesta.future,
        );

        final publicacion = c.publicar();
        await pumpEventQueue();
        await sesion.cerrarSesion();
        await sesion.iniciarSesion(emailBeto, passwordAna);
        respuesta.complete(
          const RespuestaFalsa(201, {
            'id': 900,
            'titulo': 'x',
            'categoria': 'salud',
            'resumen': 'x',
            'origen': 'x',
          }),
        );

        expect(await publicacion, isNull);
        expect(sesion.usuario.value!.nombre, 'Beto');
      },
    );
  });

  group('edición y Mis debates', () {
    Future<DebateDetalle> publicado() async {
      final c = nuevo();
      completar(c);
      final d = await c.publicar();
      return debates.detalle('token-ana', d!.id);
    }

    test('editar sin aportes guarda; con aportes queda bloqueado', () async {
      final detalle = await publicado();
      final c = nuevo(editado: detalle);
      expect(c.modoEdicion, isTrue);
      c.cambiarTitulo('¿Debería ampliarse el horario del bus en exámenes?');

      final editado = await c.guardarEdicion('Motivo de la edición de prueba.');
      expect(
        editado!.titulo,
        '¿Debería ampliarse el horario del bus en exámenes?',
      );

      servidor.sembrarAporte(autorId: 2, debateId: detalle.id);
      c.cambiarTitulo('¿Otro título largo para el mismo debate?');
      expect(await c.guardarEdicion('Motivo de la edición de prueba.'), isNull);
      expect(c.errorPublicar.value, contains('bloqueado'));
    });

    test(
      'Mis debates separa borradores, publicados y archivados de la cuenta',
      () async {
        final detalle = await publicado();
        final pendiente = nuevo()..cambiarAmbito('Borrador pendiente');
        await pendiente.guardar();
        servidor.tokensValidos['token-rosa'] = 3; // administración
        await debates.archivar(
          'token-rosa',
          detalle.id,
          'Archivo de prueba por la administración.',
        );
        servidor.borradores.add({
          ...servidor.borradores.last,
          'id': 77,
          'autor_id': 2,
        });

        final mis = MisDebatesController(debates, borradores, sesion)..onInit();
        await pumpEventQueue();

        final datos = mis.datos.value!;
        expect(datos.borradores.map((b) => b.ambito), ['Borrador pendiente']);
        expect(datos.publicados, isEmpty);
        expect(datos.archivados.single.id, detalle.id);

        expect(
          await mis.eliminarBorrador(datos.borradores.single.id),
          'Borrador eliminado.',
        );
        expect(mis.datos.value!.borradores, isEmpty);
      },
    );
  });
}

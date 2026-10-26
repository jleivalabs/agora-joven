import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/borrador.dart';
import '../models/referencia.dart';
import '../repositories/borradores_repository.dart';
import '../repositories/investigacion_repository.dart';
import '../utils/mensajes_error.dart';
import 'crear_debate_controller.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Investigación asistida del borrador abierto en el asistente de creación (7C).
///
/// - Cada consulta la inicia la persona con un botón; nunca al escribir ni al cambiar de paso.
/// - Una operación a la vez ([ocupado]); un segundo envío se ignora.
/// - Las respuestas de otra sesión ([SesionController.ejecutar]), de otro borrador o de una
///   pantalla cerrada se descartan.
/// - Si el borrador cambia mientras llega la redacción, se marca como basada en el texto
///   anterior y no se aplica nada automáticamente.
class InvestigacionController extends GetxController {
  InvestigacionController(
    this._repositorio,
    this._borradores,
    this._sesion,
    this._crear,
  );

  final InvestigacionRepository _repositorio;
  final BorradoresRepository _borradores;
  final SesionController _sesion;
  final CrearDebateController _crear;

  final estadoServicio = Rxn<EstadoInvestigacion>();
  final carga = EstadoCarga.cargando.obs;
  final errorCarga = RxnString();

  /// Operación en curso: `buscar`, `redactar`, `doi:<doi>` o `sugerencia:<id>`.
  final ocupado = RxnString();

  final busqueda = Rxn<BusquedaReferencias>();
  final errorBusqueda = RxnString();
  final referencias = <Referencia>[].obs;
  final evidencias = <Evidencia>[].obs;
  final redaccion = Rxn<Redaccion>();
  final errorRedaccion = RxnString();

  /// La redacción recibida se pidió con un texto que ya cambió en pantalla.
  final basadaEnTextoAnterior = false.obs;

  /// Último mensaje para la persona (resultado de una acción).
  final mensaje = RxnString();

  bool _activo = true;

  @override
  void onInit() {
    super.onInit();
    // Después de la construcción en curso: cargar puede guardar el borrador y eso actualiza
    // observables de otras pantallas.
    Future.microtask(cargar);
  }

  @override
  void onClose() {
    _activo = false;
    super.onClose();
  }

  bool get redaccionDesactualizada =>
      basadaEnTextoAnterior.value || (redaccion.value?.desactualizada ?? false);

  /// Texto que se enviaría a Crossref (para mostrarlo antes de consultar).
  String get textoBusqueda => [
    _crear.titulo.value.trim(),
    _crear.ambito.value.trim(),
  ].where((t) => t.isNotEmpty).join(' ');

  Future<void> cargar() async {
    carga.value = EstadoCarga.cargando;
    errorCarga.value = null;
    try {
      if (!await _asegurarGuardado()) {
        if (!_activo) return;
        errorCarga.value =
            'Guarda el borrador para usar la investigación. ${_crear.errorGuardado.value ?? ''}';
        carga.value = EstadoCarga.error;
        return;
      }
      final id = _crear.borradorId!;
      final estado = await _sesion.ejecutar(_repositorio.estado);
      final borrador = await _sesion.ejecutar(
        (t) => _borradores.obtener(t, id),
      );
      if (!_vigente(id)) return;
      estadoServicio.value = estado;
      _aplicar(borrador);
      carga.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo) return;
      errorCarga.value = mensajeDeError(e);
      carga.value = EstadoCarga.error;
    }
  }

  Future<void> buscar() => _operacion('buscar', (id) async {
    errorBusqueda.value = null;
    try {
      final resultado = await _sesion.ejecutar(
        (t) => _repositorio.buscar(t, id),
      );
      if (!_vigente(id)) return;
      busqueda.value = resultado;
    } on ApiException catch (e) {
      if (!_vigente(id)) return;
      errorBusqueda.value = _mensaje(e, 'No se pudo buscar en Crossref.');
    }
  });

  Future<void> agregar(Referencia r) => _operacion('doi:${r.doi}', (id) async {
    try {
      final b = await _sesion.ejecutar(
        (t) => _repositorio.agregar(t, id, r.doi),
      );
      if (!_vigente(id)) return;
      _aplicar(b);
      mensaje.value = 'Referencia añadida al borrador.';
    } on ApiException catch (e) {
      if (!_vigente(id)) return;
      mensaje.value = _mensaje(e, 'No se pudo añadir la referencia.');
    }
  });

  Future<void> quitar(Referencia r) => _operacion('doi:${r.doi}', (id) async {
    try {
      final b = await _sesion.ejecutar(
        (t) => _repositorio.quitar(t, id, r.doi),
      );
      if (!_vigente(id)) return;
      _aplicar(b);
      mensaje.value = 'Referencia quitada del borrador.';
    } on ApiException catch (e) {
      if (!_vigente(id)) return;
      mensaje.value = _mensaje(e, 'No se pudo quitar la referencia.');
    }
  });

  Future<void> redactar() => _operacion('redactar', (id) async {
    errorRedaccion.value = null;
    final firma = _crear.firmaContenido;
    try {
      final b = await _sesion.ejecutar((t) => _repositorio.redactar(t, id));
      if (!_vigente(id)) return;
      _aplicar(b);
      basadaEnTextoAnterior.value = firma != _crear.firmaContenido;
    } on ApiException catch (e) {
      if (!_vigente(id)) return;
      errorRedaccion.value = _mensaje(e, 'No se pudo obtener la redacción.');
    }
  });

  /// Acepta una sugerencia ya revisada (y confirmada en pantalla). Para el contexto se envía el
  /// valor que la persona vio: si cambió, el servidor no lo sobrescribe.
  Future<void> aceptar(
    SugerenciaIA s, {
    required String modo,
    required String valorVisto,
    String? texto,
    String? titulo,
    String? descripcion,
  }) => _operacion('sugerencia:${s.id}', (id) async {
    try {
      final b = await _sesion.ejecutar(
        (t) => _repositorio.aceptar(
          t,
          id,
          s.id,
          modo: modo,
          valorAnterior: valorVisto,
          texto: texto,
          titulo: titulo,
          descripcion: descripcion,
        ),
      );
      if (!_vigente(id)) return;
      _crear.sincronizarDesdeServidor(b);
      _aplicar(b);
      mensaje.value = 'Sugerencia aplicada a tu borrador.';
    } on ApiException catch (e) {
      if (!_vigente(id)) return;
      mensaje.value = _mensaje(e, 'No se pudo aplicar la sugerencia.');
      if (e.codigoDetalle == 'campo_cambiado') await _recargarSinBloquear(id);
    }
  });

  Future<void> descartar(SugerenciaIA s) =>
      _operacion('sugerencia:${s.id}', (id) async {
        try {
          final b = await _sesion.ejecutar(
            (t) => _repositorio.descartar(t, id, s.id),
          );
          if (!_vigente(id)) return;
          _aplicar(b);
        } on ApiException catch (e) {
          if (!_vigente(id)) return;
          mensaje.value = _mensaje(e, 'No se pudo descartar la sugerencia.');
        }
      });

  // --- Internos --------------------------------------------------------------------------------

  Future<void> _operacion(
    String clave,
    Future<void> Function(int id) accion,
  ) async {
    if (ocupado.value != null) return; // evita envíos duplicados
    ocupado.value = clave;
    mensaje.value = null;
    try {
      if (!await _asegurarGuardado()) {
        if (_activo) {
          mensaje.value =
              'Guarda el borrador antes de continuar. ${_crear.errorGuardado.value ?? ''}';
        }
        return;
      }
      await accion(_crear.borradorId!);
    } on SesionObsoleta {
      return;
    } finally {
      if (_activo) ocupado.value = null;
    }
  }

  /// El servidor trabaja con el borrador guardado: se guarda antes si hay cambios locales.
  Future<bool> _asegurarGuardado() async {
    if (_crear.borradorId != null && !_crear.haySinGuardar) return true;
    return _crear.guardar();
  }

  bool _vigente(int borradorId) => _activo && _crear.borradorId == borradorId;

  Future<void> _recargarSinBloquear(int id) async {
    try {
      final b = await _sesion.ejecutar((t) => _borradores.obtener(t, id));
      if (!_vigente(id)) return;
      _crear.sincronizarDesdeServidor(b);
      _aplicar(b);
    } on SesionObsoleta {
      return;
    } on ApiException {
      return;
    }
  }

  void _aplicar(Borrador b) {
    referencias.assignAll(b.referencias);
    evidencias.assignAll(b.evidencias);
    redaccion.value = b.redaccion;
    if (b.redaccion == null) basadaEnTextoAnterior.value = false;
  }

  String _mensaje(ApiException e, String generico) => switch (e.codigoDetalle) {
    'busqueda_no_configurada' =>
      'La búsqueda de referencias no está configurada en este servidor.',
    'redaccion_desactivada' =>
      'La redacción con IA está desactivada en este servidor.',
    'limite_cuenta' =>
      'Alcanzaste el máximo de consultas por hora. Inténtalo más tarde.',
    'en_curso' => 'Ya hay una consulta en curso para tu cuenta.',
    'proveedor_ocupado' =>
      'El servicio está ocupado. Inténtalo de nuevo en unos segundos.',
    'cuota_proveedor' =>
      'El servicio externo limitó las consultas. Inténtalo más tarde.',
    'proveedor_no_disponible' => 'No se pudo contactar con el servicio externo. Revisa la conexión y reintenta.',
    'respuesta_no_valida' =>
      'El servicio devolvió una respuesta no válida. Reintenta.',
    'doi_no_encontrado' => 'Crossref no tiene una obra válida con ese DOI.',
    'limite_referencias' =>
      'Alcanzaste el máximo de ${estadoServicio.value?.maxReferencias ?? 8} referencias.',
    'campo_cambiado' =>
      'El campo cambió desde que revisaste la sugerencia. Revísala de nuevo.',
    'sin_espacio' => 'No cabe: supera el límite del campo.',
    'falta_pregunta' => 'Escribe primero la pregunta del debate.',
    'ya_publicado' => 'Este borrador ya se publicó.',
    _ => '$generico ${mensajeDeError(e)}',
  };
}

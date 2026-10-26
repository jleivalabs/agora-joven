import 'package:get/get.dart';

import '../data/api_exception.dart';
import '../models/borrador.dart';
import '../models/debate.dart';
import '../repositories/borradores_repository.dart';
import '../repositories/debates_repository.dart';
import '../utils/mensajes_error.dart';
import 'actividad_comunidad.dart';
import 'debates_controller.dart';
import 'sesion_controller.dart';

/// Pasos del asistente de creación. El orden es el del formulario.
enum PasoCreacion {
  tema('Tema'),
  pregunta('Pregunta'),
  contexto('Contexto'),
  perspectivas('Perspectivas'),
  objetivo('Objetivo'),
  revision('Revisión');

  const PasoCreacion(this.titulo);

  final String titulo;

  int get numero => index + 1;
}

/// Campo → paso donde se escribe (para llevar los errores al sitio correcto).
const _pasoDeCampo = {
  'categoria': PasoCreacion.tema,
  'ambito': PasoCreacion.tema,
  'titulo': PasoCreacion.pregunta,
  'resumen': PasoCreacion.contexto,
  'contexto': PasoCreacion.contexto,
  'perspectivas': PasoCreacion.perspectivas,
  'objetivo': PasoCreacion.objetivo,
};

/// Asistente para crear un debate (nuevo o desde un borrador) o editar uno propio publicado.
///
/// - Los borradores se guardan en el servidor al avanzar y con "Guardar y salir"; pueden estar
///   incompletos. Si guardar falla, no se avanza ni se sale: se muestra el error y se reintenta.
/// - La validación completa ocurre al publicar (y el servidor vuelve a validar).
/// - Todo pasa por [SesionController.ejecutar]; al cerrarse la pantalla ([_activo]) las respuestas
///   tardías no se aplican.
class CrearDebateController extends GetxController {
  CrearDebateController(
    this._borradores,
    this._debates,
    this._sesion, {
    this.borradorInicial,
    this.debateEditado,
    this.actividad,
  });

  final BorradoresRepository _borradores;
  final DebatesRepository _debates;
  final SesionController _sesion;

  /// Si no es null, el asistente edita este debate publicado en lugar de un borrador.
  final DebateDetalle? debateEditado;
  final ActividadComunidad? actividad;

  /// Borrador a retomar (null para empezar uno nuevo).
  final int? borradorInicial;
  late int? _borradorId = borradorInicial;
  int? get borradorId => _borradorId;
  bool get modoEdicion => debateEditado != null;

  final paso = PasoCreacion.tema.obs;
  final categoria = RxnString();
  final ambito = ''.obs;
  final titulo = ''.obs;
  final resumen = ''.obs;
  final contexto = ''.obs;
  final objetivo = ''.obs;
  final perspectivas = <PerspectivaBorrador>[
    const PerspectivaBorrador(),
    const PerspectivaBorrador(),
  ].obs;

  /// Identificadores estables de cada perspectiva en pantalla (para conservar el cursor al
  /// escribir y no mezclar campos al quitar una del medio).
  final idsPerspectivas = <int>[0, 1].obs;
  int _siguienteId = 2;

  void _reiniciarIds() {
    idsPerspectivas.assignAll([
      for (var i = 0; i < perspectivas.length; i++) i,
    ]);
    _siguienteId = perspectivas.length;
  }

  /// Carga del borrador al retomarlo.
  final estado = EstadoCarga.listo.obs;
  final errorCarga = RxnString();

  final guardando = false.obs;
  final errorGuardado = RxnString();
  final publicando = false.obs;
  final errorPublicar = RxnString();

  /// Errores por campo, mostrados junto a cada campo ('perspectiva.0.titulo', 'perspectivas'…).
  final errores = <String, String>{}.obs;

  bool _sucio = false;
  bool _activo = true;

  /// El último guardado falló porque el borrador ya estaba publicado (409).
  bool _yaPublicado = false;

  /// Hay cambios que todavía no se guardaron en el servidor.
  bool get haySinGuardar => _sucio;

  @override
  void onInit() {
    super.onInit();
    final debate = debateEditado;
    if (debate != null) {
      categoria.value = debate.categoria;
      ambito.value = debate.ambito ?? '';
      titulo.value = debate.titulo;
      resumen.value = debate.resumen;
      contexto.value = debate.contexto;
      objetivo.value = debate.objetivo ?? '';
      perspectivas.assignAll([
        for (final p in debate.perspectivas)
          PerspectivaBorrador(titulo: p.titulo, descripcion: p.descripcion),
      ]);
      _reiniciarIds();
    } else if (_borradorId != null) {
      cargar();
    }
  }

  @override
  void onClose() {
    _activo = false;
    super.onClose();
  }

  Future<void> cargar() async {
    final id = _borradorId;
    if (id == null) return;
    estado.value = EstadoCarga.cargando;
    errorCarga.value = null;
    try {
      final b = await _sesion.ejecutar((t) => _borradores.obtener(t, id));
      if (!_activo) return;
      categoria.value = b.categoria;
      ambito.value = b.ambito ?? '';
      titulo.value = b.titulo ?? '';
      resumen.value = b.resumen ?? '';
      contexto.value = b.contexto ?? '';
      objetivo.value = b.objetivo ?? '';
      perspectivas.assignAll([
        ...b.perspectivas,
        for (
          var i = b.perspectivas.length;
          i < LimitesDebate.minPerspectivas;
          i++
        )
          const PerspectivaBorrador(),
      ]);
      _reiniciarIds();
      paso.value = PasoCreacion.values[(b.paso - 1).clamp(0, 5)];
      _sucio = false;
      estado.value = EstadoCarga.listo;
    } on SesionObsoleta {
      return;
    } on ApiException catch (e) {
      if (!_activo) return;
      errorCarga.value = e.tipo == TipoError.noEncontrado
          ? 'Este borrador ya no existe.'
          : mensajeDeError(e);
      estado.value = EstadoCarga.error;
    }
  }

  // --- Cambios ------------------------------------------------------------------------------

  void cambiarCategoria(String? valor) => _cambio('categoria', () {
    categoria.value = valor;
  });
  void cambiarAmbito(String v) => _cambio('ambito', () => ambito.value = v);
  void cambiarTitulo(String v) => _cambio('titulo', () => titulo.value = v);
  void cambiarResumen(String v) => _cambio('resumen', () => resumen.value = v);
  void cambiarContexto(String v) =>
      _cambio('contexto', () => contexto.value = v);
  void cambiarObjetivo(String v) =>
      _cambio('objetivo', () => objetivo.value = v);

  void cambiarPerspectiva(int i, {String? titulo, String? descripcion}) {
    final actual = perspectivas[i];
    perspectivas[i] = PerspectivaBorrador(
      titulo: titulo ?? actual.titulo,
      descripcion: descripcion ?? actual.descripcion,
    );
    _sucio = true;
    errores
      ..remove('perspectivas')
      ..remove('perspectiva.$i.${titulo != null ? 'titulo' : 'descripcion'}');
  }

  void agregarPerspectiva() {
    if (perspectivas.length >= LimitesDebate.maxPerspectivas) return;
    perspectivas.add(const PerspectivaBorrador());
    idsPerspectivas.add(_siguienteId++);
    _sucio = true;
    errores.remove('perspectivas');
  }

  void quitarPerspectiva(int i) {
    if (perspectivas.length <= LimitesDebate.minPerspectivas) return;
    perspectivas.removeAt(i);
    idsPerspectivas.removeAt(i);
    _sucio = true;
    errores.removeWhere((k, _) => k.startsWith('perspectiva'));
  }

  void _cambio(String campo, void Function() aplicar) {
    aplicar();
    _sucio = true;
    errores.remove(campo);
  }

  // --- Validación (mismos límites que el servidor) -------------------------------------------

  static String? _longitud(String valor, (int, int) limites, String vacio) {
    final largo = valor.trim().length;
    if (largo == 0) return vacio;
    if (largo < limites.$1) return 'Escribe al menos ${limites.$1} caracteres.';
    if (largo > limites.$2) return 'Máximo ${limites.$2} caracteres.';
    return null;
  }

  Map<String, String> validarPaso(PasoCreacion p) {
    final e = <String, String>{};
    void poner(String campo, String? mensaje) {
      if (mensaje != null) e[campo] = mensaje;
    }

    switch (p) {
      case PasoCreacion.tema:
        if (categoria.value == null) e['categoria'] = 'Elige una categoría.';
        poner(
          'ambito',
          _longitud(
            ambito.value,
            LimitesDebate.ambito,
            'Indica a quién afecta.',
          ),
        );
      case PasoCreacion.pregunta:
        poner(
          'titulo',
          _longitud(titulo.value, LimitesDebate.titulo, 'Escribe la pregunta.'),
        );
      case PasoCreacion.contexto:
        poner(
          'resumen',
          _longitud(
            resumen.value,
            LimitesDebate.resumen,
            'Escribe un resumen.',
          ),
        );
        poner(
          'contexto',
          _longitud(
            contexto.value,
            LimitesDebate.contexto,
            'Describe el problema.',
          ),
        );
      case PasoCreacion.perspectivas:
        if (perspectivas.length < LimitesDebate.minPerspectivas) {
          e['perspectivas'] =
              'Añade al menos ${LimitesDebate.minPerspectivas} perspectivas.';
        }
        for (var i = 0; i < perspectivas.length; i++) {
          poner(
            'perspectiva.$i.titulo',
            _longitud(
              perspectivas[i].titulo,
              LimitesDebate.perspectivaTitulo,
              'Ponle un título.',
            ),
          );
          poner(
            'perspectiva.$i.descripcion',
            _longitud(
              perspectivas[i].descripcion,
              LimitesDebate.perspectivaDescripcion,
              'Explica esta perspectiva.',
            ),
          );
        }
        final titulos = [
          for (final p in perspectivas) p.titulo.trim().toLowerCase(),
        ];
        if (titulos.toSet().length != titulos.length) {
          e['perspectivas'] = 'Las perspectivas deben tener títulos distintos.';
        }
      case PasoCreacion.objetivo:
        poner(
          'objetivo',
          _longitud(
            objetivo.value,
            LimitesDebate.objetivo,
            'Indica qué se busca aclarar o decidir.',
          ),
        );
      case PasoCreacion.revision:
        break;
    }
    return e;
  }

  Map<String, String> validarTodo() => {
    for (final p in PasoCreacion.values) ...validarPaso(p),
  };

  /// Pasos que tienen algún error (para la revisión).
  List<PasoCreacion> pasosConErrores(Map<String, String> e) => [
    for (final p in PasoCreacion.values)
      if (e.keys.any(
        (k) =>
            (_pasoDeCampo[k.startsWith('perspectiva') ? 'perspectivas' : k]) ==
            p,
      ))
        p,
  ];

  // --- Navegación y guardado -----------------------------------------------------------------

  String? _texto(String v) => v.trim().isEmpty ? null : v.trim();

  Map<String, Object?> _contenido() => {
    'categoria': categoria.value,
    'ambito': _texto(ambito.value),
    'titulo': _texto(titulo.value),
    'resumen': _texto(resumen.value),
    'contexto': _texto(contexto.value),
    'perspectivas': [
      for (final p in perspectivas)
        {'titulo': p.titulo.trim(), 'descripcion': p.descripcion.trim()},
    ],
    'objetivo': _texto(objetivo.value),
  };

  /// Guarda el borrador en el servidor (lo crea la primera vez). En modo edición no hay borrador.
  /// Devuelve false si no se pudo guardar; los datos siguen en pantalla para reintentar.
  Future<bool> guardar() async {
    if (modoEdicion) return true;
    if (guardando.value) return false;
    guardando.value = true;
    errorGuardado.value = null;
    _yaPublicado = false;
    final valores = {..._contenido(), 'paso': paso.value.numero};
    try {
      final id = _borradorId;
      final guardado = await _sesion.ejecutar(
        (t) => id == null
            ? _borradores.crear(t, valores)
            : _borradores.actualizar(t, id, valores),
      );
      if (!_activo) return false;
      _borradorId = guardado.id;
      _sucio = false;
      actividad?.avisar();
      return true;
    } on SesionObsoleta {
      return false;
    } on ApiException catch (e) {
      if (!_activo) return false;
      _yaPublicado = e.tipo == TipoError.conflicto;
      errorGuardado.value = _yaPublicado
          ? 'Este borrador ya se publicó. Ábrelo desde Mis debates.'
          : 'No se pudo guardar el borrador. ${mensajeDeError(e)} Tus datos siguen aquí.';
      return false;
    } finally {
      if (_activo) guardando.value = false;
    }
  }

  /// Avanza si el paso actual es válido. Guarda siempre lo escrito (aunque esté incompleto).
  Future<void> siguiente() async {
    final actual = paso.value;
    final e = validarPaso(actual);
    if (e.isNotEmpty) {
      errores.addAll(e);
      await guardar();
      return;
    }
    if (actual == PasoCreacion.revision) return;
    paso.value = PasoCreacion.values[actual.index + 1];
    _sucio = true;
    if (!await guardar()) paso.value = actual; // no se avanza sin guardar
  }

  void anterior() {
    if (paso.value.index == 0) return;
    paso.value = PasoCreacion.values[paso.value.index - 1];
    _sucio = true;
  }

  void irA(PasoCreacion destino) {
    paso.value = destino;
    _sucio = true;
  }

  // --- Publicar o guardar la edición ---------------------------------------------------------

  bool _validarParaEnviar() {
    final e = validarTodo();
    if (e.isEmpty) return true;
    errores.assignAll(e);
    errorPublicar.value =
        'Faltan datos o hay campos por corregir. Revisa los pasos marcados.';
    return false;
  }

  /// Publica el borrador. Si la respuesta se pierde, repetir es seguro: el servidor devuelve el
  /// mismo debate en lugar de crear otro.
  Future<DebateResumen?> publicar() async {
    errorPublicar.value = null;
    if (publicando.value || !_validarParaEnviar()) return null;
    // Solo se guarda si hay cambios. Si el borrador ya se publicó (por ejemplo, se perdió la
    // respuesta de un intento anterior), se pide igualmente: el servidor devuelve ese debate.
    if ((_sucio || _borradorId == null) && !await guardar() && !_yaPublicado) {
      return null;
    }
    final id = _borradorId!;
    publicando.value = true;
    try {
      final debate = await _sesion.ejecutar((t) => _borradores.publicar(t, id));
      if (!_activo) return null;
      errorGuardado.value = null;
      _sucio = false;
      actividad?.avisar();
      return debate;
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      errorPublicar.value = e.tipo == TipoError.validacion
          ? 'El servidor rechazó algunos campos. ${mensajeDeValidacion(e)}'
          : 'No se pudo publicar. ${mensajeDeError(e)} Tu borrador está guardado.';
      return null;
    } finally {
      if (_activo) publicando.value = false;
    }
  }

  /// Guarda la edición de un debate publicado (solo si sigue sin aportes).
  /// Guarda la edición con [motivo] (queda en el historial). Si no hay cambios reales, el
  /// servidor no crea versión nueva.
  Future<DebateDetalle?> guardarEdicion(String motivo) async {
    final debate = debateEditado;
    errorPublicar.value = null;
    if (debate == null || publicando.value || !_validarParaEnviar()) {
      return null;
    }
    publicando.value = true;
    try {
      final editado = await _sesion.ejecutar(
        (t) => _debates.editar(t, debate.id, _contenido(), motivo),
      );
      if (!_activo) return null;
      _sucio = false;
      actividad?.avisar();
      return editado;
    } on SesionObsoleta {
      return null;
    } on ApiException catch (e) {
      if (!_activo) return null;
      errorPublicar.value = switch (e.tipo) {
        TipoError.conflicto => 'El debate ya recibió aportes, está protegido o archivado: su contenido quedó bloqueado.',
        TipoError.prohibido => 'Solo quien creó este debate puede editarlo.',
        _ => 'No se pudieron guardar los cambios. ${mensajeDeError(e)}',
      };
      return null;
    } finally {
      if (_activo) publicando.value = false;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';

/// Tarjeta de una cifra del dashboard: icono, valor, título y explicación, alineados arriba.
///
/// No fija alturas ni recorta textos: la altura la decide [RejillaEstadisticas].
class TarjetaEstadistica extends StatelessWidget {
  const TarjetaEstadistica({
    super.key,
    required this.valor,
    required this.titulo,
    required this.explicacion,
    required this.icono,
    this.onTap,
  });

  final int valor;
  final String titulo;
  final String explicacion;
  final IconData icono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: '$titulo: $valor. $explicacion',
          excludeSemantics: true,
          button: onTap != null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: AppColors.primario),
                const SizedBox(height: AppSpacing.s),
                Text(
                  '$valor',
                  style: texto.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primario,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(titulo, style: texto.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(explicacion, style: texto.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rejilla de tarjetas del mismo grupo con **igual ancho e igual altura**.
///
/// - Dos columnas si cada una tiene al menos [anchoMinimo] (escalado con el tamaño de texto);
///   si no, una columna.
/// - La altura común es la de la tarjeta más alta del grupo, medida sin límite: crece con el
///   texto ampliado en lugar de recortarlo.
class RejillaEstadisticas extends StatelessWidget {
  const RejillaEstadisticas({
    super.key,
    required this.children,
    this.anchoMinimo = 140,
  });

  final List<Widget> children;
  final double anchoMinimo;

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (_, restricciones) {
        final minimo = anchoMinimo * escala.clamp(1.0, 1.6);
        final columnas = restricciones.maxWidth >= minimo * 2 + AppSpacing.s
            ? 2
            : 1;
        return _RejillaUniforme(
          columnas: columnas,
          espacio: AppSpacing.s,
          children: children,
        );
      },
    );
  }
}

class _RejillaUniforme extends MultiChildRenderObjectWidget {
  const _RejillaUniforme({
    required this.columnas,
    required this.espacio,
    required super.children,
  });

  final int columnas;
  final double espacio;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRejillaUniforme(columnas, espacio);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRejillaUniforme renderObject,
  ) {
    renderObject
      ..columnas = columnas
      ..espacio = espacio;
  }
}

class _DatosCelda extends ContainerBoxParentData<RenderBox> {}

class _RenderRejillaUniforme extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DatosCelda>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DatosCelda> {
  _RenderRejillaUniforme(this._columnas, this._espacio);

  int _columnas;
  set columnas(int valor) {
    if (valor == _columnas) return;
    _columnas = valor;
    markNeedsLayout();
  }

  double _espacio;
  set espacio(double valor) {
    if (valor == _espacio) return;
    _espacio = valor;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DatosCelda) child.parentData = _DatosCelda();
  }

  double _anchoCelda(double anchoTotal) =>
      (anchoTotal - _espacio * (_columnas - 1)) / _columnas;

  @override
  void performLayout() {
    final ancho = constraints.maxWidth;
    final anchoCelda = _anchoCelda(ancho);

    // 1) Altura natural de cada tarjeta con el ancho de la celda.
    var alto = 0.0;
    var hijo = firstChild;
    while (hijo != null) {
      hijo.layout(
        BoxConstraints.tightFor(width: anchoCelda),
        parentUsesSize: true,
      );
      if (hijo.size.height > alto) alto = hijo.size.height;
      hijo = childAfter(hijo);
    }

    // 2) Todas con la altura de la más alta.
    var indice = 0;
    hijo = firstChild;
    while (hijo != null) {
      hijo.layout(BoxConstraints.tight(Size(anchoCelda, alto)));
      final fila = indice ~/ _columnas;
      final columna = indice % _columnas;
      (hijo.parentData! as _DatosCelda).offset = Offset(
        columna * (anchoCelda + _espacio),
        fila * (alto + _espacio),
      );
      indice++;
      hijo = childAfter(hijo);
    }

    final filas = (childCount / _columnas).ceil();
    size = constraints.constrain(
      Size(ancho, filas == 0 ? 0 : filas * alto + (filas - 1) * _espacio),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Layout responsive del catálogo aliado (móvil / tablet / escritorio).
abstract final class AliadoCatalogLayout {
  static bool isDesktop(double width) => width >= AppBreakpoints.b2bDesktop;

  static int crossAxisCount(double width, {double textScale = 1}) {
    width /= textScale < 1 ? 1 : textScale;
    if (width >= 1320) return 5;
    if (width >= 1040) return 4;
    if (width >= 720) return 3;
    if (width < 360) return 1;
    return 2;
  }

  static bool useCompactCards(double width) => crossAxisCount(width) >= 3;

  static int pageSizeForCount(int columns) => columns * 4;

  static int pageSize(double width) => pageSizeForCount(crossAxisCount(width));

  static double horizontalPadding(double width) => isDesktop(width) ? 0 : 16;

  static double gridSpacing(double width) => isDesktop(width) ? 14 : 10;

  /// Foto casi cuadrada, igual en todas las fichas del catálogo.
  static const cardImageAspect = 1.2;

  static const cardPadTop = 6.0;
  static const cardPadBottom = 6.0;
  static const cardPadH = 8.0;
  static const cardRadius = 16.0;

  /// Alto de la ficha para [tileWidth], con cada bloque ya reservado.
  static double cardHeight({
    required double tileWidth,
    bool showDistance = false,
    double textScale = 1,
  }) {
    final inner = (tileWidth - 16).clamp(1.0, tileWidth);
    final image = inner / cardImageAspect;
    // Space for the full price, stock, ERP fields and supplier actions.
    final scale = textScale < 1 ? 1.0 : textScale;
    return 8 + image + 70 + 224 * scale + (showDistance ? 20 * scale : 0);
  }

  static double childAspectRatio({
    required double tileWidth,
    bool showDistance = false,
    double textScale = 1,
  }) {
    final width = tileWidth <= 0 ? 1.0 : tileWidth;
    return width /
        cardHeight(
            tileWidth: width, showDistance: showDistance, textScale: textScale);
  }
}

/// Rejilla cuyas fichas miden su contenido, sin alto fijo ni hueco sobrante.
class AliadoCatalogCardWrap extends StatelessWidget {
  const AliadoCatalogCardWrap({
    super.key,
    required this.maxWidth,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double maxWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final cols = AliadoCatalogLayout.crossAxisCount(maxWidth,
        textScale: MediaQuery.textScalerOf(context).scale(14) / 14);
    final spacing = AliadoCatalogLayout.gridSpacing(maxWidth);
    final tileWidth =
        cols <= 1 ? maxWidth : (maxWidth - spacing * (cols - 1)) / cols;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (var i = 0; i < itemCount; i++)
          SizedBox(
            width: tileWidth,
            child: itemBuilder(context, i),
          ),
      ],
    );
  }
}

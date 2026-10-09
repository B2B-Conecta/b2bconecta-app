import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Layout responsive del catálogo aliado (móvil / tablet / escritorio).
abstract final class AliadoCatalogLayout {
  static bool isDesktop(double width) => width >= AppBreakpoints.b2bDesktop;

  static int crossAxisCount(double width) {
    if (width >= 1320) return 5;
    if (width >= 1040) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  static bool useCompactCards(double width) => crossAxisCount(width) >= 3;

  static int pageSizeForCount(int columns) => columns * 4;

  static int pageSize(double width) => pageSizeForCount(crossAxisCount(width));

  static double horizontalPadding(double width) =>
      isDesktop(width) ? 0 : 16;

  static double gridSpacing(double width) => isDesktop(width) ? 14 : 10;

  /// Foto ancha y baja, igual en todas las fichas del catálogo.
  static const cardImageAspect = 1.85;

  static const cardPadTop = 8.0;
  static const cardPadBottom = 10.0;
  static const cardPadH = 8.0;
  static const cardTitleHeight = 34.0;
  static const cardCategoryHeight = 20.0;
  static const cardSupplierHeight = 18.0;
  static const cardPriceHeight = 20.0;
  static const cardOfferHeight = 26.0;
  static const cardStockHeight = 16.0;
  static const cardCustomFieldsHeight = 20.0;
  static const cardGapImage = 6.0;
  static const cardGapTight = 4.0;
  static const cardGapSection = 6.0;
  static const cardDistanceHeight = 18.0;

  /// Alto de la ficha para [tileWidth], con cada bloque ya reservado.
  static double cardHeight({
    required double tileWidth,
    bool showDistance = false,
  }) {
    final inner = (tileWidth - cardPadH * 2 - 2).clamp(1.0, tileWidth);
    final image = inner / cardImageAspect;
    return cardPadTop +
        cardPadBottom +
        image +
        cardGapImage +
        cardTitleHeight +
        cardGapTight +
        cardCategoryHeight +
        cardGapTight +
        cardSupplierHeight +
        cardGapSection +
        cardPriceHeight +
        cardOfferHeight +
        cardGapSection +
        cardStockHeight +
        cardGapTight +
        cardCustomFieldsHeight +
        (showDistance ? cardGapTight + cardDistanceHeight : 0) +
        2 +
        6;
  }

  static double childAspectRatio({
    required double tileWidth,
    bool showDistance = false,
  }) {
    final width = tileWidth <= 0 ? 1.0 : tileWidth;
    return width / cardHeight(tileWidth: width, showDistance: showDistance);
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
    final cols = AliadoCatalogLayout.crossAxisCount(maxWidth);
    final spacing = AliadoCatalogLayout.gridSpacing(maxWidth);
    final tileWidth = cols <= 1
        ? maxWidth
        : (maxWidth - spacing * (cols - 1)) / cols;

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

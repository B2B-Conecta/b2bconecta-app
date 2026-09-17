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

  /// Relación ancho/alto de cada celda del grid.
  static double childAspectRatio(
    double width, {
    required bool showDistance,
  }) {
    final cols = crossAxisCount(width);
    if (cols >= 5) return showDistance ? 0.74 : 0.80;
    if (cols == 4) return showDistance ? 0.70 : 0.76;
    if (cols == 3) return showDistance ? 0.64 : 0.70;
    return showDistance ? 0.54 : 0.62;
  }

  static int pageSizeForCount(int columns) => columns * 4;

  static int pageSize(double width) => pageSizeForCount(crossAxisCount(width));

  static double horizontalPadding(double width) =>
      isDesktop(width) ? 0 : 16;

  static double gridSpacing(double width) => isDesktop(width) ? 14 : 10;
}

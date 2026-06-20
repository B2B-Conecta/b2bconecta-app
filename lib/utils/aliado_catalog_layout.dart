import 'app_breakpoints.dart';

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
    if (cols >= 5) return showDistance ? 0.70 : 0.76;
    if (cols == 4) return showDistance ? 0.66 : 0.72;
    if (cols == 3) return showDistance ? 0.60 : 0.66;
    return showDistance ? 0.50 : 0.56;
  }

  static int pageSize(double width) => crossAxisCount(width) * 4;

  static double horizontalPadding(double width) =>
      isDesktop(width) ? 0 : 16;

  static double gridSpacing(double width) => isDesktop(width) ? 14 : 10;
}

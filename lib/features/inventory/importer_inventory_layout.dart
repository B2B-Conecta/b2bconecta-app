import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Layout responsive del inventario importador (móvil / escritorio).
abstract final class ImporterInventoryLayout {
  static bool isDesktop(double width) => width >= AppBreakpoints.b2bDesktop;

  static double horizontalPadding(double width) =>
      isDesktop(width) ? 0 : 16;

  static double listBottomPadding({
    required double width,
    required bool bulkMode,
    bool deleteOnly = false,
  }) {
    if (!bulkMode) return isDesktop(width) ? 96 : 88;
    if (deleteOnly) return isDesktop(width) ? 132 : 112;
    return isDesktop(width) ? 188 : 160;
  }
}

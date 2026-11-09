import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';

/// Layout responsive del inventario importador (móvil / escritorio).
abstract final class ImporterInventoryLayout {
  static bool isDesktop(double width) => width >= AppBreakpoints.b2bDesktop;

  static double horizontalPadding(double width) => isDesktop(width) ? 0 : 16;

  static double listBottomPadding({
    required double width,
    required bool bulkMode,
    bool deleteOnly = false,
  }) {
    if (!bulkMode) return 12;
    if (deleteOnly) return isDesktop(width) ? 132 : 112;
    return isDesktop(width) ? 188 : 160;
  }

  static const int pageSize = 40;
}

/// Total que muestra el paginador. [matching] es el conteo con los filtros
/// activos; si todavía no llegó, se usa lo ya cargado.
int inventoryPagerTotal({required int loaded, int? matching}) =>
    listPagerTotal(loaded: loaded, matching: matching);

/// Hay filas más allá del lote en memoria.
bool inventoryHasMore({
  required int loaded,
  required int batchLength,
  required int fetchSize,
  int? matching,
}) =>
    listPagerHasMore(
      loaded: loaded,
      batchLength: batchLength,
      fetchSize: fetchSize,
      matching: matching,
    );

/// Subtítulo del inventario. Sin filtros coincide con el paginador.
/// Con filtros explica el recorte: «12 de 45 productos».
String inventoryRegisteredLabel({
  required int? registered,
  required int? matching,
  required bool filtering,
}) {
  if (registered == null) return 'Tus productos';
  if (filtering && matching != null && matching != registered) {
    return '$matching de $registered productos';
  }
  return '$registered productos registrados';
}

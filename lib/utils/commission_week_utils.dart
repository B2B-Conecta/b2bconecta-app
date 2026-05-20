/// Utilidades de semana ISO (lunes) para cortes de comisión.
abstract final class CommissionWeekUtils {
  CommissionWeekUtils._();

  static DateTime mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static DateTime sundayOfWeekStarting(DateTime monday) =>
      monday.add(const Duration(days: 6));

  static String periodLabelEs(DateTime periodStart, DateTime periodEnd) {
    String fmt(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
    return '${fmt(periodStart)} — ${fmt(periodEnd)}';
  }

  /// Clave estable para agrupar por semana (lunes UTC-local de period_start).
  static String weekKey(DateTime periodStart) {
    final m = mondayOf(periodStart);
    return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
  }
}

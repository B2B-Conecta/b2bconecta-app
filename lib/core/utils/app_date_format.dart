/// Formato local corto para trazabilidad (sin dependencia intl).
String formatEsShortDateTime(DateTime? utcOrLocal) {
  if (utcOrLocal == null) return '—';
  final d = utcOrLocal.isUtc ? utcOrLocal.toLocal() : utcOrLocal;
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '${formatEsShortDate(d)} $h:$min';
}

/// Fecha `dd/MM/yyyy` y hora de 12 horas (`3:06 PM`). El panel móvil sigue en 24 h.
String formatEsShortDateTime12h(DateTime? utcOrLocal) {
  if (utcOrLocal == null) return '—';
  final d = utcOrLocal.isUtc ? utcOrLocal.toLocal() : utcOrLocal;
  final suffix = d.hour >= 12 ? 'PM' : 'AM';
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final min = d.minute.toString().padLeft(2, '0');
  return '${formatEsShortDate(d)} $hour12:$min $suffix';
}

String formatEsShortDate(DateTime utcOrLocal) {
  final d = utcOrLocal.toLocal();
  final day = d.day.toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  final y = d.year.toString();
  return '$day/$m/$y';
}

/// Rango de semana ISO (lunes–domingo) para cierres de reputación.
String formatEsWeekRange(DateTime weekStartMonday) {
  final start = DateTime(
      weekStartMonday.year, weekStartMonday.month, weekStartMonday.day);
  final end = start.add(const Duration(days: 6));
  String short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  return '${short(start)} – ${short(end)}';
}

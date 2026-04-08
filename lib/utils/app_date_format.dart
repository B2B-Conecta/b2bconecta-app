/// Formato local corto para trazabilidad (sin dependencia intl).
String formatEsShortDateTime(DateTime? utcOrLocal) {
  if (utcOrLocal == null) return '—';
  final d = utcOrLocal.isUtc ? utcOrLocal.toLocal() : utcOrLocal;
  final day = d.day.toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  final y = d.year.toString();
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$day/$m/$y $h:$min';
}

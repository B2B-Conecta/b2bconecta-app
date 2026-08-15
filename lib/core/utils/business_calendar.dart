/// Días hábiles simples (lunes a viernes; sin feriados).
int businessDaysElapsedAfterUtcDate(DateTime fromUtc) {
  var d = DateTime.utc(fromUtc.year, fromUtc.month, fromUtc.day)
      .add(const Duration(days: 1));
  final end = DateTime.utc(
    DateTime.now().toUtc().year,
    DateTime.now().toUtc().month,
    DateTime.now().toUtc().day,
  );
  var n = 0;
  while (!d.isAfter(end)) {
    if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
      n++;
    }
    d = d.add(const Duration(days: 1));
  }
  return n;
}

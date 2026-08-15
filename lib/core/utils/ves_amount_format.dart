// Formato contable VES (miles `.`, decimal `,`) y REF (punto decimal, sin miles).

String formatRefAmount(double value, {int fractionDigits = 2}) {
  if (value.isNaN || value.isInfinite) {
    return _fallbackRef(fractionDigits);
  }
  return value.toStringAsFixed(fractionDigits);
}

/// Monto en bolívares sin prefijo (solo número formateado).
String formatVesAmount(double value, {int fractionDigits = 2}) {
  if (value.isNaN || value.isInfinite) {
    return _fallbackVes(fractionDigits);
  }
  final negative = value.isNegative;
  final abs = negative ? -value : value;
  final s = abs.toStringAsFixed(fractionDigits);
  final dot = s.indexOf('.');
  final intPart = dot >= 0 ? s.substring(0, dot) : s;
  final decPart = dot >= 0 ? s.substring(dot + 1) : '';
  final grouped = _groupIntPartThousands(intPart);
  final core = decPart.isEmpty ? grouped : '$grouped,$decPart';
  return negative ? '-$core' : core;
}

/// Ej. `Bs 2.500,50`
String formatBsLabel(double value, {int fractionDigits = 2}) =>
    'Bs ${formatVesAmount(value, fractionDigits: fractionDigits)}';

/// Tasa BCV u otros coeficientes en presentación local (ej. 36,45 o 36,4521).
String formatTasaBcvDisplay(double value, {int fractionDigits = 2}) =>
    formatVesAmount(value, fractionDigits: fractionDigits);

/// Interpreta entrada de usuario: acepta `36,45`, `36.45`, `1.234,56`.
double? parseVesOrEnDecimal(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }
  return double.tryParse(s);
}

String _groupIntPartThousands(String intPart) {
  if (intPart.isEmpty) return '0';
  final neg = intPart.startsWith('-');
  var d = neg ? intPart.substring(1) : intPart;
  if (d.isEmpty) d = '0';
  final buf = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) buf.write('.');
    buf.write(d[i]);
  }
  final out = buf.toString();
  return neg ? '-$out' : out;
}

String _fallbackRef(int fractionDigits) =>
    fractionDigits <= 0 ? '0' : '0.${'0' * fractionDigits}';

String _fallbackVes(int fractionDigits) =>
    fractionDigits <= 0 ? '0' : '0,${'0' * fractionDigits}';

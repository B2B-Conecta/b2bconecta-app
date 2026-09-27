import 'cart_service.dart';
import 'min_order_currency.dart';

/// Progreso del piso de compra de un importador en el carrito.
class ImporterMinOrderProgress {
  const ImporterMinOrderProgress({
    required this.importerName,
    required this.currentRef,
    required this.minRef,
    this.currency = MinOrderCurrency.ref,
  });

  final String importerName;
  final double currentRef;
  final double minRef;
  final MinOrderCurrency currency;

  bool get hasMinimum => minRef > 0;

  bool get meets => !hasMinimum || currentRef + 1e-9 >= minRef;

  double get remainingRef => meets ? 0 : minRef - currentRef;

  double get fraction {
    if (!hasMinimum) return 1;
    if (minRef <= 0) return 1;
    final f = currentRef / minRef;
    if (f.isNaN || f.isInfinite) return 0;
    return f.clamp(0.0, 1.0);
  }
}

double cartLinesSubtotalRef(Iterable<CartLine> lines) {
  var s = 0.0;
  for (final line in lines) {
    s += line.precioUnitarioAliadoRef * line.quantity;
  }
  return s;
}

List<ImporterMinOrderProgress> importerMinOrderProgressFor(
  Iterable<MapEntry<String, List<CartLine>>> groups,
) {
  return groups.map((entry) {
    final lines = entry.value;
    final minRef = lines
        .map((l) => l.part.ownerMinOrderAmountRef)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return ImporterMinOrderProgress(
      importerName: entry.key,
      currentRef: cartLinesSubtotalRef(lines),
      minRef: minRef,
      currency: lines.isEmpty
          ? MinOrderCurrency.ref
          : lines.first.part.ownerMinOrderCurrency,
    );
  }).toList();
}

/// Extrae el mensaje de `min_order_amount:owner:min:subtotal:name`.
String? cartMinOrderErrorMessage(Object error) {
  final raw = error.toString();
  final match = RegExp(
    r'min_order_amount:([^:]+):([^:]+):([^:]+):(.+)',
  ).firstMatch(raw);
  if (match == null) return null;
  final minRef = double.tryParse(match.group(2) ?? '') ?? 0;
  final subtotal = double.tryParse(match.group(3) ?? '') ?? 0;
  final name = (match.group(4) ?? 'este importador').trim();
  final cleanName = name.replaceAll(RegExp(r'[.\s]+$'), '');
  return 'El pedido a $cleanName debe ser de al menos '
      '${minRef.toStringAsFixed(2)} REF '
      '(lleva ${subtotal.toStringAsFixed(2)} REF).';
}

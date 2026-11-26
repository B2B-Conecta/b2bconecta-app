import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';

import 'cart_service.dart';
import 'min_order_currency.dart';

/// Progreso del piso de compra de un importador en el carrito.
class ImporterMinOrderProgress {
  const ImporterMinOrderProgress({
    required this.importerName,
    required this.currentRef,
    required this.minRef,
    this.importerId,
    this.currency = MinOrderCurrency.ref,
  });

  final String importerName;
  final String? importerId;
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
      importerId: lines.isEmpty ? null : lines.first.part.ownerId,
      importerName: lines.isEmpty
          ? entry.key
          : (lines.first.part.ownerBusinessName?.trim().isNotEmpty == true
              ? lines.first.part.ownerBusinessName!.trim()
              : 'Importador'),
      currentRef: cartLinesSubtotalRef(lines),
      minRef: minRef,
      currency: lines.isEmpty
          ? MinOrderCurrency.ref
          : lines.first.part.ownerMinOrderCurrency,
    );
  }).toList();
}

/// Monto mínimo de un proveedor en el carrito.
///
/// Solo existe si el proveedor lo guardó. Sin monto propio no hay piso.
class SupplierUsdMinOrder {
  const SupplierUsdMinOrder({
    required this.current,
    required this.minimum,
    required this.currency,
    required this.hasMinimum,
  });

  final double current;
  final double minimum;
  final MinOrderCurrency currency;
  final bool hasMinimum;

  bool get meets => !hasMinimum || current + 1e-9 >= minimum;

  double get remaining => meets ? 0 : minimum - current;

  double get fraction {
    if (!hasMinimum || minimum <= 0) return 1;
    final value = current / minimum;
    if (value.isNaN || value.isInfinite) return 0;
    return value.clamp(0.0, 1.0);
  }

  static SupplierUsdMinOrder of(Iterable<CartLine> lines) {
    final list = lines.toList();
    if (list.isEmpty || list.first.part.ownerMinOrderAmountRef <= 0) {
      return const SupplierUsdMinOrder(
        current: 0,
        minimum: 0,
        currency: MinOrderCurrency.usd,
        hasMinimum: false,
      );
    }
    final part = list.first.part;
    final configured = part.ownerMinOrderAmountRef;
    if (part.ownerMinOrderCurrency != MinOrderCurrency.usd) {
      return SupplierUsdMinOrder(
        current: cartLinesSubtotalRef(list),
        minimum: configured,
        currency: part.ownerMinOrderCurrency,
        hasMinimum: true,
      );
    }
    return SupplierUsdMinOrder(
      current: _usdSubtotal(list),
      minimum: configured,
      currency: MinOrderCurrency.usd,
      hasMinimum: true,
    );
  }

  static bool meetsLines(Iterable<CartLine> lines) => of(lines).meets;

  static double _usdSubtotal(List<CartLine> lines) {
    var total = 0.0;
    for (final line in lines) {
      total += ProductCatalogPricing.aliadoUnitUsdPaymentLine(
            refUnitUsd: line.precioUnitarioAliadoRef,
            salePriceUsd: line.part.salePriceUsd,
            discountRules: line.part.discountRules,
            ownerPagoSoloDivisas: line.part.ownerPagoSoloDivisas,
          ) *
          line.quantity;
    }
    return total;
  }
}

/// Unidades mínimas de un pedido a un proveedor.
///
/// Sin un entero guardado por el proveedor no hay piso. Se suman todas las
/// unidades de su catálogo.
abstract final class SupplierOrderMinUnits {
  static int? definedMinimum(Iterable<CartLine> lines) {
    for (final line in lines) {
      final configured = line.part.ownerMinOrderUnits;
      if (configured != null && configured >= 1) return configured;
    }
    return null;
  }

  static int selected(Iterable<CartLine> lines) =>
      lines.fold(0, (sum, line) => sum + line.quantity);

  static bool meets(Iterable<CartLine> lines) {
    final minimum = definedMinimum(lines);
    if (minimum == null) return true;
    return selected(lines) >= minimum;
  }

  static int missing(Iterable<CartLine> lines) {
    final minimum = definedMinimum(lines);
    if (minimum == null) return 0;
    final gap = minimum - selected(lines);
    return gap > 0 ? gap : 0;
  }
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

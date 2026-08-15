import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'transaction_request_model.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/inventory/product_volume_tiers.dart';

/// Vista previa del descuento divisas para la ficha del pedido.
class UsdPaymentDiscountPreview {
  const UsdPaymentDiscountPreview({
    required this.baseRef,
    required this.total,
    required this.metodo,
    this.pct,
  });

  final double baseRef;
  final double total;
  final String? metodo;
  final double? pct;

  bool get applies =>
      metodo != null &&
      PagoMetodo.qualifiesForUsdDiscount(metodo) &&
      pct != null &&
      pct! > 0 &&
      total < baseRef - 0.0001;

  double get ahorro => (baseRef - total).clamp(0, double.infinity);

  String? get pctLabel {
    final p = pct;
    if (p == null) return null;
    return p.truncateToDouble() == p ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  }
}

/// Total del pedido según método de pago (descuento divisas alineado al servidor).
abstract final class OrderPaymentPricing {
  static double refBaseTotal({
    required double precioTotal,
    required double precioBaseAliadoTotal,
  }) {
    if (precioBaseAliadoTotal > 0) return precioBaseAliadoTotal;
    return precioTotal;
  }

  static double totalForPagoMetodo({
    required double refBaseTotal,
    Map<String, dynamic>? discountRules,
    required String? pagoMetodo,
    bool ownerPagoSoloDivisas = false,
  }) {
    if (ownerPagoSoloDivisas ||
        !PagoMetodo.qualifiesForUsdDiscount(pagoMetodo)) {
      return refBaseTotal;
    }
    return ProductCatalogPricing.aliadoUnitUsdPaymentLine(
      refUnitUsd: refBaseTotal,
      discountRules: discountRules,
    );
  }

  static String? discountHintEs({
    Map<String, dynamic>? discountRules,
    required String? pagoMetodo,
    bool ownerPagoSoloDivisas = false,
  }) {
    if (ownerPagoSoloDivisas ||
        !PagoMetodo.qualifiesForUsdDiscount(pagoMetodo)) {
      return null;
    }
    final pct = ProductCatalogPricing.usdPaymentDiscountPct(discountRules);
    if (pct == null) return null;
    final label = pct.truncateToDouble() == pct
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(1);
    return 'Descuento divisas/efectivo: $label % sobre el total REF';
  }

  static UsdPaymentDiscountPreview previewForRequest({
    required TransactionRequestModel request,
    required String? pagoMetodo,
  }) {
    final rules = request.effectiveDiscountRulesForPago;
    final base = request.refBaseTotalForPago;
    final total = totalForPagoMetodo(
      refBaseTotal: base,
      discountRules: rules,
      pagoMetodo: pagoMetodo,
      ownerPagoSoloDivisas: request.ownerPagoSoloDivisas,
    );
    return UsdPaymentDiscountPreview(
      baseRef: base,
      total: total,
      metodo: pagoMetodo,
      pct: request.ownerPagoSoloDivisas
          ? null
          : parseUsdPaymentDiscountPct(rules),
    );
  }

  static UsdPaymentDiscountPreview previewForLines({
    required List<TransactionRequestModel> lines,
    required String? pagoMetodo,
  }) {
    var base = 0.0;
    var total = 0.0;
    double? pct;
    for (final r in lines) {
      final rules = r.effectiveDiscountRulesForPago;
      final lineBase = r.refBaseTotalForPago;
      base += lineBase;
      total += totalForPagoMetodo(
        refBaseTotal: lineBase,
        discountRules: rules,
        pagoMetodo: pagoMetodo,
        ownerPagoSoloDivisas: r.ownerPagoSoloDivisas,
      );
      if (!r.ownerPagoSoloDivisas) {
        pct ??= parseUsdPaymentDiscountPct(rules);
      }
    }
    return UsdPaymentDiscountPreview(
      baseRef: base,
      total: total,
      metodo: pagoMetodo,
      pct: pct,
    );
  }
}

import '../models/cash_phase_policy.dart';
import 'broker_pricing.dart';
import 'product_volume_tiers.dart';

/// Cascada E4 para precios aliado (catálogo y preview; checkout en servidor).
abstract final class ProductCatalogPricing {
  static const double motolinkFeeRate = BrokerPricing.feeRate;

  /// Descuento en la línea USD del catálogo (pago en divisas / Zelle), % sobre precio REF.
  static double? usdPaymentDiscountPct(Map<String, dynamic>? discountRules) =>
      parseUsdPaymentDiscountPct(discountRules);

  static bool hasUsdPaymentDiscount(Map<String, dynamic>? discountRules) =>
      usdPaymentDiscountPct(discountRules) != null;

  /// Precio unitario aliado en línea USD (sobre [refUnitUsd] ya con cascada E4).
  static double aliadoUnitUsdPaymentLine({
    required double refUnitUsd,
    Map<String, dynamic>? discountRules,
  }) {
    final pct = usdPaymentDiscountPct(discountRules);
    if (pct == null) return refUnitUsd;
    return refUnitUsd * (1 - pct / 100.0);
  }

  static bool hasAnyCommercialBenefit({
    required double listPriceUsd,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
  }) =>
      hasDirectSale(listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd) ||
      volumeDiscountPercent(discountRules, 1) > 0 ||
      hasUsdPaymentDiscount(discountRules);

  static bool hasDirectSale({
    required double listPriceUsd,
    double? salePriceUsd,
  }) {
    final sale = salePriceUsd;
    return sale != null && sale > 0 && sale < listPriceUsd;
  }

  static double wholesaleUnitUsd({
    required double listPriceUsd,
    double? salePriceUsd,
  }) {
    final sale = salePriceUsd;
    if (sale != null && sale > 0) return sale;
    return listPriceUsd;
  }

  static double volumeDiscountPercent(
    Map<String, dynamic>? discountRules,
    int quantity,
  ) {
    final tier = activeProductVolumeTier(
      parseProductVolumeTiers(discountRules),
      quantity,
    );
    return tier?.percentDiscount ?? 0;
  }

  /// Precio unitario aliado tras cascada completa.
  static double aliadoUnitUsd({
    required double listPriceUsd,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
    int quantity = 1,
    required bool faseContado,
  }) {
    final wholesale = wholesaleUnitUsd(
      listPriceUsd: listPriceUsd,
      salePriceUsd: salePriceUsd,
    );
    final pct = volumeDiscountPercent(discountRules, quantity);
    final afterVolume = wholesale * (1 - pct / 100.0);
    var unit = afterVolume * (1 + motolinkFeeRate);
    if (faseContado) {
      unit *= (1 - CashPhasePolicy.descuentoContadoSobrePrecioMotoLink);
    }
    return unit;
  }

  /// Precio tachado: lista regular sin oferta directa (sin tramo volumen en grid).
  static double aliadoUnitRegularListUsd({
    required double listPriceUsd,
    Map<String, dynamic>? discountRules,
    int quantity = 1,
    required bool faseContado,
  }) =>
      aliadoUnitUsd(
        listPriceUsd: listPriceUsd,
        salePriceUsd: null,
        discountRules: discountRules,
        quantity: quantity,
        faseContado: faseContado,
      );

  static String? volumeIncentiveBadgeEs(
    Map<String, dynamic>? discountRules, {
    int currentQuantity = 1,
  }) {
    final next = nextProductVolumeTier(
      parseProductVolumeTiers(discountRules),
      currentQuantity,
    );
    if (next == null) return null;
    final pct = _formatPercentLabel(next.percentDiscount);
    return 'Compra ${next.minUnits} unidades y obtén $pct de descuento adicional';
  }

  /// Etiqueta corta para chips en el grid del catálogo aliado.
  static String? volumeIncentiveChipEs(
    Map<String, dynamic>? discountRules, {
    int currentQuantity = 1,
  }) {
    final next = nextProductVolumeTier(
      parseProductVolumeTiers(discountRules),
      currentQuantity,
    );
    if (next == null) return null;
    final pct = _formatPercentLabel(next.percentDiscount);
    return 'Desde ${next.minUnits} uds: $pct';
  }

  static String _formatPercentLabel(double pct) {
    final s = pct.toStringAsFixed(
      pct.truncateToDouble() == pct ? 0 : 1,
    );
    return '$s% dto.';
  }

  /// Chip con monto USD si hay descuento por pago en divisas.
  static String? usdPaymentChipEs({
    required double refUnitUsd,
    Map<String, dynamic>? discountRules,
  }) {
    final pct = usdPaymentDiscountPct(discountRules);
    if (pct == null) return null;
    final usd = aliadoUnitUsdPaymentLine(
      refUnitUsd: refUnitUsd,
      discountRules: discountRules,
    );
    final pctLabel = pct.toStringAsFixed(
      pct.truncateToDouble() == pct ? 0 : 1,
    );
    return 'USD ${usd.toStringAsFixed(2)} ($pctLabel% menos)';
  }
}

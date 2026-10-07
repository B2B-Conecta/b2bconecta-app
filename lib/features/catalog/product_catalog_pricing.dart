import 'package:motolink_pro_app/features/inventory/product_volume_tiers.dart';

/// Cascada E4 para precios aliado (catálogo y preview; checkout en servidor).
/// Sin markup B2B Conecta: lista/oferta del importador → % volumen → línea USD opcional.
abstract final class ProductCatalogPricing {

  /// Descuento en la línea USD del catálogo (pago en divisas / Zelle), % sobre precio REF.
  static double? usdPaymentDiscountPct(Map<String, dynamic>? discountRules) =>
      parseUsdPaymentDiscountPct(discountRules);

  static double? effectiveUsdPaymentDiscountPct({
    Map<String, dynamic>? discountRules,
    bool ownerPagoSoloDivisas = false,
  }) {
    if (ownerPagoSoloDivisas) return null;
    return usdPaymentDiscountPct(discountRules);
  }

  static bool hasUsdPaymentDiscount(
    Map<String, dynamic>? discountRules, {
    bool ownerPagoSoloDivisas = false,
  }) =>
      effectiveUsdPaymentDiscountPct(
        discountRules: discountRules,
        ownerPagoSoloDivisas: ownerPagoSoloDivisas,
      ) !=
      null;

  /// Precio unitario aliado en línea USD (sobre [refUnitUsd] ya con cascada E4).
  static double aliadoUnitUsdPaymentLine({
    required double refUnitUsd,
    Map<String, dynamic>? discountRules,
    bool ownerPagoSoloDivisas = false,
  }) {
    final pct = effectiveUsdPaymentDiscountPct(
      discountRules: discountRules,
      ownerPagoSoloDivisas: ownerPagoSoloDivisas,
    );
    if (pct == null) return refUnitUsd;
    return refUnitUsd * (1 - pct / 100.0);
  }

  static bool hasAnyCommercialBenefit({
    required double listPriceUsd,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
    bool ownerPagoSoloDivisas = false,
    double? campaignDiscountPercent,
  }) =>
      hasDirectSale(listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd) ||
      hasCampaignDiscount(campaignDiscountPercent) ||
      volumeDiscountPercent(discountRules, 1) > 0 ||
      hasUsdPaymentDiscount(
        discountRules,
        ownerPagoSoloDivisas: ownerPagoSoloDivisas,
      );

  static bool hasDirectSale({
    required double listPriceUsd,
    double? salePriceUsd,
  }) {
    final sale = salePriceUsd;
    return sale != null && sale > 0 && sale < listPriceUsd;
  }

  static bool hasCampaignDiscount(double? campaignDiscountPercent) {
    final pct = campaignDiscountPercent;
    return pct != null && pct > 0 && pct < 100;
  }

  /// Precio de lista con % de valla (sin oferta directa).
  static double? campaignUnitUsd({
    required double listPriceUsd,
    double? campaignDiscountPercent,
  }) {
    if (!hasCampaignDiscount(campaignDiscountPercent)) return null;
    final price = listPriceUsd * (1 - campaignDiscountPercent! / 100.0);
    if (price <= 0 || price >= listPriceUsd) return null;
    return price;
  }

  /// Mayorista: el menor entre oferta directa y precio de campaña, o lista.
  static double wholesaleUnitUsd({
    required double listPriceUsd,
    double? salePriceUsd,
    double? campaignDiscountPercent,
  }) {
    final candidates = <double>[];
    if (hasDirectSale(listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd)) {
      candidates.add(salePriceUsd!);
    }
    final camp = campaignUnitUsd(
      listPriceUsd: listPriceUsd,
      campaignDiscountPercent: campaignDiscountPercent,
    );
    if (camp != null) candidates.add(camp);
    if (candidates.isEmpty) return listPriceUsd;
    return candidates.reduce((a, b) => a < b ? a : b);
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
    double? campaignDiscountPercent,
  }) {
    final wholesale = wholesaleUnitUsd(
      listPriceUsd: listPriceUsd,
      salePriceUsd: salePriceUsd,
      campaignDiscountPercent: campaignDiscountPercent,
    );
    final pct = volumeDiscountPercent(discountRules, quantity);
    return wholesale * (1 - pct / 100.0);
  }

  /// Precio tachado: lista regular sin oferta/valla (sin tramo volumen en grid).
  static double aliadoUnitRegularListUsd({
    required double listPriceUsd,
    Map<String, dynamic>? discountRules,
    int quantity = 1,
  }) =>
      aliadoUnitUsd(
        listPriceUsd: listPriceUsd,
        salePriceUsd: null,
        discountRules: discountRules,
        quantity: quantity,
        campaignDiscountPercent: null,
      );

  static String? campaignDiscountChipEs(double? campaignDiscountPercent) {
    if (!hasCampaignDiscount(campaignDiscountPercent)) return null;
    final pct = campaignDiscountPercent!;
    final label = pct == pct.roundToDouble()
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(1);
    return 'Promo −$label%';
  }

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
    bool ownerPagoSoloDivisas = false,
  }) {
    final pct = effectiveUsdPaymentDiscountPct(
      discountRules: discountRules,
      ownerPagoSoloDivisas: ownerPagoSoloDivisas,
    );
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

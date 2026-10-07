import 'package:motolink_pro_app/features/inventory/product_volume_tiers.dart';

/// Cascada E4 para precios aliado (catálogo y preview; checkout en servidor).
///
/// Volumen y valla son caminos excluyentes sobre el precio **base** (lista):
/// - Si la cantidad activa un tramo por unidades → % volumen sobre lista
///   (también se considera oferta directa `sale_price_usd` si es menor).
/// - Si no hay tramo activo → % de promoción/valla sobre lista
///   (o oferta directa si es menor).
/// Luego, opcionalmente, línea USD/Zelle sobre el REF resultante.
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

  /// True cuando la cantidad activa un tramo por unidades (camino volumen).
  static bool volumePathActive(
    Map<String, dynamic>? discountRules,
    int quantity,
  ) =>
      volumeDiscountPercent(discountRules, quantity) > 0;

  /// Precio de lista con % de valla (sobre base).
  static double? campaignUnitUsd({
    required double listPriceUsd,
    double? campaignDiscountPercent,
  }) {
    if (!hasCampaignDiscount(campaignDiscountPercent)) return null;
    final price = listPriceUsd * (1 - campaignDiscountPercent! / 100.0);
    if (price <= 0 || price >= listPriceUsd) return null;
    return price;
  }

  static double? _volumeOnListUnitUsd({
    required double listPriceUsd,
    required double volumePercent,
  }) {
    if (volumePercent <= 0 || volumePercent >= 100) return null;
    final price = listPriceUsd * (1 - volumePercent / 100.0);
    if (price <= 0 || price >= listPriceUsd) return null;
    return price;
  }

  static double _minCandidate(double list, Iterable<double?> extras) {
    var best = list;
    for (final x in extras) {
      if (x != null && x > 0 && x < best) best = x;
    }
    return best;
  }

  /// Mayorista sin volumen: min(lista, oferta, lista×promo).
  static double wholesaleUnitUsd({
    required double listPriceUsd,
    double? salePriceUsd,
    double? campaignDiscountPercent,
  }) {
    return _minCandidate(listPriceUsd, [
      hasDirectSale(listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd)
          ? salePriceUsd
          : null,
      campaignUnitUsd(
        listPriceUsd: listPriceUsd,
        campaignDiscountPercent: campaignDiscountPercent,
      ),
    ]);
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

  /// Precio unitario aliado: volumen **o** promo sobre base (no se apilan).
  static double aliadoUnitUsd({
    required double listPriceUsd,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
    int quantity = 1,
    double? campaignDiscountPercent,
  }) {
    final volPct = volumeDiscountPercent(discountRules, quantity);
    if (volPct > 0) {
      // Camino por unidades: % volumen sobre lista; oferta directa si es menor.
      return _minCandidate(listPriceUsd, [
        hasDirectSale(listPriceUsd: listPriceUsd, salePriceUsd: salePriceUsd)
            ? salePriceUsd
            : null,
        _volumeOnListUnitUsd(
          listPriceUsd: listPriceUsd,
          volumePercent: volPct,
        ),
      ]);
    }

    // Camino promoción / oferta: % valla sobre lista (o oferta directa).
    return wholesaleUnitUsd(
      listPriceUsd: listPriceUsd,
      salePriceUsd: salePriceUsd,
      campaignDiscountPercent: campaignDiscountPercent,
    );
  }

  /// Precio tachado: siempre la lista (base), sin oferta/valla/volumen.
  static double aliadoUnitRegularListUsd({
    required double listPriceUsd,
    Map<String, dynamic>? discountRules,
    int quantity = 1,
  }) =>
      listPriceUsd;

  /// Chip de promo solo si el camino volumen no está activo.
  static String? campaignDiscountChipEs(
    double? campaignDiscountPercent, {
    Map<String, dynamic>? discountRules,
    int quantity = 1,
  }) {
    if (volumePathActive(discountRules, quantity)) return null;
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
    return 'Compra ${next.minUnits} unidades y obtén $pct sobre el precio base';
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

/// Precio unitario para el aliado: igual al mayorista del importador (sin markup B2B Conecta).
abstract final class BrokerPricing {
  /// Sin recargo broker en catálogo; comisión B2B Conecta se liquida aparte en cortes.
  static const double feeRate = 0.0;

  static double finalUnitPrice(double wholesaleUnitPriceUsd) {
    return wholesaleUnitPriceUsd;
  }

  static double unitPriceForAliado(double wholesaleUnitPriceUsd) {
    return wholesaleUnitPriceUsd;
  }
}

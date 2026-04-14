/// Precio final unitario para el aliado: mayorista + comisión MotoLink (broker).
abstract final class BrokerPricing {
  static const double feeRate = 0.10;

  static double finalUnitPrice(double wholesaleUnitPriceUsd) {
    return wholesaleUnitPriceUsd * (1 + feeRate);
  }
}

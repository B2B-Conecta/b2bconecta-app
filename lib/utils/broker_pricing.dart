import '../models/cash_phase_policy.dart';

/// Precio final unitario para el aliado: mayorista + comisión MotoLink (broker).
abstract final class BrokerPricing {
  static const double feeRate = 0.10;

  static double finalUnitPrice(double wholesaleUnitPriceUsd) {
    return wholesaleUnitPriceUsd * (1 + feeRate);
  }

  /// Precio de venta al aliado: [finalUnitPrice] y, en fase contado, descuento promocional acordado.
  static double unitPriceForAliado(
    double wholesaleUnitPriceUsd, {
    required bool faseContado,
  }) {
    final base = finalUnitPrice(wholesaleUnitPriceUsd);
    if (faseContado) {
      return base *
          (1 - CashPhasePolicy.descuentoContadoSobrePrecioMotoLink);
    }
    return base;
  }
}

/// Primeros [entregasRequeridas] pedidos de onboarding: precio promocional contado, reglas de acceso
/// relajadas (RIF + domicilio) y en la UI de pago solo transferencia/efectivo.
///
/// Tras completar esa fase, nuevos pedidos exigen KYC aprobado para usar crédito MotoLink; el pago al
/// contado (transferencia/efectivo) y el resto de métodos siguen disponibles según cupo y perfil.
abstract final class CashPhasePolicy {
  static const int entregasRequeridas = 3;

  /// Descuento sobre el precio unitario MotoLink (mayorista + comisión broker) en fase contado.
  /// Ej.: 0.05 = 5 % menos sobre ese precio; debe coincidir con la validación en servidor cuando aplique.
  static const double descuentoContadoSobrePrecioMotoLink = 0.05;
}

/// Método de pago del aliado (`transaction_requests.pago_metodo`).
///
/// En los **primeros pedidos contado** (onboarding) la UI solo ofrece [valuesFaseContado].
/// **Después** de esa fase, con KYC aprobado y cupo puede usarse [creditoSistema]; transferencia y
/// efectivo **siguen** disponibles para compras al contado junto con el resto de medios.
abstract final class PagoMetodo {
  /// Recargo sobre [precio_base_aliado_total] al elegir efectivo (servidor y cliente alineados).
  static const double recargoEfectivoTasa = 0.04;

  static const pagoMovil = 'pago_movil';
  static const zelleDivisas = 'zelle_divisas';
  static const transferencia = 'transferencia';
  static const efectivo = 'efectivo';

  /// Línea de crédito MotoLink (solo tras fase contado y con cupo asignado).
  static const creditoSistema = 'credito_sistema';

  static const values = [pagoMovil, zelleDivisas, transferencia, efectivo];

  /// Solo durante onboarding (primeras entregas contado): transferencia y efectivo.
  static const valuesFaseContado = [transferencia, efectivo];

  /// Tras onboarding: todos los medios habituales + crédito MotoLink (si hay cupo en perfil).
  static const valuesPostContadoConCredito = [
    pagoMovil,
    zelleDivisas,
    transferencia,
    efectivo,
    creditoSistema,
  ];

  static String labelEs(String code) {
    switch (code.trim()) {
      case pagoMovil:
        return 'Pago Móvil';
      case zelleDivisas:
        return 'Zelle (divisas)';
      case transferencia:
        return 'Transferencia';
      case efectivo:
        return 'Efectivo';
      case creditoSistema:
        return 'Crédito del sistema (MotoLink)';
      default:
        return code;
    }
  }
}

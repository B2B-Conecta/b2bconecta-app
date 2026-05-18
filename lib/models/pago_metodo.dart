/// Método de pago del aliado (`transaction_requests.pago_metodo`).
///
/// En los **primeros pedidos contado** (onboarding) la UI solo ofrece [valuesFaseContado].
/// Tras esa fase, MotoConecta ofrece los medios en [valuesMotoconecta]; plazos y cuotas se acuerdan
/// con el importador en el chat del pedido.
abstract final class PagoMetodo {
  /// Recargo sobre [precio_base_aliado_total] al elegir efectivo (servidor y cliente alineados).
  static const double recargoEfectivoTasa = 0.04;

  static const pagoMovil = 'pago_movil';
  static const zelleDivisas = 'zelle_divisas';
  static const transferencia = 'transferencia';
  static const binance = 'binance';
  static const efectivo = 'efectivo';

  /// Legado: línea MotoLink en plataforma (pedidos históricos; ya no se ofrece en UI nueva).
  static const creditoSistema = 'credito_sistema';

  /// MotoConecta: medios acordados; verificación por el importador.
  static const valuesMotoconecta = [
    zelleDivisas,
    pagoMovil,
    binance,
    transferencia,
    efectivo,
  ];

  static const values = [pagoMovil, zelleDivisas, transferencia, efectivo, binance];

  /// Solo durante onboarding (primeras entregas contado): transferencia y efectivo.
  static const valuesFaseContado = [transferencia, efectivo];

  static String labelEs(String code) {
    switch (code.trim()) {
      case pagoMovil:
        return 'Pago Móvil';
      case zelleDivisas:
        return 'Zelle';
      case transferencia:
        return 'Transferencia';
      case binance:
        return 'Binance';
      case efectivo:
        return 'Efectivo';
      case creditoSistema:
        return 'Crédito del sistema (legado)';
      default:
        return code;
    }
  }
}

/// Método de pago del aliado (`transaction_requests.pago_metodo`).
/// MotoConecta ofrece los medios en [valuesMotoconecta]; plazos y cuotas se acuerdan
/// con el importador en el chat del pedido.
abstract final class PagoMetodo {
  static const pagoMovil = 'pago_movil';
  static const zelleDivisas = 'zelle_divisas';
  static const transferencia = 'transferencia';
  static const binance = 'binance';
  static const usdt = 'usdt';
  static const efectivo = 'efectivo';

  /// Legado: línea MotoLink en plataforma (pedidos históricos; ya no se ofrece en UI nueva).
  static const creditoSistema = 'credito_sistema';

  /// Métodos estándar que puede ofrecer un importador.
  static const valuesMotoconecta = [
    zelleDivisas,
    pagoMovil,
    binance,
    usdt,
    transferencia,
    efectivo,
  ];

  /// Métodos que activan el % `usd_payment_discount_pct` del producto al registrar pago.
  static const valuesUsdDiscount = [
    zelleDivisas,
    binance,
    usdt,
    efectivo,
  ];

  static const values = [
    pagoMovil,
    zelleDivisas,
    transferencia,
    efectivo,
    binance,
    usdt,
  ];

  static bool qualifiesForUsdDiscount(String? metodo) {
    final m = metodo?.trim();
    if (m == null || m.isEmpty) return false;
    return valuesUsdDiscount.contains(m);
  }

  static List<String> filterByImporterAccepted(List<String>? accepted) {
    if (accepted == null || accepted.isEmpty) {
      return List<String>.from(valuesMotoconecta);
    }
    final allowed = accepted.map((e) => e.trim()).where((e) => e.isNotEmpty);
    return valuesMotoconecta.where(allowed.contains).toList();
  }

  static String labelEs(String code) {
    switch (code.trim()) {
      case pagoMovil:
        return 'Pago Móvil';
      case zelleDivisas:
        return 'Zelle / divisas';
      case transferencia:
        return 'Transferencia';
      case binance:
        return 'Binance';
      case usdt:
        return 'USDT';
      case efectivo:
        return 'Efectivo';
      case creditoSistema:
        return 'Crédito del sistema (legado)';
      default:
        return code;
    }
  }
}

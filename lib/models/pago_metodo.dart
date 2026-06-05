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

  /// Métodos en bolívares (Bs) que se deshabilitan en modo «solo divisas».
  static const valuesBolivares = [
    pagoMovil,
    transferencia,
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

  static bool isBolivares(String? metodo) {
    final m = metodo?.trim();
    if (m == null || m.isEmpty) return false;
    return valuesBolivares.contains(m);
  }

  static List<String> filterByImporterAccepted(
    List<String>? accepted, {
    bool pagoSoloDivisas = false,
  }) {
    var list = valuesMotoconecta;
    if (accepted != null && accepted.isNotEmpty) {
      final allowed = accepted.map((e) => e.trim()).where((e) => e.isNotEmpty);
      list = valuesMotoconecta.where(allowed.contains).toList();
    }
    if (pagoSoloDivisas) {
      list = list.where((m) => !isBolivares(m)).toList();
    }
    return List<String>.from(list);
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

  /// Guía para que el importador complete los datos de transferencia.
  static String instructionHintEs(String code) {
    switch (code.trim()) {
      case zelleDivisas:
        return 'Email Zelle: cuenta@correo.com\n'
            'Titular: Nombre Apellido\n'
            'Nota opcional (banco emisor, etc.)';
      case pagoMovil:
        return 'Banco: Banco de Venezuela\n'
            'Teléfono: 0414-1234567\n'
            'Cédula/RIF del titular: V-12.345.678';
      case transferencia:
        return 'Banco: Mercantil\n'
            'Tipo de cuenta: Corriente\n'
            'Número: 0105-...\n'
            'Titular: Razón social o nombre';
      case binance:
        return 'Binance ID o email: 123456789\n'
            'Titular: Nombre en la cuenta\n'
            'Red/moneda si aplica: USDT';
      case usdt:
        return 'Red: TRC20 (o ERC20)\n'
            'Wallet: Txxxxxxxx...\n'
            'Titular / nota: ...';
      case efectivo:
        return 'Dónde y cuándo entregar el efectivo\n'
            'Persona de contacto y teléfono';
      default:
        return 'Datos que el aliado necesita para realizar el pago';
    }
  }
}

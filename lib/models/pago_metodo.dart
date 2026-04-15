/// Método de pago del aliado (`transaction_requests.pago_metodo`).
abstract final class PagoMetodo {
  static const pagoMovil = 'pago_movil';
  static const zelleDivisas = 'zelle_divisas';
  static const transferencia = 'transferencia';

  static const values = [pagoMovil, zelleDivisas, transferencia];

  static String labelEs(String code) {
    switch (code.trim()) {
      case pagoMovil:
        return 'Pago Móvil';
      case zelleDivisas:
        return 'Zelle (divisas)';
      case transferencia:
        return 'Transferencia';
      default:
        return code;
    }
  }
}

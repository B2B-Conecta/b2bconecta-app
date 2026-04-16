/// Método de pago del aliado (`transaction_requests.pago_metodo`).
abstract final class PagoMetodo {
  static const pagoMovil = 'pago_movil';
  static const zelleDivisas = 'zelle_divisas';
  static const transferencia = 'transferencia';
  static const efectivo = 'efectivo';

  /// Línea de crédito MotoLink (solo tras fase contado y con cupo asignado).
  static const creditoSistema = 'credito_sistema';

  static const values = [pagoMovil, zelleDivisas, transferencia, efectivo];

  /// Fase contado (primeros N entregas): solo transferencia y efectivo.
  static const valuesFaseContado = [transferencia, efectivo];

  /// Post fase contado: métodos habituales + crédito del sistema (si aplica en UI).
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

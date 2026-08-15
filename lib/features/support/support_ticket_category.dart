/// Categorías de reclamo de soporte.
abstract final class SupportTicketCategory {
  static const cuenta = 'cuenta';
  static const pedido = 'pedido';
  static const pago = 'pago';
  static const kyc = 'kyc';
  static const plataforma = 'plataforma';
  static const otro = 'otro';

  static const all = [
    cuenta,
    pedido,
    pago,
    kyc,
    plataforma,
    otro,
  ];

  static String labelEs(String category) {
    switch (category.trim()) {
      case cuenta:
        return 'Cuenta';
      case pedido:
        return 'Pedido';
      case pago:
        return 'Pago';
      case kyc:
        return 'Verificación (KYC)';
      case plataforma:
        return 'Plataforma';
      case otro:
        return 'Otro';
      default:
        return category;
    }
  }
}

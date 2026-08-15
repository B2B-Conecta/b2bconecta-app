/// Cómo se paga el flete del transportista respecto a la factura del importador.
abstract final class CarrierFletePagoModo {
  static const incluidoFactura = 'incluido_factura';
  static const pagoSeparado = 'pago_separado';

  static const values = [incluidoFactura, pagoSeparado];

  static String labelEs(String? code) {
    switch (code?.trim()) {
      case incluidoFactura:
        return 'Incluido en la factura del importador';
      case pagoSeparado:
        return 'Pago separado al transportista';
      default:
        return 'Consultar con el importador';
    }
  }

  static String shortLabelEs(String? code) {
    switch (code?.trim()) {
      case incluidoFactura:
        return 'Flete en factura importador';
      case pagoSeparado:
        return 'Flete aparte';
      default:
        return 'Flete';
    }
  }
}

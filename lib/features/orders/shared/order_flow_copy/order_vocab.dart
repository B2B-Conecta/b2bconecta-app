/// Términos unificados en toda la app de pedidos (evitar mezclar proveedor/importador).
abstract final class OrderVocab {
  static const importador = 'importador';
  static const aliado = 'aliado';
  static const transportista = 'transportista';

  static const facturaImportador = 'Factura del importador';
  static const facturaFlete = 'Factura del flete';
  static const comprobantePago = 'Comprobante de pago';

  static const seccionPagoFactura = 'Pago y factura';
  static const seccionPagoFlete = 'Pago del flete';
  static const seccionChat = 'Mensajes del pedido';

  static const carrito = 'carrito';
  static const pedido = 'pedido';

  static const chipPagoPendiente = 'Pago pendiente';
}

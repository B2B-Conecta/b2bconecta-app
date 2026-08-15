/// Textos de ayuda (icono ℹ️) en fichas y secciones de pedido.
abstract final class OrderSectionHelp {
  static const aliadoKycCredit =
      'Use este expediente para evaluar solicitudes de crédito B2B con el aliado.';
  static const aliadoCancelPending =
      'Puede cancelar mientras el importador no haya adjuntado su factura. Motivo obligatorio.';
  static const adminAnularPedido =
      'Cierra el pedido en curso; requiere motivo. El inventario puede revertirse.';
  static const carritoMaestroAliado =
      'Un solo pedido en B2B Conecta: destino y productos compartidos. '
      'Elija un importador abajo para ver envío, factura y pago.';
  static const chatPedido =
      'Desde que el pedido está pendiente, aliado e importador pueden escribir aquí '
      '(cantidad, plazos y logística). B2B Conecta puede leer el hilo.';
  static const pagoAliadoMetodo =
      'Revise la factura, elija el método y adjunte el comprobante.';
  static const pagoAliadoArchivo =
      'Documentación archivada · solo consulta.';
  static const adminPreTransit =
      'La factura la emite el importador. Tras registrarla, el aliado puede declarar pago; '
      'en tránsito solo con factura cargada.';
  static const evidenciaPedido =
      'Archivos del pedido (conservados al cerrar). Abrir con enlace temporal.';
  static const cicloEnvioPago =
      'El comprobante y su aprobación quedan en el expediente de pago del aliado; '
      'no forman parte del cronograma de envío.';
  static const puntoRecoleccion =
      'Dirección donde se retira la mercancía del importador. '
      'Se confirma cuando el pedido está listo y el aliado definió el transporte.';
}

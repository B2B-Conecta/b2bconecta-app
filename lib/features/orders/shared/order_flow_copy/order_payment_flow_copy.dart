import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'order_vocab.dart';

/// Factura, comprobante, flete y estados de pago.
abstract final class OrderPaymentFlowCopy {
  // —— Factura (importador sube, aliado consulta) ——

  static const importadorFacturaTitulo = OrderVocab.facturaImportador;
  static const importadorFacturaTituloReferencia =
      '${OrderVocab.facturaImportador} (referencia)';

  static const importadorFacturaAyuda =
      'Adjunte PDF o imagen en preparación o al marcar listo para recolección. '
      'La necesitará antes de marcar «En tránsito».';
  static const importadorFacturaAyudaCompacta =
      'Adjunte o actualice el archivo antes de marcar «En tránsito».';
  static const importadorFacturaAyudaCarrito =
      'Un solo archivo para todo el carrito de este importador.';
  static const importadorFacturaSoloLectura = 'Archivo adjunto · solo consulta.';
  static const importadorFacturaExito = 'Factura del importador guardada.';
  static const importadorFacturaRegistrada = 'Factura registrada';

  static const aliadoEsperaFactura =
      'El importador aún no adjunta su factura. Cuando la suba, '
      'podrá registrar el pago en esta sección.';
  static const aliadoVerFactura = 'Ver factura del importador';

  static const bloqueoSinFacturaImportador =
      'Adjunte la factura del importador antes de marcar «En tránsito».';

  // —— Comprobante (aliado declara, importador verifica) ——

  static const importadorVerificarPagoTitulo = 'Comprobante del aliado';
  static const importadorRechazarComprobanteTitulo = 'Rechazar comprobante';
  static const importadorRechazarComprobanteMotivo = 'Motivo (opcional)';

  static String pagoEstadoLabel(String? estado) => switch (estado?.trim()) {
        PagoRevisionEstado.aprobado => 'Pago confirmado',
        PagoRevisionEstado.enRevision => 'En revisión',
        PagoRevisionEstado.rechazado => 'Comprobante rechazado',
        _ => 'Sin comprobante',
      };

  // —— Flete separado ——

  static const seccionFleteTitulo = OrderVocab.seccionPagoFlete;
  static const seccionFleteTituloLargo = 'Flete (pago al transportista)';
  static const importadorFleteAyuda =
      'Pago separado al transportista. Adjunte la factura del flete '
      'además de la del importador antes de «En tránsito».';
  static const bloqueoSinFacturaFlete =
      'Adjunte la factura del flete antes de marcar «En tránsito».';

  static const aliadoFleteInstruccion =
      'Pague al transportista según los datos indicados y adjunte el comprobante.';

  // —— Secciones colapsables (aliado) ——

  static const aliadoSeccionPagoSubtitulo =
      'Factura del importador y comprobante de pago';
  static const aliadoSeccionPagoInfo =
      'Revise la factura, elija el método y adjunte el comprobante. '
      'Las condiciones comerciales pueden acordarse en el chat del pedido.';

  // —— Moroso / pago pendiente ——

  static String morosoDetalleAliado(TransactionRequestModel r) {
    final impPend = r.pagoImportadorPendienteTrasEntrega;
    final fletePend = r.pagoFletePendienteTrasEntrega;

    if (impPend && fletePend) {
      return 'Faltan dos pagos: comprobante de la factura del importador y '
          'pago del flete al transportista. Complételos en las secciones indicadas.';
    }
    if (fletePend) {
      if (!r.hasFleteComprobantePago) {
        return 'Falta el comprobante del flete. Regístrelo en «${OrderVocab.seccionPagoFlete}».';
      }
      if (r.fletePagoEstadoRevisionEfectivo == PagoRevisionEstado.enRevision) {
        return 'Comprobante del flete en revisión por el importador.';
      }
      if (r.fletePagoEstadoRevisionEfectivo == PagoRevisionEstado.rechazado) {
        return 'Comprobante del flete rechazado. Adjunte uno nuevo en '
            '«${OrderVocab.seccionPagoFlete}».';
      }
      return 'Pago del flete pendiente de confirmación por el importador.';
    }
    if (!r.hasProveedorFactura) {
      return 'Pedido recibido. Cuando el importador adjunte su factura, '
          'registre su comprobante en «${OrderVocab.seccionPagoFactura}».';
    }
    return 'Pago pendiente de aprobación. Revise o actualice su comprobante '
        'en «${OrderVocab.seccionPagoFactura}».';
  }

  static String morosoDetalleImportador(TransactionRequestModel r) {
    final impPend = r.pagoImportadorPendienteTrasEntrega;
    final fletePend = r.pagoFletePendienteTrasEntrega;

    if (impPend && fletePend) {
      return 'Entregado con pagos pendientes: comprobante del aliado y pago del flete.';
    }
    if (fletePend) {
      return 'Entregado con pago del flete pendiente de su confirmación.';
    }
    if (!r.hasProveedorFactura) {
      return 'Entregado sin pago aprobado. Falta factura o comprobante del aliado.';
    }
    return 'Revise el comprobante del aliado en la sección de pago.';
  }
}

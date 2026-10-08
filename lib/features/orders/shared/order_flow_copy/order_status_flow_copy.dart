import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'order_vocab.dart';

/// Etiquetas de estado, titulares y botones de avance del ciclo del pedido.
abstract final class OrderStatusFlowCopy {
  static String labelEs(String status) => switch (status) {
        TransactionRequestStatus.pendiente => 'Nuevo · en revisión',
        TransactionRequestStatus.aprobadoAdmin => 'Aprobado por B2B Conecta',
        TransactionRequestStatus.rechazado => 'Cancelado o rechazado',
        TransactionRequestStatus.enPreparacion => 'En preparación',
        TransactionRequestStatus.pedidoListo => 'Listo para recolección',
        TransactionRequestStatus.enTransito => 'En tránsito',
        TransactionRequestStatus.enviado => 'En tránsito',
        TransactionRequestStatus.entregado => 'Entregado',
        _ => status,
      };

  static String importerFilterLabelEs(String status) =>
      status == TransactionRequestStatus.pendiente
          ? 'Pedido nuevo'
          : labelEs(status);

  static String actionLabelForNext(String nextStatus) => switch (nextStatus) {
        TransactionRequestStatus.enPreparacion => 'Marcar en preparación',
        TransactionRequestStatus.pedidoListo => 'Marcar listo para recolección',
        TransactionRequestStatus.enTransito => 'Marcar en tránsito',
        TransactionRequestStatus.enviado => 'Marcar en tránsito',
        TransactionRequestStatus.entregado => 'Confirmar recepción en su taller',
        _ => 'Avanzar pedido',
      };

  static String importerAdvanceButtonLabel(
    String nextStatus, {
    bool checkoutGroup = false,
  }) {
    if (!checkoutGroup) return actionLabelForNext(nextStatus);
    return switch (nextStatus) {
      TransactionRequestStatus.enPreparacion => 'Preparar carrito',
      TransactionRequestStatus.pedidoListo => 'Listo para recolección',
      TransactionRequestStatus.enTransito => 'Despachar carrito',
      _ => actionLabelForNext(nextStatus),
    };
  }

  static String importerOperationalHeadline(String status) => switch (status) {
        TransactionRequestStatus.entregado => 'Pedido cerrado',
        TransactionRequestStatus.rechazado => '—',
        TransactionRequestStatus.pedidoListo =>
          'Listo para recolección · transporte y punto de retiro',
        TransactionRequestStatus.enTransito ||
        TransactionRequestStatus.enviado =>
          'En tránsito · la tienda minorista confirma la recepción',
        TransactionRequestStatus.enPreparacion => 'En preparación',
        TransactionRequestStatus.pendiente => 'Nuevo pedido',
        _ => 'Pedido activo',
      };

  static String aliadoTrackingHeadline(
    String status, {
    bool canceladoPorAliado = false,
    bool canceladoPorImportador = false,
    bool anuladoPorMotolink = false,
  }) =>
      switch (status) {
        TransactionRequestStatus.pendiente =>
          'Solicitud enviada · el importador la revisará',
        TransactionRequestStatus.enPreparacion =>
          'El importador prepara su pedido',
        TransactionRequestStatus.pedidoListo =>
          'Mercancía lista · defina el transporte',
        TransactionRequestStatus.enTransito ||
        TransactionRequestStatus.enviado =>
          'En camino · confirme al recibir en su taller',
        TransactionRequestStatus.entregado => 'Pedido completado',
        TransactionRequestStatus.rechazado => () {
          if (canceladoPorAliado) return 'Solicitud cancelada por usted';
          if (canceladoPorImportador) {
            return 'Pedido cancelado por el importador';
          }
          if (anuladoPorMotolink) return 'Pedido anulado por B2B Conecta';
          return 'Pedido rechazado';
        }(),
        _ => '—',
      };

  /// Sufijo en listas cuando hay pago pendiente tras entrega.
  static const morosoListSuffix = ' · ${OrderVocab.chipPagoPendiente}';

  /// Qué puede hacer ahora la tienda, visible sin abrir la ficha.
  static String aliadoCollapsedHint(String status) => switch (status) {
        TransactionRequestStatus.pendiente =>
          'El proveedor confirma el stock. Abra el detalle para ver el pedido o cancelarlo.',
        TransactionRequestStatus.enPreparacion =>
          'El proveedor prepara los productos. Abra el detalle para ver el avance.',
        TransactionRequestStatus.pedidoListo =>
          'La mercancía está lista. Abra el detalle para elegir el transporte.',
        TransactionRequestStatus.enTransito ||
        TransactionRequestStatus.enviado =>
          'Va en camino. Abra el detalle y confirme cuando lo reciba en el taller.',
        TransactionRequestStatus.entregado =>
          'Pedido recibido. En el detalle puede pagar, valorar o pedir una devolución.',
        TransactionRequestStatus.rechazado =>
          'Este pedido no sigue. Abra el detalle para ver el motivo.',
        _ => 'Abra el detalle para ver el seguimiento.',
      };

  /// Qué puede hacer ahora el proveedor, visible sin abrir la ficha.
  static String importerCollapsedHint(String status) => switch (status) {
        TransactionRequestStatus.pendiente =>
          'Revise el pedido y use el botón azul para pasarlo a preparación.',
        TransactionRequestStatus.enPreparacion =>
          'Cuando termine de alistar, use el botón azul para marcarlo listo.',
        TransactionRequestStatus.pedidoListo =>
          'En el detalle defina el retiro y luego márquelo en tránsito.',
        TransactionRequestStatus.enTransito ||
        TransactionRequestStatus.enviado =>
          'La tienda confirma la recepción. El detalle muestra la guía.',
        TransactionRequestStatus.entregado =>
          'Pedido cerrado. El detalle guarda la factura y el pago.',
        TransactionRequestStatus.rechazado =>
          'Este pedido no sigue. Abra el detalle para ver el motivo.',
        _ => 'Abra el detalle para continuar el pedido.',
      };
}

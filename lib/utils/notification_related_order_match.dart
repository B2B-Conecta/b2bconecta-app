import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import 'aliado_order_grouping.dart';

/// Filtro rápido sugerido en pedidos del importador al abrir una notificación.
enum ImporterPedidosQuickFilterHint {
  nuevos,
  enProceso,
  cerrados,
}

ImporterPedidosQuickFilterHint? importerPedidosQuickFilterForOrderStatus(
  String status,
) {
  switch (status) {
    case TransactionRequestStatus.pendiente:
      return ImporterPedidosQuickFilterHint.nuevos;
    case TransactionRequestStatus.enPreparacion:
    case TransactionRequestStatus.pedidoListo:
    case TransactionRequestStatus.enTransito:
    case TransactionRequestStatus.enviado:
      return ImporterPedidosQuickFilterHint.enProceso;
    case TransactionRequestStatus.entregado:
    case TransactionRequestStatus.rechazado:
      return ImporterPedidosQuickFilterHint.cerrados;
    default:
      return ImporterPedidosQuickFilterHint.enProceso;
  }
}

ImporterPedidosQuickFilterHint? importerPedidosQuickFilterForNotificationType(
  String type,
) {
  switch (type.trim()) {
    case 'pago':
      return ImporterPedidosQuickFilterHint.enProceso;
    case 'envio':
      return ImporterPedidosQuickFilterHint.nuevos;
    case 'morosidad':
      return ImporterPedidosQuickFilterHint.cerrados;
    default:
      return null;
  }
}

/// Coincide `related_id` de notificación con un pedido (id o `checkout_group_id`).
bool transactionRequestMatchesNotificationRelatedId(
  TransactionRequestModel request,
  String relatedId,
) {
  final needle = relatedId.trim();
  if (needle.isEmpty) return false;
  if (request.id == needle) return true;
  final cg = request.checkoutGroupId?.trim();
  return cg != null && cg.isNotEmpty && cg == needle;
}

/// Admin: clave de expansión alineada con agrupación por carrito.
String? adminExpandRequestIdForNotification(
  List<TransactionRequestModel> rows,
  String relatedId,
) => orderExpandKeyForNotification(rows, relatedId);

/// Primera línea del listado que coincide con `related_id` (id o checkout).
TransactionRequestModel? findTransactionForNotificationRelatedId(
  List<TransactionRequestModel> rows,
  String relatedId,
) {
  for (final r in rows) {
    if (transactionRequestMatchesNotificationRelatedId(r, relatedId)) {
      return r;
    }
  }
  return null;
}

/// Aliado / importador: clave de expansión de tarjeta (grupo o línea).
String? orderExpandKeyForNotification(
  List<TransactionRequestModel> rows,
  String relatedId,
) {
  for (final g in groupAliadoOrdersByCheckout(rows)) {
    if (g.any((r) => transactionRequestMatchesNotificationRelatedId(r, relatedId))) {
      if (g.length == 1) return checkoutGroupExpandKey(g);
      final direct = g.where(
        (r) => r.id == relatedId.trim(),
      );
      if (direct.isNotEmpty) {
        return checkoutGroupExpandKey([direct.first]);
      }
      return checkoutGroupExpandKey(g);
    }
  }
  return null;
}

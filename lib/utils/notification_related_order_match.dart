import '../models/transaction_request_model.dart';
import 'aliado_order_grouping.dart';

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

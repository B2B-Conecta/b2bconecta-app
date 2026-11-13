import 'transaction_request_model.dart';

/// Clave de «1 pedido» en bandeja/badge: carrito (`checkout_group_id`) o línea suelta.
String checkoutOrderBucketKey({
  required String id,
  String? checkoutGroupId,
}) {
  final g = checkoutGroupId?.trim();
  if (g != null && g.isNotEmpty) return 'g:$g';
  return 'i:${id.trim()}';
}

/// Cuenta pedidos (no líneas) con la misma regla que [groupAliadoOrdersByCheckout].
int countDistinctCheckoutOrders(
  Iterable<({String id, String? checkoutGroupId})> rows,
) {
  final keys = <String>{};
  for (final r in rows) {
    final id = r.id.trim();
    if (id.isEmpty) continue;
    keys.add(
      checkoutOrderBucketKey(id: id, checkoutGroupId: r.checkoutGroupId),
    );
  }
  return keys.length;
}

/// Agrupa filas de `transaction_requests` que vienen del mismo checkout del carrito.
List<List<TransactionRequestModel>> groupAliadoOrdersByCheckout(
  List<TransactionRequestModel> flat,
) {
  if (flat.isEmpty) return const [];

  final buckets = <String, List<TransactionRequestModel>>{};
  final keyOrder = <String>[];

  for (final r in flat) {
    final key = checkoutOrderBucketKey(
      id: r.id,
      checkoutGroupId: r.checkoutGroupId,
    );
    if (!buckets.containsKey(key)) {
      keyOrder.add(key);
      buckets[key] = <TransactionRequestModel>[];
    }
    buckets[key]!.add(r);
  }

  return keyOrder.map((k) {
    final list = buckets[k]!;
    list.sort((a, b) {
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return ca.compareTo(cb);
    });
    return list;
  }).toList();
}

/// Dentro de un mismo carrito, agrupa líneas por importador (`owner_id`).
List<List<TransactionRequestModel>> groupCheckoutLinesByImportador(
  List<TransactionRequestModel> lines,
) {
  if (lines.isEmpty) return const [];

  final byImp = <String, List<TransactionRequestModel>>{};
  final order = <String>[];

  for (final r in lines) {
    final k = r.ownerId.trim();
    if (k.isEmpty) continue;
    if (!byImp.containsKey(k)) {
      order.add(k);
      byImp[k] = <TransactionRequestModel>[];
    }
    byImp[k]!.add(r);
  }

  return order.map((k) => byImp[k]!).toList();
}

/// Clave estable para expandir / animaciones (un grupo o un pedido suelto).
String checkoutGroupExpandKey(List<TransactionRequestModel> group) {
  if (group.isEmpty) return '';
  return checkoutOrderBucketKey(
    id: group.first.id,
    checkoutGroupId: group.first.checkoutGroupId,
  );
}

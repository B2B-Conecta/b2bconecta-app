import '../models/transaction_request_model.dart';

/// Agrupa filas de `transaction_requests` que vienen del mismo checkout del carrito.
List<List<TransactionRequestModel>> groupAliadoOrdersByCheckout(
  List<TransactionRequestModel> flat,
) {
  if (flat.isEmpty) return const [];

  final buckets = <String, List<TransactionRequestModel>>{};
  final keyOrder = <String>[];

  for (final r in flat) {
    final g = r.checkoutGroupId?.trim();
    final key = (g != null && g.isNotEmpty) ? 'g:$g' : 'i:${r.id}';
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

/// Clave estable para expandir / animaciones (un grupo o un pedido suelto).
String checkoutGroupExpandKey(List<TransactionRequestModel> group) {
  if (group.isEmpty) return '';
  final g = group.first.checkoutGroupId?.trim();
  if (g != null && g.isNotEmpty) return 'g:$g';
  return group.first.id;
}

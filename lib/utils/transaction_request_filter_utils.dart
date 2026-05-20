import '../models/transaction_request_model.dart';

/// Filtrado local de solicitudes (búsqueda + estado opcional).
abstract final class TransactionRequestFilterUtils {
  TransactionRequestFilterUtils._();

  static bool matchesSearch(TransactionRequestModel r, String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String? x) => x != null && x.toLowerCase().contains(q);
    return has(r.productName) ||
        has(r.productSku) ||
        has(r.aliadoBusinessName) ||
        has(r.ownerBusinessName);
  }

  static List<TransactionRequestModel> apply(
    List<TransactionRequestModel> rows, {
    required String searchQuery,
    String? statusFilter,
    bool morosoOnly = false,
  }) {
    var list = rows.where((r) => matchesSearch(r, searchQuery)).toList();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      list = list.where((r) => r.status == statusFilter).toList();
    }
    if (morosoOnly) {
      list = list.where((r) => r.esPedidoMoroso).toList();
    }
    return list;
  }
}

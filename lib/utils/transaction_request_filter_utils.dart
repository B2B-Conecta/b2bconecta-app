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

  static DateTime _dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Filtra por `created_at` (día calendario local, inclusive).
  static bool matchesDateRange(
    TransactionRequestModel r, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    if (dateFrom == null && dateTo == null) return true;
    final created = r.createdAt;
    if (created == null) return false;
    final day = _dateOnly(created);
    if (dateFrom != null && day.isBefore(_dateOnly(dateFrom))) return false;
    if (dateTo != null && day.isAfter(_dateOnly(dateTo))) return false;
    return true;
  }

  static List<TransactionRequestModel> apply(
    List<TransactionRequestModel> rows, {
    required String searchQuery,
    String? statusFilter,
    bool morosoOnly = false,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    var list = rows.where((r) => matchesSearch(r, searchQuery)).toList();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      list = list.where((r) => r.status == statusFilter).toList();
    }
    if (morosoOnly) {
      list = list.where((r) => r.esPedidoMoroso).toList();
    }
    if (dateFrom != null || dateTo != null) {
      list = list
          .where(
            (r) => matchesDateRange(
              r,
              dateFrom: dateFrom,
              dateTo: dateTo,
            ),
          )
          .toList();
    }
    return list;
  }
}

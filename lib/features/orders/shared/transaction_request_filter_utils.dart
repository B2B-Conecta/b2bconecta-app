import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'importer_order_date.dart';

/// Filtrado local de solicitudes (búsqueda + estado opcional).
abstract final class TransactionRequestFilterUtils {
  TransactionRequestFilterUtils._();

  static bool matchesSearch(TransactionRequestModel r, String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String? x) => x != null && x.toLowerCase().contains(q);
    final id = r.id.toLowerCase();
    final group = (r.checkoutGroupId ?? '').toLowerCase();
    final shortId = id.replaceAll('-', '');
    final shortGroup = group.replaceAll('-', '');
    final qCompact = q.replaceAll(RegExp(r'[#\s-]'), '');
    return has(r.productName) ||
        has(r.productSku) ||
        has(r.aliadoBusinessName) ||
        has(r.ownerBusinessName) ||
        has(r.aliadoRif) ||
        has(r.ownerRif) ||
        id.contains(q) ||
        group.contains(q) ||
        (qCompact.isNotEmpty &&
            (shortId.contains(qCompact) || shortGroup.contains(qCompact)));
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
    bool useOrderPanelDate = false,
  }) {
    var list = rows.where((r) => matchesSearch(r, searchQuery)).toList();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      list = list
          .where(
            (r) => TransactionRequestStatus.matchesStatusFilter(
              r.status,
              statusFilter,
            ),
          )
          .toList();
    }
    if (morosoOnly) {
      list = list.where((r) => r.esPedidoMoroso).toList();
    }
    if (dateFrom != null || dateTo != null) {
      list = list
          .where(
            (r) => useOrderPanelDate
                ? ImporterOrderDate.matchesDateRange(
                    r,
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                  )
                : matchesDateRange(
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

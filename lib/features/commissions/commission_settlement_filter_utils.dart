import 'commission_settlement_document_type.dart';
import 'commission_settlement_model.dart';

/// Alcance temporal por semana calendario (lunes–domingo).
enum CommissionSettlementWeekScope {
  current,
  previous,
}

/// Filtros locales sobre la lista de cortes cargada.
class CommissionSettlementFilters {
  const CommissionSettlementFilters({
    this.searchQuery = '',
    this.status,
    this.weekScope,
    this.documentType,
    this.importadorId,
  });

  final String searchQuery;
  /// `borrador` | `emitido` | `pagado` | `anulado` | `pago_revision`
  final String? status;
  final CommissionSettlementWeekScope? weekScope;
  final CommissionSettlementDocumentType? documentType;
  final String? importadorId;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      status != null ||
      weekScope != null ||
      documentType != null ||
      importadorId != null;

  CommissionSettlementFilters cleared() => const CommissionSettlementFilters();

  CommissionSettlementFilters copyWithSearch(String searchQuery) =>
      CommissionSettlementFilters(
        searchQuery: searchQuery,
        status: status,
        weekScope: weekScope,
        documentType: documentType,
        importadorId: importadorId,
      );

  CommissionSettlementFilters copyWithStatus(String? status) =>
      CommissionSettlementFilters(
        searchQuery: searchQuery,
        status: status,
        weekScope: weekScope,
        documentType: documentType,
        importadorId: importadorId,
      );

  CommissionSettlementFilters copyWithWeekScope(
    CommissionSettlementWeekScope? weekScope,
  ) =>
      CommissionSettlementFilters(
        searchQuery: searchQuery,
        status: status,
        weekScope: weekScope,
        documentType: documentType,
        importadorId: importadorId,
      );

  CommissionSettlementFilters copyWithDocumentType(
    CommissionSettlementDocumentType? documentType,
  ) =>
      CommissionSettlementFilters(
        searchQuery: searchQuery,
        status: status,
        weekScope: weekScope,
        documentType: documentType,
        importadorId: importadorId,
      );

  CommissionSettlementFilters copyWithImportadorId(String? importadorId) =>
      CommissionSettlementFilters(
        searchQuery: searchQuery,
        status: status,
        weekScope: weekScope,
        documentType: documentType,
        importadorId: importadorId,
      );
}

DateTime commissionSettlementDateOnly(DateTime d) =>
    DateTime(d.year, d.month, d.day);

DateTime commissionSettlementMondayOfWeek(DateTime d) {
  final local = commissionSettlementDateOnly(d);
  return local.subtract(Duration(days: local.weekday - DateTime.monday));
}

bool commissionSettlementSameDate(DateTime a, DateTime b) {
  final da = commissionSettlementDateOnly(a);
  final db = commissionSettlementDateOnly(b);
  return da.year == db.year && da.month == db.month && da.day == db.day;
}

bool commissionSettlementMatchesWeekScope(
  CommissionSettlementModel row,
  CommissionSettlementWeekScope? scope,
  DateTime now,
) {
  if (scope == null) return true;
  final monday = commissionSettlementMondayOfWeek(now);
  final target = scope == CommissionSettlementWeekScope.current
      ? monday
      : monday.subtract(const Duration(days: 7));
  return commissionSettlementSameDate(row.periodStart, target);
}

bool commissionSettlementMatchesSearch(
  CommissionSettlementModel row,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final haystack = [
    row.importadorBusinessName,
    row.importadorRif,
    row.invoiceReference,
  ].whereType<String>().join(' ').toLowerCase();
  return haystack.contains(q);
}

bool commissionSettlementMatchesStatus(
  CommissionSettlementModel row,
  String? status,
) {
  if (status == null) return true;
  if (status == 'pago_revision') {
    return row.isEmitido && row.pagoEnRevision;
  }
  return row.status == status;
}

bool commissionSettlementMatchesDocumentType(
  CommissionSettlementModel row,
  CommissionSettlementDocumentType? documentType,
) {
  if (documentType == null) return true;
  if (row.isBorrador || row.isAnulado) return false;
  return row.documentTypeEffective == documentType;
}

bool commissionSettlementMatchesImportador(
  CommissionSettlementModel row,
  String? importadorId,
) {
  if (importadorId == null || importadorId.trim().isEmpty) return true;
  return row.importadorId == importadorId;
}

List<CommissionSettlementModel> filterCommissionSettlements(
  List<CommissionSettlementModel> rows,
  CommissionSettlementFilters filters, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  return rows.where((row) {
    if (!commissionSettlementMatchesSearch(row, filters.searchQuery)) {
      return false;
    }
    if (!commissionSettlementMatchesStatus(row, filters.status)) {
      return false;
    }
    if (!commissionSettlementMatchesWeekScope(row, filters.weekScope, clock)) {
      return false;
    }
    if (!commissionSettlementMatchesDocumentType(row, filters.documentType)) {
      return false;
    }
    if (!commissionSettlementMatchesImportador(row, filters.importadorId)) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

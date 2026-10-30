/// Estado editable del panel de filtros de pedidos del aliado.
class AliadoPedidosFiltersDraft {
  const AliadoPedidosFiltersDraft({
    this.statusFilter,
    this.morosoOnly = false,
    this.creditOnly = false,
    this.replacementOnly = false,
    this.dateFrom,
    this.dateTo,
  });

  /// `transaction_requests.status`; `null` = todos.
  final String? statusFilter;
  final bool morosoOnly;
  final bool creditOnly;
  final bool replacementOnly;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get hasStatusFilter =>
      statusFilter != null && statusFilter!.trim().isNotEmpty;

  bool get hasDateFilter => dateFrom != null || dateTo != null;

  bool get hasAnyPanelFilter =>
      hasStatusFilter ||
      morosoOnly ||
      hasDateFilter ||
      creditOnly ||
      replacementOnly;

  int get activePanelFilterCount {
    var n = 0;
    if (hasStatusFilter) n++;
    if (morosoOnly) n++;
    if (hasDateFilter) n++;
    if (creditOnly) n++;
    if (replacementOnly) n++;
    return n;
  }
}

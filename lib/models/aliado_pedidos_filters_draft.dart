/// Estado editable del panel de filtros de pedidos del aliado.
class AliadoPedidosFiltersDraft {
  const AliadoPedidosFiltersDraft({
    this.statusFilter,
    this.morosoOnly = false,
    this.dateFrom,
    this.dateTo,
  });

  /// `transaction_requests.status`; `null` = todos.
  final String? statusFilter;
  final bool morosoOnly;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get hasStatusFilter =>
      statusFilter != null && statusFilter!.trim().isNotEmpty;

  bool get hasDateFilter => dateFrom != null || dateTo != null;

  bool get hasAnyPanelFilter => hasStatusFilter || morosoOnly || hasDateFilter;

  int get activePanelFilterCount {
    var n = 0;
    if (hasStatusFilter) n++;
    if (morosoOnly) n++;
    if (hasDateFilter) n++;
    return n;
  }
}

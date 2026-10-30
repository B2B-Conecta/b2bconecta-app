/// Filtros del panel de pedidos (importador y admin).
class ImporterPedidosFiltersDraft {
  const ImporterPedidosFiltersDraft({
    this.dateFrom,
    this.dateTo,
    this.morosoOnly = false,
    this.creditOnly = false,
    this.replacementOnly = false,
    this.onlyNuevos = false,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool morosoOnly;
  final bool creditOnly;
  final bool replacementOnly;

  /// Solo pedidos en estado pendiente (importador).
  final bool onlyNuevos;

  bool get hasDateFilter => dateFrom != null || dateTo != null;

  bool get hasAnyPanelFilter =>
      hasDateFilter ||
      morosoOnly ||
      creditOnly ||
      replacementOnly ||
      onlyNuevos;

  int get activePanelFilterCount {
    var n = 0;
    if (hasDateFilter) n++;
    if (morosoOnly) n++;
    if (creditOnly) n++;
    if (replacementOnly) n++;
    if (onlyNuevos) n++;
    return n;
  }
}

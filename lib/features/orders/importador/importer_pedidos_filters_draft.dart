/// Filtros del panel de pedidos del importador (fecha de cierre / activo).
class ImporterPedidosFiltersDraft {
  const ImporterPedidosFiltersDraft({
    this.dateFrom,
    this.dateTo,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;

  bool get hasDateFilter => dateFrom != null || dateTo != null;
}

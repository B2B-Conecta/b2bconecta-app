/// Pedido rechazado: la cantidad solicitada supera el inventario disponible.
class StockInsufficientException implements Exception {
  StockInsufficientException(this.message);

  final String message;

  @override
  String toString() => message;
}

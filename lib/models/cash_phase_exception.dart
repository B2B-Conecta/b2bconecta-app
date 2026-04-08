/// Pedido bloqueado por la regla de un solo pedido activo en fase “primeros contado”.
class CashPhaseException implements Exception {
  CashPhaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

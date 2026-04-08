/// Pedido rechazado por política de `credit_limit` o perfil sin cupo asignado.
class CreditLimitException implements Exception {
  CreditLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

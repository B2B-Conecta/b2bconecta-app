/// Cuenta aliado: MotoLink suspendió nuevos pedidos por morosidad.
class PedidosSuspendidosMorosidadException implements Exception {
  PedidosSuspendidosMorosidadException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'transaction_request_status.dart';

/// Plazo para registrar una devolución o una queja.
///
/// Solo con el pedido `entregado`, durante 7 días desde la entrega
/// (`at_entregado`). Si esa fecha no existe, se usa `updated_at`.
abstract final class OrderReturnRules {
  static const window = Duration(days: 7);

  static const closedHint =
      'El plazo de 7 días para una devolución o una queja terminó.';

  static DateTime? anchor({
    DateTime? deliveredAt,
    DateTime? updatedAt,
  }) =>
      deliveredAt ?? updatedAt;

  static bool isAvailable({
    required String status,
    required DateTime? updatedAt,
    DateTime? deliveredAt,
    DateTime? now,
  }) {
    if (status != TransactionRequestStatus.entregado) return false;
    final at = anchor(deliveredAt: deliveredAt, updatedAt: updatedAt);
    if (at == null) return false;
    final clock = (now ?? DateTime.now()).toUtc();
    final start = at.toUtc();
    if (clock.isBefore(start)) return false;
    return clock.difference(start) <= window;
  }

  static DateTime? availableUntil({
    DateTime? deliveredAt,
    DateTime? updatedAt,
  }) {
    final at = anchor(deliveredAt: deliveredAt, updatedAt: updatedAt);
    if (at == null) return null;
    return at.toUtc().add(window);
  }
}

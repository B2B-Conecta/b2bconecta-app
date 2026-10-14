import 'transaction_request_status.dart';

/// Plazo para registrar una devolución o una queja.
///
/// Solo con el pedido `entregado`, durante 7 días desde la entrega
/// (`at_entregado`). Si esa fecha no existe, se usa `updated_at`.
abstract final class OrderReturnRules {
  static const window = Duration(days: 7);

  static const closedHint =
      'El plazo de 7 días para una devolución o una queja terminó.';

  static const receptionConfirmedHint =
      'Recepción confirmada. El pedido queda registrado. Durante 7 días puede pedir una devolución o presentar una queja desde el detalle.';

  static const receptionConfirmedPagoPendienteHint =
      'Recepción registrada. La mercancía queda como entregada. Durante 7 días puede pedir una devolución o presentar una queja desde el detalle. El comprobante de pago sigue pendiente de registrar o aprobar por B2B Conecta.';

  static const openHint =
      'Si un producto tuvo un inconveniente, regístrelo aquí. El plazo es de 7 días desde la recepción y el pedido sigue entregado.';

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

  /// Unidades del producto que presentaron el inconveniente, entre 1 y la línea.
  static int clampAffectedQty(int requested, int lineQty) {
    final maxQty = lineQty < 1 ? 1 : lineQty;
    if (requested < 1) return 1;
    if (requested > maxQty) return maxQty;
    return requested;
  }

  /// Crédito REF de las unidades afectadas. Usa el precio de la tienda.
  static double creditAmount({
    required double unitPrice,
    required double lineTotal,
    required int lineQty,
    required int affectedQty,
  }) {
    final qty = clampAffectedQty(affectedQty, lineQty);
    final unit = unitPrice > 0
        ? unitPrice
        : (lineQty > 0 ? lineTotal / lineQty : lineTotal);
    if (unit <= 0) return 0;
    return double.parse((unit * qty).toStringAsFixed(4));
  }
}

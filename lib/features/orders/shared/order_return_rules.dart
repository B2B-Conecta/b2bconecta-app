import 'transaction_request_status.dart';

/// Cuándo se ofrece el botón Devoluciones.
///
/// Visible solo si el pedido está `entregado` y no pasaron más de [window]
/// desde `transaction_requests.updated_at`. No hay una fecha propia de entrega:
/// `updated_at` es la última modificación del pedido, así que el plazo es
/// aproximado hasta que exista `entregado_at`.
///
/// Oculto en cualquier otro estado, incluido `rechazado` y los pedidos en curso.
abstract final class OrderReturnRules {
  static const window = Duration(days: 7);

  static bool isAvailable({
    required String status,
    required DateTime? updatedAt,
    DateTime? now,
  }) {
    if (status != TransactionRequestStatus.entregado) return false;
    if (updatedAt == null) return false;
    final clock = (now ?? DateTime.now()).toUtc();
    final at = updatedAt.toUtc();
    if (clock.isBefore(at)) return false;
    return clock.difference(at) <= window;
  }

  static DateTime? availableUntil(DateTime? updatedAt) {
    if (updatedAt == null) return null;
    return updatedAt.toUtc().add(window);
  }
}

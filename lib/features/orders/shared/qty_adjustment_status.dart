/// Estados de la propuesta formal de ajuste de cantidad (`transaction_requests.qty_adjustment_status`).
abstract final class QtyAdjustmentStatus {
  static const pendienteAliado = 'pendiente_aliado';
  static const aceptado = 'aceptado';
  static const rechazado = 'rechazado';
}

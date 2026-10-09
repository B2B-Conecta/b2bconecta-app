import 'transaction_request_model.dart';
import 'transaction_request_status.dart';

/// Tras marcar recibido, tienda y proveedor siguen pudiendo escribir.
const orderChatAfterDelivery = Duration(days: 7);

const orderChatDeliveryGraceHint =
    'El pedido ya se recibió. Este chat sigue abierto 7 días por si hay '
    'una observación. Puede escribir, y enviar fotos o video. '
    'La otra parte recibe un aviso.';

/// Chat abierto mientras el pedido sigue en curso, o hasta 7 días después
/// de recibido. Un pedido rechazado queda cerrado.
///
/// Sin fecha de entrega, un pedido recibido no se reabre.
bool orderChatReplyOpen(
  String status, {
  DateTime? deliveredAt,
  DateTime? updatedAt,
  DateTime? now,
}) {
  if (status == TransactionRequestStatus.rechazado) return false;
  if (status != TransactionRequestStatus.entregado) return true;
  final at = deliveredAt ?? updatedAt;
  if (at == null) return false;
  final clock = (now ?? DateTime.now()).toUtc();
  final start = at.toUtc();
  if (clock.isBefore(start)) return true;
  return clock.difference(start) <= orderChatAfterDelivery;
}

bool orderLinesAllowChatReply(
  Iterable<TransactionRequestModel> lines, {
  DateTime? now,
}) {
  return lines.any(
    (line) => orderChatReplyOpen(
      line.status,
      deliveredAt: line.atEntregado,
      updatedAt: line.updatedAt,
      now: now,
    ),
  );
}

/// Todas las líneas ya cerraron y al menos una sigue dentro de los 7 días.
bool orderLinesChatDeliveryGrace(
  Iterable<TransactionRequestModel> lines, {
  DateTime? now,
}) {
  final list = lines.toList();
  if (list.isEmpty || !orderLinesAllowChatReply(list, now: now)) return false;
  final anyDelivered = list.any(
    (line) => line.status == TransactionRequestStatus.entregado,
  );
  if (!anyDelivered) return false;
  return list.every(
    (line) =>
        line.status == TransactionRequestStatus.entregado ||
        line.status == TransactionRequestStatus.rechazado,
  );
}

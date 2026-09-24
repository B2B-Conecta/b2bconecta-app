import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/notifications/in_app_notification_model.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

InAppNotificationModel _n({
  required String id,
  required String type,
  required bool isRead,
  String? relatedId,
}) {
  return InAppNotificationModel(
    id: id,
    userId: 'u1',
    title: 't',
    body: 'b',
    type: type,
    isRead: isRead,
    createdAt: DateTime.utc(2026, 9, 23),
    relatedId: relatedId,
  );
}

void main() {
  test('unread mensaje count matches related order ids', () {
    final items = [
      _n(id: '1', type: 'mensaje', isRead: false, relatedId: 'ord-a'),
      _n(id: '2', type: 'mensaje', isRead: false, relatedId: 'ord-b'),
      _n(id: '3', type: 'mensaje', isRead: true, relatedId: 'ord-a'),
      _n(id: '4', type: 'pedido', isRead: false, relatedId: 'ord-a'),
    ];
    expect(
      NotificationProvider.unreadMensajeCount(
        items: items,
        relatedIds: ['ord-a', 'ord-c'],
      ),
      1,
    );
    expect(
      NotificationProvider.unreadMensajeCount(
        items: items,
        relatedIds: ['ord-a', 'ord-b'],
      ),
      2,
    );
  });

  test('order chat replies stay open until delivered or rejected', () {
    expect(orderChatReplyOpen(TransactionRequestStatus.pendiente), isTrue);
    expect(orderChatReplyOpen(TransactionRequestStatus.enTransito), isTrue);
    expect(orderChatReplyOpen(TransactionRequestStatus.entregado), isFalse);
    expect(orderChatReplyOpen(TransactionRequestStatus.rechazado), isFalse);
  });
}

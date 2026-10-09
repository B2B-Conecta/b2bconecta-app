import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/notifications/in_app_notification_model.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/widgets/messages_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_inbox_sheet.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_thread.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

TransactionRequestModel _order({
  required String id,
  String ownerId = 'imp-1',
  String? checkoutGroupId,
  String status = TransactionRequestStatus.pendiente,
  String? productName,
  String? sku,
  String? importerName,
  String? aliadoName,
  DateTime? updatedAt,
  DateTime? atEntregado,
}) {
  return TransactionRequestModel(
    id: id,
    aliadoId: 'aliado-1',
    productId: 'p-$id',
    ownerId: ownerId,
    status: status,
    cantidad: 1,
    precioUnitarioProveedor: 1,
    precioUnitarioAliado: 1,
    precioTotal: 1,
    precioBaseAliadoTotal: 1,
    checkoutGroupId: checkoutGroupId,
    productName: productName,
    productSku: sku,
    ownerBusinessName: importerName,
    aliadoBusinessName: aliadoName,
    updatedAt: updatedAt,
    atEntregado: atEntregado,
  );
}

void main() {
  test('groups checkout lines by importer into separate threads', () {
    final orders = [
      _order(
        id: 'a',
        checkoutGroupId: 'g1',
        ownerId: 'imp-a',
        productName: 'Cadena',
        importerName: 'Delta',
        aliadoName: 'Taller Ruices',
      ),
      _order(
        id: 'b',
        checkoutGroupId: 'g1',
        ownerId: 'imp-b',
        productName: 'Aceite',
        importerName: 'Cúcuta',
        aliadoName: 'Taller Ruices',
      ),
    ];
    final threads = orderChatThreadsFromOrders(
      orders,
      role: AppHomeRole.aliado,
    );
    expect(threads, hasLength(2));
    expect(threads.map((t) => t.counterpartName), containsAll(['Delta', 'Cúcuta']));
    expect(threads.first.requestIds, isNotEmpty);
  });

  test('filter keeps active, closed, unread and search', () {
    const active = OrderChatThread(
      primaryRequestId: '1',
      requestIds: ['1'],
      title: 'Cadena DID',
      counterpartName: 'Delta',
      status: TransactionRequestStatus.pendiente,
      statusLabel: 'Pendiente',
      canReply: true,
      productSku: 'DID-428',
    );
    const closed = OrderChatThread(
      primaryRequestId: '2',
      requestIds: ['2'],
      title: 'Aceite',
      counterpartName: 'Cúcuta',
      status: TransactionRequestStatus.entregado,
      statusLabel: 'Entregado',
      canReply: false,
    );
    int unreadFor(List<String> ids) => ids.contains('1') ? 2 : 0;

    expect(
      filterOrderChatThreads(
        threads: [active, closed],
        query: '',
        filter: OrderChatInboxFilter.active,
        unreadFor: unreadFor,
      ).map((t) => t.primaryRequestId),
      ['1'],
    );
    expect(
      filterOrderChatThreads(
        threads: [active, closed],
        query: '',
        filter: OrderChatInboxFilter.closed,
        unreadFor: unreadFor,
      ).map((t) => t.primaryRequestId),
      ['2'],
    );
    expect(
      filterOrderChatThreads(
        threads: [active, closed],
        query: '',
        filter: OrderChatInboxFilter.unread,
        unreadFor: unreadFor,
      ).single.primaryRequestId,
      '1',
    );
    expect(
      filterOrderChatThreads(
        threads: [active, closed],
        query: 'did-428',
        filter: OrderChatInboxFilter.all,
        unreadFor: unreadFor,
      ).single.title,
      'Cadena DID',
    );
  });

  test('admin counterpart includes retailer and importer', () {
    final threads = orderChatThreadsFromOrders(
      [
        _order(
          id: 'x',
          productName: 'Kit',
          importerName: 'Delta',
          aliadoName: 'Taller Ruices',
        ),
      ],
      role: AppHomeRole.administrador,
    );
    expect(threads.single.counterpartName, 'Taller Ruices · Delta');
    expect(threads.single.canReply, isTrue);
  });

  test('closed order cannot reply for retailer or importer', () {
    final threads = orderChatThreadsFromOrders(
      [
        _order(
          id: 'z',
          status: TransactionRequestStatus.entregado,
          productName: 'Kit',
        ),
      ],
      role: AppHomeRole.importador,
    );
    expect(threads.single.canReply, isFalse);
    expect(orderChatReplyOpen(TransactionRequestStatus.entregado), isFalse);
  });

  test('recibido hace menos de 7 días sigue abierto para el proveedor', () {
    final threads = orderChatThreadsFromOrders(
      [
        _order(
          id: 'z',
          status: TransactionRequestStatus.entregado,
          productName: 'Kit',
          atEntregado: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        ),
      ],
      role: AppHomeRole.importador,
    );
    expect(threads.single.canReply, isTrue);
    expect(threads.single.inDeliveryGrace, isTrue);
  });

  testWidgets('messages button is visible for authenticated header action',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesIconButton(onPressed: () => opened = true),
        ),
      ),
    );
    expect(find.byTooltip('Mensajes'), findsOneWidget);
    await tester.tap(find.byTooltip('Mensajes'));
    expect(opened, isTrue);
  });

  testWidgets('app bar hides messages when callback is absent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: MotolinkAppBar()),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Mensajes'), findsNothing);
  });

  testWidgets('app bar shows messages when authenticated callback is set',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: MotolinkAppBar(onMessagesTap: () => opened = true),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Mensajes'), findsOneWidget);
    await tester.tap(find.byTooltip('Mensajes'));
    expect(opened, isTrue);
  });

  testWidgets('inbox shows empty copy when there are no orders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderChatInboxSheet(
            homeRole: AppHomeRole.aliado,
            hasSession: () => true,
            fetchOrders: () async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin conversaciones'), findsOneWidget);
    expect(find.textContaining('cuando hay un pedido'), findsOneWidget);
  });

  testWidgets('inbox shows session expired when signed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderChatInboxSheet(
            homeRole: AppHomeRole.aliado,
            hasSession: () => false,
            fetchOrders: () async => throw StateError('should not fetch'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sesión vencida'), findsOneWidget);
    expect(find.byTooltip('Mensajes'), findsNothing);
  });

  testWidgets('inbox lists an order thread for the signed-in user',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderChatInboxSheet(
            homeRole: AppHomeRole.aliado,
            hasSession: () => true,
            fetchOrders: () async => [
              _order(
                id: 'ord-1',
                productName: 'Cadena DID 428',
                importerName: 'Repuestos Delta',
                status: TransactionRequestStatus.pendiente,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cadena DID 428'), findsOneWidget);
    expect(find.textContaining('Repuestos Delta'), findsOneWidget);
  });

  test('reply flags follow role and active order', () {
    const openThread = OrderChatThread(
      primaryRequestId: '1',
      requestIds: ['1'],
      title: 'Kit',
      counterpartName: 'Delta',
      status: TransactionRequestStatus.pendiente,
      statusLabel: 'Pendiente',
      canReply: true,
    );
    const closedThread = OrderChatThread(
      primaryRequestId: '2',
      requestIds: ['2'],
      title: 'Kit',
      counterpartName: 'Delta',
      status: TransactionRequestStatus.entregado,
      statusLabel: 'Entregado',
      canReply: false,
    );
    expect(
      orderChatInboxReplyFlags(role: AppHomeRole.aliado, thread: openThread),
      (aliado: true, admin: false, importador: false),
    );
    expect(
      orderChatInboxReplyFlags(role: AppHomeRole.importador, thread: closedThread),
      (aliado: false, admin: false, importador: false),
    );
    expect(
      orderChatInboxReplyFlags(
        role: AppHomeRole.administrador,
        thread: closedThread,
      ),
      (aliado: false, admin: true, importador: false),
    );
  });

  test('unread chat count ignores non-mensaje notifications', () {
    final items = [
      InAppNotificationModel(
        id: '1',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 'mensaje',
        isRead: false,
        createdAt: DateTime.utc(2026, 9, 28),
        relatedId: 'ord-1',
      ),
      InAppNotificationModel(
        id: '2',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 'pedido',
        isRead: false,
        createdAt: DateTime.utc(2026, 9, 28),
        relatedId: 'ord-1',
      ),
    ];
    expect(
      NotificationProvider.unreadMensajeCount(
        items: items,
        relatedIds: ['ord-1'],
      ),
      1,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';
import 'package:motolink_pro_app/features/orders/shared/mobile_chat_widgets.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_inbox_sheet.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_thread.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

const order = TransactionRequestModel(
    id: 'order-123456',
    aliadoId: 'ally',
    productId: 'part',
    ownerId: 'supplier',
    status: 'en_transito',
    cantidad: 5,
    precioUnitarioProveedor: 10,
    precioUnitarioAliado: 10,
    precioTotal: 50,
    precioBaseAliadoTotal: 50,
    ownerBusinessName: 'Repuestos Delta Caracas C.A.',
    productName: 'Caucho Firestone delantero para moto 150 cc');

void main() {
  Future<void> pump(WidgetTester tester, Widget child,
      {double width = 390, double scale = 1, double keyboard = 0}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 844),
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: Scaffold(body: child))));
    await tester.pumpAndSettle();
  }

  for (final size in [(320.0, 1.6), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets(
        'inbox adapts to $size and keeps search, filters and consultation tab',
        (tester) async {
      await pump(
          tester,
          OrderChatInboxSheet(
              homeRole: AppHomeRole.aliado,
              asPage: true,
              hasSession: () => true,
              fetchOrders: () async => [order]),
          width: size.$1,
          scale: size.$2);
      expect(tester.takeException(), isNull);
      expect(find.text('Repuestos Delta Caracas C.A.'), findsOneWidget);
      expect(find.text('Filtros'), findsOneWidget);
      expect(find.byType(ChatBusinessAvatar),
          size.$1 < 768 ? findsOneWidget : findsNothing);
      expect(find.text('1 conversación'),
          size.$1 < 768 ? findsOneWidget : findsNothing);
      expect(find.text('B2B CONECTA'),
          size.$1 < 768 ? findsOneWidget : findsNothing);
      await tester.enterText(find.byType(TextField), 'no existe');
      await tester.pumpAndSettle();
      expect(find.text('Ningún chat coincide'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Limpiar filtros'));
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile keyboard leaves the inbox usable', (tester) async {
    await pump(
        tester,
        OrderChatInboxSheet(
            homeRole: AppHomeRole.aliado,
            asPage: true,
            hasSession: () => true,
            fetchOrders: () async => [order]),
        width: 320,
        keyboard: 300);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile blue bubbles have white text; desktop keeps its original colors',
      (tester) async {
    for (final mobile in [true, false]) {
      await pump(
          tester,
          ChatMessageBubble(
              mine: true,
              at: DateTime(2026, 11, 20, 10),
              mobileStyle: mobile,
              child: const Text('Gracias, quedo atento.')));
      final textContext = tester.element(find.text('Gracias, quedo atento.'));
      expect(DefaultTextStyle.of(textContext).style.color,
          mobile ? Colors.white : isNot(Colors.white));
      final background = tester
          .widget<DecoratedBox>(find
              .ancestor(
                  of: find.text('Gracias, quedo atento.'),
                  matching: find.byType(DecoratedBox))
              .first)
          .decoration as BoxDecoration;
      expect(background.color, mobile ? mobileChatBlue : isNot(mobileChatBlue));
    }
  });

  testWidgets(
      'order context keeps mixed status truth, real navigation and fits enlarged text',
      (tester) async {
    var opened = false;
    final thread = OrderChatThread(
        primaryRequestId: 'order',
        requestIds: const ['order'],
        title: order.productName!,
        counterpartName: 'Delta',
        status: 'mixed',
        statusLabel: 'Varios estados',
        canReply: true,
        lines: const [order]);
    await pump(tester,
        MobileOrderChatCard(thread: thread, onOpenOrder: () => opened = true),
        width: 320, scale: 1.6);
    expect(find.text('Varios estados'), findsOneWidget);
    await tester.tap(find.text('Ver pedido →'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}

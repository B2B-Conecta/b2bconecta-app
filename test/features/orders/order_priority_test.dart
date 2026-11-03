import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_entry.dart';
import 'package:motolink_pro_app/features/orders/shared/order_priority_controls.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'order_workspace_test.dart' show fixture;

void main() {
  test('pending groups keep all lines and retain stable ordering', () {
    final transit = [fixture('transit', status: 'en_transito')];
    final mixed = [
      fixture('pending'),
      fixture('ready', status: 'en_preparacion')
    ];
    final closed = [fixture('closed', status: 'entregado')];
    final pending = [fixture('other')];
    final result = prioritizePendingOrders([transit, mixed, closed, pending]);
    expect(result, [mixed, pending, transit, closed]);
    expect(result.first, same(mixed));
    expect(OrderListEntry(mixed).status, 'Varios estados');
    expect(OrderListEntry(pending).status, 'Esperando al proveedor');
    expect(OrderListEntry(pending, viewerRole: AppHomeRole.importador).status,
        'Por confirmar');
    expect(OrderListEntry(closed).awaitingConfirmation, isFalse);
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 1280.0]) {
      testWidgets('priority controls work at $width dark=$dark',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var pendingSelected = false;
        var pendingFirst = true;
        await tester.pumpWidget(MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
                body: OrderPriorityControls(
              scope: PedidosListScope.todos,
              onScope: (_) {},
              pendingOnly: false,
              pendingCount: 8,
              onPending: () => pendingSelected = true,
              pendingFirst: pendingFirst,
              onSort: (v) => pendingFirst = v,
            ))));
        await tester.tap(find.text('Por confirmar'));
        expect(pendingSelected, isTrue);
        expect(find.text('8'), findsOneWidget);
        await tester.tap(find.byTooltip('Ordenar pedidos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Orden habitual'));
        await tester.pumpAndSettle();
        expect(pendingFirst, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

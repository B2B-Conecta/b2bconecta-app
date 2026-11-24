import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/widgets/aliado_quick_filter.dart';
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
        await tester.tap(find.text('Por gestionar'));
        expect(pendingSelected, isTrue);
        expect(find.text('8'), findsOneWidget);
        await tester.tap(find.byTooltip('Ordenar pedidos'));
        await tester.pumpAndSettle();
        await tester.tap(
            find.widgetWithText(CheckedPopupMenuItem<bool>, 'Orden habitual'));
        await tester.pumpAndSettle();
        expect(pendingFirst, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('mobile uses catalog pills and keeps filter and sort actions',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var pendingOnly = false;
    var pendingFirst = true;
    var scope = PedidosListScope.todos;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return OrderPriorityControls(
            compact: true,
            scope: scope,
            onScope: (next) => setState(() {
              pendingOnly = false;
              scope = next;
            }),
            pendingOnly: pendingOnly,
            pendingCount: 19,
            onPending: () => setState(() => pendingOnly = true),
            pendingFirst: pendingFirst,
            onSort: (next) => setState(() => pendingFirst = next),
          );
        }),
      ),
    ));

    final all = find.widgetWithText(AliadoQuickFilterChip, 'Todos');
    final pending = find.widgetWithText(AliadoQuickFilterChip, 'Por gestionar');
    expect(tester.widget<AliadoQuickFilterChip>(all).selected, isTrue);
    expect(find.descendant(of: pending, matching: find.text('19')),
        findsOneWidget);
    await tester.tap(pending);
    await tester.pumpAndSettle();
    expect(tester.widget<AliadoQuickFilterChip>(all).selected, isFalse);
    expect(tester.widget<AliadoQuickFilterChip>(pending).selected, isTrue);

    final canceled = find.widgetWithText(AliadoQuickFilterChip, 'Cancelados');
    final filterRow = find.byType(AliadoQuickFilterRow);
    final scrollable = find.descendant(
      of: filterRow,
      matching: find.byType(Scrollable),
    );
    await tester.timedDrag(
        filterRow, const Offset(-240, 0), const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0));
    await tester.ensureVisible(canceled);
    await tester.pumpAndSettle();
    await tester.tap(canceled);
    await tester.pumpAndSettle();
    expect(tester.widget<AliadoQuickFilterChip>(canceled).selected, isTrue);

    await tester.tap(find.byTooltip('Ordenar pedidos'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(CheckedPopupMenuItem<bool>, 'Orden habitual'));
    await tester.pumpAndSettle();
    expect(find.text('Orden habitual ↓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

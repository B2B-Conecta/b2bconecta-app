import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_colors.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_entry.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_row.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_filter_bar.dart';
import 'order_workspace_test.dart' show fixture;

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  test('mixed and cancelled requests do not invent a shipping phase', () {
    expect(
        OrderListEntry([fixture('cancelled', status: 'rechazado')])
            .shippingPhase,
        isNull);
    expect(
        OrderListEntry([fixture('one'), fixture('two', status: 'en_transito')])
            .shippingPhase,
        isNull);
    expect(
        OrderListEntry([fixture('one', status: 'en_transito')]).shippingPhase,
        2);
  });

  testWidgets('a constant heading follows a live theme change', (tester) async {
    late StateSetter rebuild;
    var dark = false;
    await tester.pumpWidget(StatefulBuilder(builder: (_, setState) {
      rebuild = setState;
      return MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const Scaffold(body: OrderListColumnsHeader()));
    }));
    Color textColor() =>
        DefaultTextStyle.of(tester.element(find.text('Pedido'))).style.color!;
    final light = textColor();
    rebuild(() => dark = true);
    await tester.pumpAndSettle();
    expect(
        textColor().computeLuminance(), greaterThan(light.computeLuminance()));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('text and status contrast in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Builder(builder: (context) {
            final colors = OrderListColors.of(context);
            expect(contrast(colors.secondary, colors.surface),
                greaterThanOrEqualTo(4.5));
            expect(contrast(colors.accent, colors.surface),
                greaterThanOrEqualTo(4.5));
            for (final status in [
              'pendiente',
              'en_preparacion',
              'en_transito',
              'entregado',
              'rechazado'
            ]) {
              final color = OrderListEntry([fixture('one', status: status)])
                  .statusColor(context);
              final background =
                  Color.alphaBlend(color.withOpacity(.10), colors.surface);
              expect(contrast(color, background), greaterThanOrEqualTo(4.5),
                  reason: status);
            }
            return const Scaffold();
          })));
    });
    for (final width in [320.0, 768.0, 1280.0, 1600.0]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets('row and controls at $width / $scale / dark=$dark',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1100);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          var opened = false;
          PedidosListScope selected = PedidosListScope.todos;
          await tester.pumpWidget(MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: Builder(
                  builder: (context) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: Scaffold(
                            body: SingleChildScrollView(
                                child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            OrderListFilterBar(
                                searchController: controller,
                                onSearchChanged: (_) {},
                                onFilters: () {},
                                softStyle: true,
                                padding: EdgeInsets.zero),
                            PedidosScopeBar(
                                selected: selected,
                                onSelected: (value) => selected = value,
                                filledStyle: true),
                            OrderListRow(
                                entry: OrderListEntry([fixture('visible')]),
                                table: width >= 1000 && scale < 1.4,
                                selected: false,
                                onOpen: () => opened = true),
                          ]),
                        ))),
                      ))));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.textContaining('#VISIBLE'));
          await tester.tap(find.textContaining('#VISIBLE'));
          await tester.pumpAndSettle();
          expect(opened, isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

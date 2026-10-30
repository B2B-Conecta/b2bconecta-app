import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/order_workspace.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

TransactionRequestModel fixture(String id,
        {String mode = 'DIVISAS', String status = 'pendiente'}) =>
    TransactionRequestModel.fromJson({
      'id': id,
      'aliado_id': 'store',
      'importador_id': 'supplier',
      'product_id': 'product-$id',
      'status': status,
      'cantidad': 5,
      'precio_total_usd': mode == 'DIVISAS' ? 240 : 260,
      'precio_unitario_aliado': 52,
      'precio_unitario_proveedor': 40,
      'precio_base_aliado_total': 260,
      'total_ref': 260,
      'total_bs': 2600,
      'tasa_bcv_aplicada': 10,
      'metodo_pago_moneda': mode,
      'discount_rules': {'checkout_pricing_version': 1},
      'products': {
        'name': 'Disco de freno para motocicletas modelo extra largo $id'
      },
      'importador': {
        'business_name': 'Importadora de Repuestos del Occidente C.A.'
      },
    });

void main() {
  test('order projection keeps USD offers separate from the REF conversion',
      () {
    final usd = OrderListEntry([fixture('one')]);
    final ref = OrderListEntry([fixture('two', mode: 'BOLIVARES')]);
    expect(usd.amount, '240.00 USD');
    expect(usd.bolivares, isNull);
    expect(ref.amount, '260.00 REF');
    expect(ref.bolivares, contains('2.600,00'));
    expect(OrderListEntry([fixture('x')]).reference, '#X');
  });

  for (final width in [320.0, 768.0, 1280.0, 1600.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('selection, close and refresh at $width / $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = null as String?;
        var refreshed = false;
        late StateSetter rebuild;
        var groups = [
          [fixture('first')],
          [fixture('second', mode: 'BOLIVARES')]
        ];
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: Scaffold(
                          body: StatefulBuilder(builder: (context, setState) {
                        rebuild = setState;
                        return OrderWorkspace(
                          groups: groups,
                          selectedKey: selected,
                          onSelect: (key) => setState(() => selected = key),
                          onClose: () => setState(() => selected = null),
                          controls: const Text('Controles de pedidos'),
                          onRefresh: () async => refreshed = true,
                          onClearFilters: () {},
                          resetKey: 'all',
                          detailBuilder: (lines) => Column(children: [
                            Text('Detalle de ${lines.first.id}'),
                            Text(OrderListEntry(lines).amount),
                            const TextField(
                                decoration:
                                    InputDecoration(labelText: 'Borrador')),
                            OrderFulfilmentProgress(lines: lines),
                          ]),
                        );
                      })),
                    ))));
        expect(tester.takeException(), isNull);
        await tester.tap(find.textContaining('#FIRST').first);
        await tester.pumpAndSettle();
        expect(find.text('Detalle de first'), findsOneWidget);
        expect(find.text('Controles de pedidos'), findsNothing);
        expect(find.textContaining('#SECOND'), findsNothing);
        await tester.enterText(find.byType(TextField), 'Referencia en edición');
        rebuild(() => groups = [
              [fixture('first', status: 'en_preparacion')],
              groups.last
            ]);
        await tester.pumpAndSettle();
        expect(find.text('Referencia en edición'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Volver a pedidos'));
        await tester.pumpAndSettle();
        expect(find.text('Detalle de first'), findsNothing);
        expect(find.text('Controles de pedidos'), findsOneWidget);
        expect(refreshed, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('mobile back preserves the page and scroll position',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    final groups = List.generate(23, (i) => [fixture('page$i')]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => OrderWorkspace(
                      groups: groups,
                      selectedKey: selected,
                      onSelect: (key) => setState(() => selected = key),
                      onClose: () => setState(() => selected = null),
                      controls: const Text('Buscar'),
                      detailBuilder: (_) => const Text('Detalle seleccionado'),
                      onRefresh: () async {},
                      resetKey: 'all',
                      onClearFilters: () {},
                    )))));
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -100));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(list).position.pixels;
    await tester.tap(find.textContaining('#PAGE11').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver a pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('11–20 de 23'), findsOneWidget);
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty results offer recovery without a stale detail',
      (tester) async {
    var cleared = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderWorkspace(
      groups: const [],
      selectedKey: 'missing',
      onSelect: (_) {},
      onClose: () {},
      controls: const Text('Buscar'),
      detailBuilder: (_) => const Text('Detalle antiguo'),
      onRefresh: () async {},
      resetKey: 0,
      onClearFilters: () => cleared = true,
    ))));
    expect(find.text('Detalle antiguo'), findsNothing);
    await tester.tap(find.text('Ver todos los pedidos'));
    expect(cleared, isTrue);
  });

  testWidgets('cancelled orders have no invented delivery progress',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderFulfilmentProgress(
      lines: [fixture('cancelled', status: 'rechazado')],
    ))));
    expect(find.text('En camino'), findsNothing);
  });
}

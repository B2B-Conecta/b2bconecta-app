import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_pedidos_filters_sheet.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_filter_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/order_summary_header.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_list_heading.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

TransactionRequestModel line(
        {String mode = 'DIVISAS',
        String status = 'pendiente',
        String? adjustment}) =>
    TransactionRequestModel.fromJson({
      'id': 'fixture',
      'aliado_id': 'store',
      'importador_id': 'supplier',
      'product_id': 'p',
      'status': status,
      'cantidad': 5,
      'precio_total_usd': mode == 'DIVISAS' ? 240 : 260,
      'precio_unitario_aliado': 52,
      'precio_unitario_proveedor': 40,
      'precio_base_aliado_total': 260,
      'total_ref': 260,
      'total_bs': 2600,
      'metodo_pago_moneda': mode,
      'tasa_bcv_aplicada': 10,
      'discount_rules': {'checkout_pricing_version': 1},
      'qty_adjustment_status': adjustment,
      'products': {'name': 'Disco de freno EBC para motocicleta'},
      'importador': {
        'business_name': 'Distribuidora Internacional del Occidente C.A.'
      },
      'aliado': {'business_name': 'Taller Los Ruices'},
    });

Widget frame(Widget child, {double scale = 1}) => MaterialApp(
      home: Builder(
          builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(body: child))),
    );

void main() {
  testWidgets('the desktop list does not repeat the shell title',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(frame(const OrdersListHeading(count: 3)));
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('3 pedidos'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 850);
    await tester.pumpWidget(frame(const OrdersListHeading(count: 3)));
    expect(find.text('Pedidos'), findsNothing);
    expect(find.text('3 pedidos'), findsOneWidget);
  });
  for (final role in AppHomeRole.values.where((r) => [
        AppHomeRole.aliado,
        AppHomeRole.importador,
        AppHomeRole.administrador
      ].contains(r))) {
    for (final mode in ['DIVISAS', 'VES']) {
      testWidgets('$role preserves the agreed $mode amount', (tester) async {
        await tester.pumpWidget(frame(OrderSummaryHeader(
          lines: [line(mode: mode)],
          viewerRole: role,
          expanded: false,
          onToggle: () {},
          statusLabel: 'Pendiente',
          chatAction: const SizedBox(),
        )));
        expect(find.text(mode == 'DIVISAS' ? '240.00 USD' : '260.00 REF'),
            findsOneWidget);
        expect(find.text('240.00 REF'), findsNothing);
        expect(find.textContaining('2.600,00'),
            mode == 'VES' ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'opening a pedido and cancelling remain separate explicit actions',
      (tester) async {
    var opened = false;
    var cancelled = false;
    await tester.pumpWidget(frame(OrderSummaryHeader(
      lines: [line()],
      viewerRole: AppHomeRole.aliado,
      expanded: false,
      onToggle: () => opened = true,
      onCancel: () => cancelled = true,
      statusLabel: 'Pendiente',
      chatAction: const SizedBox(),
    )));
    expect(find.text('Cancelar pedido'), findsNothing);
    await tester.tap(find.text('Ver pedido'));
    expect(opened, isTrue);
    expect(cancelled, isFalse);
    await tester.tap(find.byTooltip('Más opciones del pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar pedido'), findsOneWidget);
    expect(cancelled, isFalse);
    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
  });

  testWidgets('a quantity proposal is surfaced as the next step',
      (tester) async {
    await tester.pumpWidget(frame(OrderSummaryHeader(
      lines: [line(adjustment: 'pendiente_aliado')],
      viewerRole: AppHomeRole.aliado,
      expanded: false,
      onToggle: () {},
      statusLabel: 'Pendiente',
      chatAction: const SizedBox(),
    )));
    expect(find.text('Revisar cantidad'), findsOneWidget);
    expect(
        find.textContaining('Confirma la cantidad propuesta'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
          'list controls and long order names fit $width at text scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(frame(
            SingleChildScrollView(
                child: Column(children: [
              OrderListFilterBar(
                  searchController: controller,
                  onSearchChanged: (_) {},
                  onFilters: () {},
                  activeFilterCount: 3),
              PedidosScopeBar(
                  selected: PedidosListScope.todos, onSelected: (_) {}),
              ListPageBar(
                  total: 93,
                  pageIndex: 0,
                  pageSize: 10,
                  onPageIndex: (_) {},
                  onPageSize: (_) {}),
              OrderSummaryHeader(
                  lines: [line(mode: 'VES')],
                  viewerRole: AppHomeRole.aliado,
                  expanded: false,
                  onToggle: () {},
                  statusLabel: 'Pendiente',
                  onCancel: () {},
                  chatAction: IconButton(
                      onPressed: () {}, icon: const Icon(Icons.chat_outlined))),
            ])),
            scale: scale));
        expect(find.text('Ver pedido'), findsOneWidget);
        expect(find.text('Filtros (3)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('collapsing detail keeps an in-progress field intact',
      (tester) async {
    await tester.pumpWidget(frame(const OrderCardCollapsibleSection(
      title: 'Factura y pago',
      child: TextField(),
    )));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Factura y pago'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Referencia 1234');
    await tester.tap(find.text('Factura y pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Factura y pago'));
    await tester.pumpAndSettle();
    expect(find.text('Referencia 1234'), findsOneWidget);
  });

  testWidgets('bottom pagination advances and resets when filters change',
      (tester) async {
    var resetKey = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(frame(StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return PagedItems<int>(
          items: List.generate(23, (i) => i),
          resetKey: resetKey,
          pagerAtBottom: true,
          itemKey: (i) => i,
          itemBuilder: (i) => Text('Pedido $i'));
    })));
    expect(tester.getTopLeft(find.byType(ListPageBar)).dy,
        greaterThan(tester.getTopLeft(find.text('Pedido 0')).dy));
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido 10'), findsOneWidget);
    expect(find.text('Pedido 0'), findsNothing);
    rebuild(() => resetKey++);
    await tester.pumpAndSettle();
    expect(find.text('Pedido 0'), findsOneWidget);
  });

  testWidgets('filter sheet returns dates and signals, and reset clears them',
      (tester) async {
    AliadoPedidosFiltersDraft? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        result = await AliadoPedidosFiltersSheet.show(context,
                            initial: AliadoPedidosFiltersDraft(
                                creditOnly: true,
                                dateFrom: DateTime(2026, 10, 1)),
                            statusOptions: const []);
                      },
                      child: const Text('Filtrar')),
                ))));
    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(result!.creditOnly, isTrue);
    expect(result!.dateFrom, DateTime(2026, 10, 1));
    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restablecer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pumpAndSettle();
    expect(result!.hasAnyPanelFilter, isFalse);
  });
}

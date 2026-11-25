import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_expandable_order_card.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_order_detail_view.dart';
import 'package:motolink_pro_app/features/orders/aliado/mobile_cancel_order_screen.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/order_summary_header.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/orders/shared/order_detail_overview.dart';
import 'package:motolink_pro_app/features/orders/shared/order_delivery_stepper.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_motolink_thread_section.dart';
import 'order_workspace_test.dart' show fixture;

class _ChatRouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

TransactionRequestModel supplierLine(String id, String supplier,
        {bool invoice = false, bool paid = false}) =>
    TransactionRequestModel.fromJson({
      'aliado_id': 'store',
      'product_id': id,
      'status': 'pendiente',
      'cantidad': 5,
      'precio_total_usd': 240,
      'precio_unitario_aliado': 52,
      'precio_unitario_proveedor': 40,
      'metodo_pago_moneda': 'DIVISAS',
      'id': id,
      'importador_id': supplier,
      'checkout_group_id': 'checkout',
      if (invoice) 'proveedor_factura_storage_path': '$id/factura.pdf',
      if (paid) 'pago_estado_revision': 'aprobado',
      'products': {'name': 'Repuesto $id'},
      'importador': {'business_name': 'Proveedor $supplier'},
    });

List<TransactionRequestModel> mixedSummaryFixture({bool bsSnapshot = true}) => [
      for (final row in [
        ('one', 'A', 'DIVISAS', 49.5),
        ('two', 'B', 'DIVISAS', 98.0),
        ('three', 'C', 'BOLIVARES', 156.42)
      ])
        TransactionRequestModel.fromJson({
          'id': row.$1,
          'aliado_id': 'store',
          'importador_id': row.$2,
          'product_id': row.$1,
          'checkout_group_id': 'DCBD89FC-checkout',
          'status': row.$1 == 'one' ? 'pendiente' : 'en_preparacion',
          'cantidad': 5,
          'precio_total_usd': row.$4,
          'precio_unitario_aliado': row.$4 / 5,
          'precio_unitario_proveedor': row.$4 / 5,
          'metodo_pago_moneda': row.$3,
          'discount_rules': {'checkout_pricing_version': 1},
          if (row.$3 == 'BOLIVARES' && bsSnapshot) ...{
            'total_ref': row.$4,
            'total_bs': 139386.93,
            'tasa_bcv_aplicada': 891.105,
          },
          'products': {
            'name':
                row.$1 == 'one' ? 'Casco Vini Rabe azul' : 'Producto ${row.$1}'
          },
          'importador': {'business_name': 'Proveedor ${row.$2}'},
        }),
    ];

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
          'mixed mobile summary separates actual currencies without a combined line $width/$scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                        body: Padding(
                            padding: const EdgeInsets.all(12),
                            child: OrderSummaryHeader(
                              lines: mixedSummaryFixture(),
                              viewerRole: AppHomeRole.aliado,
                              expanded: true,
                              onToggle: () {},
                              statusLabel: 'Varios estados',
                              detailSummary: true,
                              compactDetail: true,
                              actionsInHeader: true,
                              chatAction: OrderChatIconButton(
                                  relatedOrderIds: const [], onOpen: () {}),
                              onCancel: () {},
                            )))))));
        await tester.pumpAndSettle();
        expect(find.text('147.50 USD'), findsOneWidget);
        expect(find.text('Bs 139.386,93'), findsOneWidget);
        expect(tester.getBottomRight(find.text('147.50 USD')).dx,
            closeTo(width - 21, .5));
        expect(tester.getBottomRight(find.text('Bs 139.386,93')).dx,
            closeTo(width - 21, .5));
        expect(find.textContaining('USD +'), findsNothing);
        expect(tester.getTopLeft(find.text('147.50 USD')).dy,
            lessThan(tester.getTopLeft(find.text('Bs 139.386,93')).dy));
        expect(find.text('Casco Vini Rabe azul y 2 más'), findsOneWidget);
        expect(find.byTooltip('Más opciones del pedido'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'mixed mobile summary preserves REF when the Bs snapshot is unavailable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderDetailOverview(
                lines: mixedSummaryFixture(bsSnapshot: false),
                compactRetailer: true,
                nextStep: '',
                chatAction: const SizedBox.shrink()))));
    await tester.pumpAndSettle();
    expect(find.text('147.50 USD'), findsOneWidget);
    expect(find.text('156.42 REF'), findsOneWidget);
    expect(find.textContaining('Bs '), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
          'compact summary shares the title row with working actions $width/$scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var chats = 0, cancellations = 0;
        final line = supplierLine(
            'Filtro de aire de espuma para motocicleta de nombre largo', 'B');
        await tester.pumpWidget(MaterialApp(
            theme: scale > 1 ? ThemeData.dark() : ThemeData.light(),
            home: Builder(
                builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                        body: Padding(
                            padding: const EdgeInsets.all(12),
                            child: OrderSummaryHeader(
                              lines: [line],
                              viewerRole: AppHomeRole.aliado,
                              expanded: true,
                              onToggle: () {},
                              statusLabel: 'Pendiente',
                              detailSummary: true,
                              compactDetail: true,
                              actionsInHeader: true,
                              chatAction: OrderChatIconButton(
                                  relatedOrderIds: const [],
                                  onOpen: () => chats++),
                              onCancel: () => cancellations++,
                            )))))));
        await tester.pumpAndSettle();
        final title = tester.getRect(find.text(line.productName!));
        final chat = tester.getRect(find.byTooltip('Mensajes del pedido'));
        expect(chat.top, lessThan(title.bottom));
        expect(chat.bottom, greaterThan(title.top));
        expect(chat.left, greaterThan(title.left));
        await tester.tap(find.byTooltip('Mensajes del pedido'));
        await tester.pumpAndSettle();
        expect(chats, 1);
        await tester.tap(find.byTooltip('Más opciones del pedido'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar pedido'));
        await tester.pumpAndSettle();
        expect(cancellations, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets(
        'confirming cancellation from a mixed checkout writes only the chosen supplier at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lines = [
        supplierLine('paid-A', 'A', invoice: true, paid: true),
        supplierLine('B-one', 'B'),
        supplierLine('B-two', 'B')
      ];
      final cancelled = <String>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => SingleChildScrollView(
                        child: AliadoExpandableOrderCard(
                          request: lines.first,
                          checkoutGroupLines: lines,
                          expanded: true,
                          onToggle: () {},
                          statusLabel: 'Varios estados',
                          workspaceDetail: true,
                          compactDetail: width < 768,
                          onCancelarProveedor: (selected) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MobileCancelOrderScreen(
                                        lines: selected,
                                        loadLines: () async => lines,
                                        cancelLine: (line, reason) async {
                                          cancelled.add(line.id);
                                          expect(reason,
                                              'Me equivoqué de proveedor.');
                                        },
                                      ))),
                          detailSectionsBuilder: (_, __, ___, ____) =>
                              const AliadoOrderDetailSections(
                                  payment: SizedBox.shrink(),
                                  paymentStatus: 'Estado del pago'),
                        ),
                      )))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Proveedor B'));
      await tester.tap(find.text('Proveedor B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Más opciones del pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Más opciones del pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar a Proveedor B'));
      await tester.pumpAndSettle();
      expect(find.text('Proveedor A'), findsNothing);
      expect(find.text('Repuesto paid-A'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('cancel-reason')));
      await tester.enterText(find.byKey(const ValueKey('cancel-reason')),
          'Me equivoqué de proveedor.');
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect(cancelled, ['B-one', 'B-two']);
      expect(find.text('Cancelación registrada'), findsOneWidget);
      expect(lines.first.pagoEstadoRevisionEfectivo, 'aprobado');
    });
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'mobile mixed checkout cancels only the selected supplier at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<TransactionRequestModel>? requested;
      var globalCalls = 0;
      late StateSetter refresh;
      var lines = [
        supplierLine('paid-A', 'A', invoice: true, paid: true),
        supplierLine('B-one', 'B'),
        supplierLine('B-two', 'B')
      ];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        refresh = setState;
        return SingleChildScrollView(
            child: AliadoExpandableOrderCard(
          request: lines.first,
          checkoutGroupLines: lines,
          expanded: true,
          onToggle: () {},
          statusLabel: 'Varios estados',
          workspaceDetail: true,
          compactDetail: true,
          onCancelarSolicitudPendiente: () => globalCalls++,
          onCancelarProveedor: (selected) => requested = selected,
          detailSectionsBuilder: (_, __, ___, ____) =>
              const AliadoOrderDetailSections(
                  payment: SizedBox.shrink(), paymentStatus: 'Estado del pago'),
        ));
      }))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Más opciones del pedido'), findsNothing);
      await tester.ensureVisible(find.text('Proveedor B'));
      await tester.tap(find.text('Proveedor B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Más opciones del pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Más opciones del pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar a Proveedor B'), findsOneWidget);
      await tester.tap(find.text('Cancelar a Proveedor B'));
      await tester.pumpAndSettle();
      expect(requested!.map((line) => line.id), ['B-one', 'B-two']);
      expect(requested!.every((line) => line.ownerId == 'B'), isTrue);
      expect(globalCalls, 0);
      // A normal refresh preserves B as the selected supplier but its new invoice
      // must immediately remove the action, independently of A's payment.
      refresh(() => lines = [
            lines.first,
            supplierLine('B-one', 'B', invoice: true),
            lines.last
          ]);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Más opciones del pedido'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'mobile cancellation remains provider scoped even when everyone is eligible',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lines = [supplierLine('A-one', 'A'), supplierLine('B-one', 'B')];
    List<TransactionRequestModel>? requested;
    var globalCalls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AliadoExpandableOrderCard(
      request: lines.first,
      checkoutGroupLines: lines,
      expanded: true,
      onToggle: () {},
      statusLabel: 'Pendiente',
      workspaceDetail: true,
      compactDetail: true,
      onCancelarSolicitudPendiente: () => globalCalls++,
      onCancelarProveedor: (selected) => requested = selected,
      detailSectionsBuilder: (_, __, ___, ____) =>
          const AliadoOrderDetailSections(
              payment: SizedBox.shrink(), paymentStatus: 'Esperando factura'),
    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Más opciones del pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar a Proveedor A'));
    await tester.pumpAndSettle();
    expect(requested!.map((line) => line.id), ['A-one']);
    expect(globalCalls, 0);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('order header chat follows the selected supplier at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _ChatRouteObserver();
      final lines = [
        supplierLine('A-one', 'A'),
        supplierLine('B-one', 'B'),
        supplierLine('B-two', 'B'),
      ];
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: SingleChildScrollView(
            child: AliadoExpandableOrderCard(
              request: lines.first,
              checkoutGroupLines: lines,
              expanded: true,
              onToggle: () {},
              statusLabel: 'Pendiente',
              workspaceDetail: true,
              compactDetail: width < 768,
              detailSectionsBuilder: (_, __, ___, ____) =>
                  const AliadoOrderDetailSections(
                payment: SizedBox.shrink(),
                paymentStatus: 'Esperando factura',
              ),
            ),
          ),
        ),
      ));
      final chat = find.byType(OrderChatIconButton);
      expect(tester.widget<OrderChatIconButton>(chat).relatedOrderIds, ['A-one']);
      await tester.tap(find.text('Proveedor B'));
      await tester.pumpAndSettle();
      expect(tester.widget<OrderChatIconButton>(chat).relatedOrderIds,
          ['B-one', 'B-two']);

      if (width < 768) {
        await tester.tap(find.byTooltip('Mensajes del pedido'));
        final route = observer.lastPushed! as MaterialPageRoute<void>;
        final thread = route.builder(tester.element(chat))
            as OrderMotolinkThreadSection;
        expect(thread.transactionRequestId, 'B-one');
        expect(thread.mergedThreadRequestIds, ['B-one', 'B-two']);
        expect(thread.orderLines.map((line) => line.ownerId), ['B', 'B']);
        observer.navigator!.removeRoute(route);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proveedor A'));
      await tester.pumpAndSettle();
      expect(tester.widget<OrderChatIconButton>(chat).relatedOrderIds, ['A-one']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retailer detail places the chat icon in the summary header',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
            child: AliadoExpandableOrderCard(
          request: fixture('pending'),
          expanded: true,
          onToggle: () {},
          statusLabel: 'Pendiente',
          workspaceDetail: true,
          onCancelarSolicitudPendiente: () {},
          detailSectionsBuilder: (_, __, ___, ____) =>
              const AliadoOrderDetailSections(
            payment: SizedBox.shrink(),
            paymentStatus: 'Esperando factura',
          ),
        )),
      ),
    ));
    final chat = find.byTooltip('Mensajes del pedido');
    final summary = find.byType(OrderDetailOverview);
    expect(chat, findsOneWidget);
    expect(find.text('Mensajes'), findsNothing);
    expect(tester.getTopLeft(chat).dy,
        lessThan(tester.getTopLeft(summary).dy + 64));
    final options = find.byTooltip('Más opciones del pedido');
    expect(options, findsOneWidget);
    expect(tester.getCenter(chat).dx, lessThan(tester.getCenter(options).dx));
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final width in [320.0, 768.0, 1280.0]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets(
            'detail sections remain usable at $width / $scale / dark=$dark',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
                          child: AliadoOrderDetailView(
                            lines: [fixture('single')],
                            summary: Column(children: [
                              const Text('Resumen único'),
                              OrderSummaryHeader(
                                lines: [fixture('single')],
                                viewerRole: AppHomeRole.aliado,
                                expanded: true,
                                detailSummary: true,
                                showToggle: false,
                                onToggle: () {},
                                statusLabel: 'Pendiente',
                                onCancel: () {},
                                chatAction: IconButton(
                                    onPressed: () {},
                                    icon:
                                        const Icon(Icons.chat_bubble_outline)),
                              ),
                            ]),
                            sectionsBuilder: (_, __, ___, ____) =>
                                const AliadoOrderDetailSections(
                              payment: Text('Comprobante del pedido'),
                              paymentStatus: 'Esperando factura',
                              receipt: Text('Acción de recepción'),
                              deliveryActions: Text('Transportista del pedido'),
                              attention: Text('Aceptar ajuste de cantidad'),
                              afterSales: Text('Devolución y valoración'),
                            ),
                          ),
                        ))),
                      ))));
          await tester.pumpAndSettle();
          for (final title in [
            'Seguimiento',
            'Productos',
            'Entrega',
            'Pago y factura',
            'Contacto'
          ]) {
            expect(
                find.byWidgetPredicate((widget) =>
                    widget is OrderDetailSection && widget.title == title),
                findsOneWidget);
          }
          expect(find.text('Resumen único'), findsOneWidget);
          expect(find.text('Acción de recepción'), findsOneWidget);
          expect(find.text('Aceptar ajuste de cantidad'), findsOneWidget);
          await tester.ensureVisible(find.text('Ver factura y opciones'));
          await tester.tap(find.text('Ver factura y opciones'));
          await tester.pumpAndSettle();
          expect(find.text('Comprobante del pedido'), findsOneWidget);
          await tester.ensureVisible(find.text('Historial del envío'));
          await tester.tap(find.text('Historial del envío'));
          await tester.pumpAndSettle();
          expect(find.text('Devolución y valoración'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final mode in ['DIVISAS', 'BOLIVARES']) {
    testWidgets('new overview keeps $mode and labelled messages actionable',
        (tester) async {
      var opened = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OrderDetailOverview(
        lines: [fixture('currency', mode: mode)],
        nextStep: 'Revisa el pedido',
        chatAction: OrderChatIconButton(
            showLabel: true,
            relatedOrderIds: const [],
            onOpen: () => opened = true),
      ))));
      expect(find.text(mode == 'DIVISAS' ? '240.00 USD' : '260.00 REF'),
          findsOneWidget);
      expect(find.textContaining('2.600,00'),
          mode == 'DIVISAS' ? findsNothing : findsOneWidget);
      await tester.tap(find.text('Chat'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelled and mixed shipping remain honest in the new journey',
      (tester) async {
    Widget frame(List<TransactionRequestModel> lines) =>
        MaterialApp(home: Scaffold(body: OrderDeliveryStepper(lines: lines)));
    await tester.pumpWidget(frame([fixture('cancel', status: 'rechazado')]));
    expect(find.text('Este pedido fue cancelado.'), findsOneWidget);
    expect(find.text('En camino'), findsNothing);
    await tester.pumpWidget(
        frame([fixture('one'), fixture('two', status: 'en_transito')]));
    expect(find.textContaining('avances distintos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplier selection isolates forms and survives a data refresh',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late StateSetter refresh;
    var lines = [supplierLine('one', 'A'), supplierLine('two', 'B')];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      refresh = setState;
      return SingleChildScrollView(
          child: AliadoOrderDetailView(
        lines: lines,
        summary: const Text('Total del carrito'),
        sectionsBuilder: (_, chunk, index, total) => AliadoOrderDetailSections(
          paymentStatus: 'Pago $index de $total',
          paymentOpen: true,
          payment: TextFormField(
              initialValue: chunk.first.ownerId,
              decoration: const InputDecoration(labelText: 'Referencia')),
        ),
      ));
    }))));
    await tester.pumpAndSettle();
    expect(find.text('Pago 1 de 2'), findsOneWidget);
    await tester.tap(find.text('Proveedor B'));
    await tester.pumpAndSettle();
    expect(find.text('Pago 2 de 2'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'Referencia en edición');
    refresh(() => lines = [supplierLine('one', 'A'), supplierLine('two', 'B')]);
    await tester.pumpAndSettle();
    expect(find.text('Pago 2 de 2'), findsOneWidget);
    expect(find.text('Referencia en edición'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

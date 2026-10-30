import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_order_detail_view.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/order_summary_header.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/orders/shared/order_detail_overview.dart';
import 'package:motolink_pro_app/features/orders/shared/order_delivery_stepper.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'order_workspace_test.dart' show fixture;

TransactionRequestModel supplierLine(String id, String supplier) =>
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
      'products': {'name': 'Repuesto $id'},
      'importador': {'business_name': 'Proveedor $supplier'},
    });

void main() {
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
      await tester.tap(find.text('Mensajes'));
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

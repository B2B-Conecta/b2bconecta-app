import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/order_date_shortcuts.dart';
import 'package:motolink_pro_app/features/orders/shared/order_signal_filters.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

TransactionRequestModel _line({
  required String id,
  double credit = 0,
  String? resolution,
}) {
  return TransactionRequestModel(
    id: id,
    aliadoId: 'a',
    productId: 'p',
    ownerId: 'o',
    status: 'pendiente',
    cantidad: 1,
    precioUnitarioProveedor: 1,
    precioUnitarioAliado: 1,
    precioTotal: 1,
    precioBaseAliadoTotal: 1,
    creditoAplicadoMonto: credit,
    postventaResolucion: resolution,
  );
}

void main() {
  final creditOrder = [
    _line(id: '1', credit: 12),
    _line(id: '2'),
  ];
  final changeOrder = [
    _line(id: '3', resolution: 'cambio'),
  ];
  final plainOrder = [
    _line(id: '4'),
  ];
  final groups = [creditOrder, changeOrder, plainOrder];

  test('sin filtros conserva todos los pedidos', () {
    expect(
      filterOrderGroupsBySignals(
        groups,
        creditOnly: false,
        replacementOnly: false,
      ),
      groups,
    );
  });

  test('bajo crédito deja el carrito completo si una línea usó saldo', () {
    final filtered = filterOrderGroupsBySignals(
      groups,
      creditOnly: true,
      replacementOnly: false,
    );
    expect(filtered, [creditOrder]);
  });

  test('cambio de producto deja solo los pedidos con cambio', () {
    final filtered = filterOrderGroupsBySignals(
      groups,
      creditOnly: false,
      replacementOnly: true,
    );
    expect(filtered, [changeOrder]);
  });

  test('los dos filtros juntos exigen crédito y cambio en el mismo pedido', () {
    final both = [
      [_line(id: '5', credit: 8, resolution: 'cambio')],
      creditOrder,
      changeOrder,
    ];
    final filtered = filterOrderGroupsBySignals(
      both,
      creditOnly: true,
      replacementOnly: true,
    );
    expect(filtered, [both.first]);
  });

  testWidgets('los filtros se ven completos en móvil y en web', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PedidosScopeBar(
                  selected: PedidosListScope.enCurso,
                  onSelected: (_) {},
                ),
                OrderDateShortcutBar(
                  from: null,
                  to: null,
                  onChanged: (DateTime? from, DateTime? to) {},
                  onPickRange: () {},
                ),
                OrderSignalFilterBar(
                  creditOnly: false,
                  replacementOnly: false,
                  onChanged: (bool credit, bool replacement) {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Bajo crédito'), findsOneWidget);
      expect(find.text('Cambio de producto'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Entregados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await pumpAt(const Size(390, 844));
    await pumpAt(const Size(1280, 800));
  });
}

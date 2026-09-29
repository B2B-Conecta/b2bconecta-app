import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/importer_min_order.dart';
import 'package:motolink_pro_app/features/cart/min_order_currency.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/importer_sales_snapshot.dart';

void main() {
  test('el piso de compra se evalúa por importador, no por el total', () {
    final cheap = PartModel(
      id: 'a',
      ownerBusinessName: 'Casa A',
      nombre: 'Junta',
      precio: 5,
      stock: 20,
      ownerMinOrderAmountRef: 100,
    );
    final other = PartModel(
      id: 'b',
      ownerBusinessName: 'Casa B',
      nombre: 'Filtro',
      precio: 20,
      stock: 20,
      ownerMinOrderAmountRef: 0,
    );
    final progress = importerMinOrderProgressFor({
      'Casa A': [
        CartLine(part: cheap, quantity: 4, precioUnitarioAliadoRef: 5),
      ],
      'Casa B': [
        CartLine(part: other, quantity: 3, precioUnitarioAliadoRef: 20),
      ],
    }.entries);
    expect(progress.length, 2);
    expect(progress.firstWhere((e) => e.importerName == 'Casa A').meets, isFalse);
    expect(progress.firstWhere((e) => e.importerName == 'Casa B').meets, isTrue);
  });

  test('parsea el error de checkout de pedido mínimo', () {
    final msg = cartMinOrderErrorMessage(
      Exception('min_order_amount:abc:100:42:Casa Norte'),
    );
    expect(msg, contains('Casa Norte'));
    expect(msg, contains('100.00'));
    expect(msg, contains('42.00'));
  });

  test('parsea el snapshot de ventas del importador', () {
    final snap = ImporterSalesSnapshot.fromJson({
      'days': 30,
      'orders_count': 4,
      'units_sold': 18,
      'revenue_ref': 250.5,
      'top_products': [
        {'product_id': '1', 'name': 'Bujía', 'units': 10, 'revenue': 80},
      ],
      'low_rotation': [
        {'product_id': '2', 'name': 'Junta', 'units': 0},
      ],
    });
    expect(snap.ordersCount, 4);
    expect(snap.ordersActive, 0);
    expect(snap.topProducts.single.name, 'Bujía');
    expect(snap.lowRotation.single.units, 0);
    expect(snap.averageTicketRef, closeTo(62.625, 0.001));
    expect(snap.productRevenueShare(snap.topProducts.single), closeTo(80 / 250.5, 0.0001));
    expect(snap.unitsPerDay, closeTo(18 / 30, 0.0001));
  });

  test('el piso se presenta en REF o divisa sin cambiar el monto', () {
    expect(formatMinOrderAmount(100, MinOrderCurrency.ref), '100 REF');
    expect(formatMinOrderAmount(100, MinOrderCurrency.usd), '100 USD');
    expect(MinOrderCurrency.parse('divisa'), MinOrderCurrency.usd);
  });
}

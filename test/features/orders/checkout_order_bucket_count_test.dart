import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

TransactionRequestModel _line({
  required String id,
  String? checkoutGroupId,
  String status = 'pendiente',
}) {
  return TransactionRequestModel(
    id: id,
    aliadoId: 'a',
    productId: 'p',
    ownerId: 'o',
    status: status,
    cantidad: 1,
    precioUnitarioProveedor: 1,
    precioUnitarioAliado: 1,
    precioTotal: 1,
    precioBaseAliadoTotal: 1,
    checkoutGroupId: checkoutGroupId,
  );
}

void main() {
  group('countDistinctCheckoutOrders', () {
    test('counts one pedido for multiple lines in the same checkout group', () {
      final n = countDistinctCheckoutOrders([
        (id: 'line-a', checkoutGroupId: 'cart-1'),
        (id: 'line-b', checkoutGroupId: 'cart-1'),
        (id: 'line-c', checkoutGroupId: 'cart-2'),
      ]);
      expect(n, 2);
    });

    test('counts orphan lines without checkout_group_id as their own pedido', () {
      final n = countDistinctCheckoutOrders([
        (id: 'solo-1', checkoutGroupId: null),
        (id: 'solo-2', checkoutGroupId: ''),
        (id: 'line-a', checkoutGroupId: 'cart-1'),
      ]);
      expect(n, 3);
    });
  });

  group('groupAliadoOrdersByCheckout', () {
    test('matches distinct-count keys for badge vs bandeja', () {
      final flat = [
        _line(id: 'a', checkoutGroupId: 'g1'),
        _line(id: 'b', checkoutGroupId: 'g1', status: 'en_preparacion'),
        _line(id: 'c', checkoutGroupId: 'g2'),
      ];
      final groups = groupAliadoOrdersByCheckout(flat);
      expect(groups.length, 2);
      expect(
        countDistinctCheckoutOrders(
          flat.map((r) => (id: r.id, checkoutGroupId: r.checkoutGroupId)),
        ),
        groups.length,
      );
    });
  });
}

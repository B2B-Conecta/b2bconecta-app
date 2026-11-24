import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'cart_draft_test.dart' show MemoryDrafts, part;

void main() {
  test('supplier choices survive reload and remain isolated by account',
      () async {
    final storage = MemoryDrafts();
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'sandbox:a',
        storage: storage,
        loadProduct: (id) async => part(id, owner: id));
    for (final id in ['one', 'two']) {
      cart.addOrIncrement(part(id, owner: id), precioUnitarioAliadoRef: 10);
    }
    cart.setSupplierCurrencies({'one': true, 'two': false});
    await cart.saved;
    final restored = CartService();
    await restored.openAccount(
        accountKey: 'sandbox:a',
        storage: storage,
        loadProduct: (id) async => part(id, owner: id));
    expect(restored.supplierCurrencyPreferences, {'one': true, 'two': false});
    await restored.openAccount(
        accountKey: 'sandbox:b',
        storage: storage,
        loadProduct: (id) async => part(id, owner: id));
    expect(restored.supplierCurrencyPreferences, isEmpty);
    restored.addOrIncrement(part('one', owner: 'one'),
        precioUnitarioAliadoRef: 10);
    expect(restored.supplierCurrencyPreferences, isEmpty);
  });
  test(
      'only USD constraints, quantity changes, undo, and new providers stay independent',
      () {
    final cart = CartService();
    cart.addOrIncrement(
        const PartModel(
            id: 'only-usd',
            ownerId: 'one',
            nombre: 'Producto',
            precio: 10,
            stock: 100,
            ownerPagoSoloDivisas: true),
        precioUnitarioAliadoRef: 10);
    cart.addOrIncrement(part('two', owner: 'two'), precioUnitarioAliadoRef: 10);
    cart.setSupplierCurrencies({'one': false, 'two': false, 'foreign': true});
    expect(cart.supplierCurrencyPreferences, {'one': true, 'two': false});
    cart.setQuantity('two', 10);
    expect(cart.supplierCurrencyPreferences['two'], isFalse);
    cart.removeProduct('two');
    expect(cart.supplierCurrencyPreferences, {'one': true});
    cart.addOrIncrement(part('two', owner: 'two'), precioUnitarioAliadoRef: 10);
    expect(cart.supplierCurrencyPreferences['two'], isFalse);
    cart.addOrIncrement(part('three', owner: 'three'),
        precioUnitarioAliadoRef: 10);
    expect(cart.supplierCurrencyPreferences.containsKey('three'), isFalse);
    cart.clear();
    cart.addOrIncrement(part('two', owner: 'two'), precioUnitarioAliadoRef: 10);
    expect(cart.supplierCurrencyPreferences, isEmpty);
  });
  test('malformed or unrelated saved preferences do not become active choices',
      () async {
    final storage = MemoryDrafts()
      ..values['a'] = jsonEncode({
        'version': 1,
        'lines': [
          {'id': 'one', 'quantity': 5}
        ],
        'supplier_currencies': {'one': 'USD', 'foreign': true}
      });
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'a',
        storage: storage,
        loadProduct: (id) async => part(id, owner: id));
    expect(cart.supplierCurrencyPreferences, isEmpty);
    expect(cart.canEdit, isTrue);
  });
}

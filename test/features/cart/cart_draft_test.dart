import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_draft_storage.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

class MemoryDrafts implements CartDraftStorage {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Storage unavailable');
    values[key] = value;
  }
}

PartModel part(String id,
        {String owner = 'supplier-a',
        int stock = 30,
        int minimum = 5,
        double price = 10,
        double minAmount = 0}) =>
    PartModel(
        id: id,
        nombre: 'Repuesto $id',
        ownerId: owner,
        ownerBusinessName: 'Mismo nombre',
        precio: price,
        stock: stock,
        minOrderQty: minimum,
        ownerMinOrderAmountRef: minAmount);

String draft(List<Map<String, Object>> lines) => jsonEncode({
      'version': 1,
      'lines': lines,
      'campaigns': {'supplier-a': 'campaign-a'}
    });

void main() {
  test('reload restores quantities and attribution with current catalog prices',
      () async {
    final storage = MemoryDrafts();
    final first = CartService();
    await first.openAccount(
        accountKey: 'sandbox:ally-a',
        storage: storage,
        loadProduct: (id) async => part(id));
    first.addOrIncrement(part('p1'), precioUnitarioAliadoRef: 10, delta: 8);
    first.setPromoAttribution(
        importadorId: 'supplier-a', campaignId: 'campaign-a');
    await first.saved;
    final saved = jsonDecode(storage.values['sandbox:ally-a']!) as Map;
    expect((saved['lines'] as List).single, {'id': 'p1', 'quantity': 8});
    expect(storage.values['sandbox:ally-a'], isNot(contains('precio')));

    final second = CartService();
    await second.openAccount(
        accountKey: 'sandbox:ally-a',
        storage: storage,
        loadProduct: (id) async => part(id, price: 12));
    expect(second.itemCount, 8);
    expect(second.totalRef(), 96);
    expect(second.promoCampaignIdForImportador('supplier-a'), 'campaign-a');
    second.clear();
    await second.saved;
    final third = CartService();
    await third.openAccount(
        accountKey: 'sandbox:ally-a',
        storage: storage,
        loadProduct: (id) async => part(id));
    expect(third.isEmpty, isTrue);
    expect(third.promoCampaignByImportadorId, isEmpty);
  });

  test('restore adjusts stock and minimum and excludes unavailable products',
      () async {
    final storage = MemoryDrafts()
      ..values['a'] = draft([
        {'id': 'limited', 'quantity': 20},
        {'id': 'minimum', 'quantity': 5},
        {'id': 'gone', 'quantity': 5},
        {'id': 'paused', 'quantity': 5},
        {'id': 'short', 'quantity': 5},
      ]);
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'a',
        storage: storage,
        loadProduct: (id) async {
          switch (id) {
            case 'limited':
              return part(id, stock: 9);
            case 'minimum':
              return part(id, minimum: 10);
            case 'paused':
              return part(id).copyWith(isActive: false);
            case 'short':
              return part(id, stock: 3);
            default:
              return null;
          }
        });
    expect(cart.lines.map((e) => e.quantity), [9, 10]);
    expect(cart.restoreMessage, isNotNull);
    expect(cart.canEdit, isTrue);
  });

  test('failed restore keeps draft intact and retry replaces no partial items',
      () async {
    final storage = MemoryDrafts()
      ..values['a'] = draft([
        {'id': 'p1', 'quantity': 7},
        {'id': 'p2', 'quantity': 8}
      ]);
    final original = storage.values['a'];
    var offline = true;
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'a',
        storage: storage,
        loadProduct: (id) async {
          if (id == 'p2' && offline) throw StateError('offline');
          return part(id);
        });
    expect(cart.isEmpty, isTrue);
    expect(cart.canEdit, isFalse);
    cart.addOrIncrement(part('new'), precioUnitarioAliadoRef: 10);
    cart.clear();
    expect(storage.values['a'], original);
    offline = false;
    await cart.retryRestore();
    expect(cart.itemCount, 15);
    expect(cart.canEdit, isTrue);
  });

  test('account switch cancels pending restore and logout clears only RAM',
      () async {
    final storage = MemoryDrafts()
      ..values['a'] = draft([
        {'id': 'p1', 'quantity': 6}
      ]);
    final pending = Completer<PartModel?>();
    final requested = Completer<void>();
    final cart = CartService();
    final restoreA = cart.openAccount(
        accountKey: 'a',
        storage: storage,
        loadProduct: (id) {
          requested.complete();
          return pending.future;
        });
    await requested.future;
    await cart.openAccount(
        accountKey: 'b', storage: storage, loadProduct: (id) async => part(id));
    cart.addOrIncrement(part('b-product'), precioUnitarioAliadoRef: 10);
    pending.complete(part('p1'));
    await restoreA;
    expect(cart.lines.single.part.id, 'b-product');
    await cart.saved;
    await cart.openAccount(
        accountKey: null,
        storage: storage,
        loadProduct: (id) async => part(id));
    expect(cart.isEmpty, isTrue);
    expect(storage.values.keys, containsAll(['a', 'b']));
  });

  test(
      'write failures show recovery and later successful writes clear the warning',
      () async {
    final storage = MemoryDrafts();
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'a', storage: storage, loadProduct: (id) async => part(id));
    storage.failWrite = true;
    cart.addOrIncrement(part('p1'), precioUnitarioAliadoRef: 10);
    await cart.saved;
    expect(cart.storageMessage, isNotNull);
    storage.failWrite = false;
    cart.setQuantity('p1', 12);
    cart.setQuantity('p1', 13);
    await cart.saved;
    expect(cart.storageMessage, isNull);
    expect(
        (jsonDecode(storage.values['a']!)['lines'] as List).single['quantity'],
        13);
  });

  test('invalid draft requires explicit reset before a fresh cart is saved',
      () async {
    final storage = MemoryDrafts()..values['a'] = 'invalid json';
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'a', storage: storage, loadProduct: (id) async => part(id));
    expect(cart.invalidDraft, isTrue);
    expect(cart.canEdit, isFalse);
    expect(storage.values['a'], 'invalid json');
    cart.discardInvalidDraft();
    await cart.saved;
    expect(cart.canEdit, isTrue);
    expect(jsonDecode(storage.values['a']!)['lines'], isEmpty);
  });

  test('same business names never merge supplier minimums', () {
    final cart = CartService();
    cart.addOrIncrement(part('a', owner: 'a', minAmount: 100),
        precioUnitarioAliadoRef: 10);
    cart.addOrIncrement(part('b', owner: 'b', minAmount: 100),
        precioUnitarioAliadoRef: 10);
    expect(cart.supplierGroups.length, 2);
    expect(cart.totalRef(), 100);
    expect(cart.meetsAllImporterMinOrders, isFalse);
    expect(
        cart.importerMinOrderProgress().map((p) => p.importerId), ['a', 'b']);
  });
}

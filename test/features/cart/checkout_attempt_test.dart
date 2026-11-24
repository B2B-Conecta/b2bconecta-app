import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/checkout_attempt.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'cart_draft_test.dart' show MemoryDrafts, part;

void main() {
  test('canonical fingerprint ignores map order but distinguishes choices', () {
    expect(
        CheckoutAttempt.signatureFor({
          'b': {'y': 2, 'x': 1},
          'a': 1
        }),
        CheckoutAttempt.signatureFor({
          'a': 1,
          'b': {'x': 1, 'y': 2}
        }));
    expect(CheckoutAttempt.signatureFor({'currency': 'USD'}),
        isNot(CheckoutAttempt.signatureFor({'currency': 'BOLIVARES'})));
  });
  test('confirmation is saved before sending and survives reload', () async {
    final storage = MemoryDrafts();
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'sandbox:a',
        storage: storage,
        loadProduct: (id) async => part(id));
    cart.addOrIncrement(part('p'), precioUnitarioAliadoRef: 10);
    final signature = CheckoutAttempt.signatureFor({'p': 5});
    final attempt = await cart.prepareCheckoutAttempt(signature,
        resolve: (_) async => null);
    expect(CheckoutAttempt.fromJson(attempt.toJson())?.id, attempt.id);
    final restored = CartService();
    await restored.openAccount(
        accountKey: 'sandbox:a',
        storage: storage,
        loadProduct: (id) async => part(id));
    expect(restored.pendingCheckoutAttempt?.id, attempt.id);
    await expectLater(
        restored.prepareCheckoutAttempt(signature,
            resolve: (_) async => 'placed-order'),
        throwsA(isA<CheckoutRecoveredException>()
            .having((e) => e.samePayload, 'samePayload', true)));
    expect(restored.itemCount, 5);
    restored.completeCheckout();
    await restored.saved;
    expect(restored.pendingCheckoutAttempt, isNull);
    expect(restored.isEmpty, isTrue);
  });
  test('offline resolution never replaces an uncertain attempt', () async {
    final cart = CartService();
    final attempt = await cart.prepareCheckoutAttempt(
        CheckoutAttempt.signatureFor({'p': 5}),
        resolve: (_) async => null);
    await expectLater(
        cart.prepareCheckoutAttempt(CheckoutAttempt.signatureFor({'p': 10}),
            resolve: (_) async => throw StateError('offline')),
        throwsStateError);
    expect(cart.pendingCheckoutAttempt?.id, attempt.id);
    final next = await cart.prepareCheckoutAttempt(
        CheckoutAttempt.signatureFor({'p': 10}),
        resolve: (_) async => null);
    expect(next.id, isNot(attempt.id));
  });
  test('failed local persistence blocks sending and accounts stay isolated',
      () async {
    final storage = MemoryDrafts();
    final cart = CartService();
    await cart.openAccount(
        accountKey: 'a', storage: storage, loadProduct: (id) async => part(id));
    storage.failWrite = true;
    await expectLater(
        cart.prepareCheckoutAttempt(CheckoutAttempt.signatureFor({}),
            resolve: (_) async => null),
        throwsStateError);
    storage.failWrite = false;
    await cart.openAccount(
        accountKey: 'b', storage: storage, loadProduct: (id) async => part(id));
    expect(cart.pendingCheckoutAttempt, isNull);
  });
}

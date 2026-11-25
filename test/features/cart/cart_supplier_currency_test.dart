import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/cart_quantity_field.dart';
import 'package:motolink_pro_app/features/cart/min_order_currency.dart';
import 'package:motolink_pro_app/features/cart/mobile_checkout_screen.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'mobile_checkout_test.dart' as fixture;
import 'checkout_delivery_flow_test.dart' show press;

void main() {
  final cart = CartService.instance;
  setUp(cart.clear);
  tearDown(cart.clear);
  void seed({bool onlyUsd = false}) {
    for (final owner in ['one', 'two']) {
      cart.addOrIncrement(
          PartModel(
              id: owner,
              ownerId: owner,
              ownerBusinessName: 'Proveedor $owner',
              nombre: 'Producto $owner',
              precio: 100,
              stock: 100,
              ownerPagoSoloDivisas: owner == 'one' && onlyUsd,
              discountRules: owner == 'one'
                  ? const {'usd_payment_discount_pct': 10}
                  : const {}),
          delta: 5,
          precioUnitarioAliadoRef: 100);
    }
  }

  Future<void> open(WidgetTester tester,
      {double width = 390, double scale = 1, double? rate = 10}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: CartScreen(
            profile: const ProfileModel(id: 'ally', role: 'aliado'),
            liveTasaBcv: rate,
            suggestionAutoPlay: false)));
    await tester.pumpAndSettle();
  }

  Finder group(String owner) =>
      find.byKey(ValueKey('supplier-currency-$owner'));
  Future<void> choose(WidgetTester tester, String owner, String label) async {
    final target =
        find.descendant(of: group(owner), matching: find.text(label));
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 180,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets('supplier units and discounted USD minimums gate delivery at $width',
        (tester) async {
      cart.addOrIncrement(
        const PartModel(
          id: 'unit-product',
          ownerId: 'unit-supplier',
          nombre: 'Repuesto por unidades',
          precio: 10,
          stock: 50,
          ownerMinOrderUnits: 10,
        ),
        delta: 8,
        precioUnitarioAliadoRef: 10,
      );
      cart.addOrIncrement(
        const PartModel(
          id: 'usd-product',
          ownerId: 'usd-supplier',
          nombre: 'Repuesto con descuento',
          precio: 12.50,
          stock: 50,
          ownerMinOrderAmountRef: 95,
          ownerMinOrderCurrency: MinOrderCurrency.usd,
          discountRules: {'usd_payment_discount_pct': 10},
        ),
        delta: 8,
        precioUnitarioAliadoRef: 12.50,
      );
      await open(tester, width: width);

      final scroll = find.byType(Scrollable).first;
      final unitNotice =
          find.textContaining(RegExp('faltan 2 unidades', caseSensitive: false));
      final amountNotice = find.text('Llevas 90 USD de 95 USD');
      final next = find.widgetWithText(FilledButton, 'Continuar con la entrega →');
      expect(unitNotice, findsOneWidget);
      await tester.scrollUntilVisible(amountNotice, 120, scrollable: scroll);
      expect(amountNotice, findsOneWidget);
      await tester.scrollUntilVisible(next, 120, scrollable: scroll);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      cart.setQuantity('usd-product', 9);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      cart.setQuantity('usd-product', 8);
      cart.setQuantity('unit-product', 10);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(next).onPressed, isNull);

      cart.setQuantity('usd-product', 9);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'mobile supplier choices reprice only that supplier at scale $scale',
        (tester) async {
      seed();
      await open(tester, width: 320, scale: scale);
      await choose(tester, 'one', 'USD');
      expect(cart.supplierCurrencyPreferences, {'one': true});
      expect(
          find.descendant(of: group('one'), matching: find.text('450.00 USD')),
          findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('cart-total-usd')), 180,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('cart-total-usd')),
              matching: find.text('450.00 USD')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('cart-total-bs')),
              matching: find.text('Bs 5.000,00')),
          findsOneWidget);
      await choose(tester, 'two', 'USD');
      expect(cart.supplierCurrencyPreferences, {'one': true, 'two': true});
      await choose(tester, 'two', 'Bolívares');
      expect(cart.supplierCurrencyPreferences, {'one': true, 'two': false});
      final quantity = find.descendant(
          of: find.byKey(const ValueKey('cart-supplier-one')),
          matching: find.byType(CartQuantityField));
      await tester.scrollUntilVisible(quantity, -160,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(quantity);
      await tester.enterText(
          find.descendant(of: quantity, matching: find.byType(TextField)),
          '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(cart.itemCount, 15);
      await tester.scrollUntilVisible(group('one'), 120,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.descendant(of: group('one'), matching: find.text('900.00 USD')),
          findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('Continuar con la entrega →'), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Continuar con la entrega →'));
      await tester.pumpAndSettle();
      final checkout = tester
          .widget<MobileCheckoutScreen>(find.byType(MobileCheckoutScreen));
      expect(checkout.initialPayUsdBySupplier, {'one': true, 'two': false});
      checkout.onCurrenciesChanged!({'one': false, 'two': true});
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
      expect(cart.supplierCurrencyPreferences, {'one': false, 'two': true});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('desktop keeps both supplier currencies when entering checkout',
      (tester) async {
    seed();
    await open(tester, width: 1440);
    await choose(tester, 'one', 'USD');
    await choose(tester, 'two', 'Bolívares');
    expect(cart.supplierCurrencyPreferences, {'one': true, 'two': false});
    expect(find.text('450.00 USD'), findsWidgets);
    expect(find.text('Bs 5.000,00'), findsWidgets);
    final next = find.text('Continuar con la entrega →');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    final checkout =
        tester.widget<MobileCheckoutScreen>(find.byType(MobileCheckoutScreen));
    expect(checkout.initialPayUsdBySupplier, {'one': true, 'two': false});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'USD-only and missing BCV disable bolivares without blocking the other supplier',
      (tester) async {
    seed(onlyUsd: true);
    await open(tester);
    await choose(tester, 'one', 'Bolívares');
    expect(cart.supplierCurrencyPreferences.containsKey('one'), isFalse);
    await choose(tester, 'two', 'USD');
    await choose(tester, 'two', 'Bolívares');
    expect(cart.supplierCurrencyPreferences['two'], isFalse);
    await tester.pumpWidget(const SizedBox());
    await open(tester, rate: 0);
    await choose(tester, 'two', 'Bolívares');
    expect(find.descendant(of: group('two'), matching: find.text('500.00 USD')),
        findsOneWidget);
    expect(
        find.descendant(
            of: group('two'),
            matching: find.textContaining('falta la tasa BCV')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'review inherits the cart currencies and reports edits without losing them between steps',
      (tester) async {
    Map<String, bool>? changed;
    await tester.pumpWidget(MaterialApp(
        home: MobileCheckoutScreen(
            profile: fixture.profile,
            lines: fixture.lines(),
            initialPayUsd: false,
            initialPayUsdBySupplier: const {'one': true, 'two': false},
            onCurrenciesChanged: (value) => changed = value,
            rate: 10,
            credits: const {},
            loadCarriers: (id, {state, city, latitude, longitude}) async =>
                [fixture.carrier(id)],
            submit: (_) async => 'order-12345678')));
    await tester.pumpAndSettle();
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    final edit = find.byKey(const ValueKey('currency-one'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await press(tester, 'Bolívares · REF al BCV');
    expect(changed, {'one': false, 'two': false});
    await press(tester, 'Cambiar entrega');
    await press(tester, 'Revisar pedido →');
    expect(changed, {'one': false, 'two': false});
    expect(tester.takeException(), isNull);
  });
}

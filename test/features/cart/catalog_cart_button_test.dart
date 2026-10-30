import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/catalog_cart_button.dart';
import 'package:motolink_pro_app/features/catalog/catalog_cart_price.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/variant_cart_picker_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const buyer =
    ProfileModel(id: 'ally', role: 'aliado', accountAccessStatus: 'active');
const product = PartModel(
    id: 'p',
    nombre: 'LED stop',
    precio: 12,
    stock: 100,
    minOrderQty: 5,
    ownerId: 'supplier');

void main() {
  testWidgets('variant family opens picker without adding a default SKU',
      (tester) async {
    final cart = CartService();
    var choosing = false;
    final family = product.copyWith(variants: [
      product.copyWith(id: 'small', minOrderQty: 1, stock: 20),
      product.copyWith(id: 'large', minOrderQty: 2, stock: 20),
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 220,
                child: CatalogCartButton(
                    part: family,
                    profile: buyer,
                    cart: cart,
                    onChooseVariant: () => choosing = true)))));
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();
    expect(choosing, isTrue);
    expect(cart.isEmpty, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'variant picker confirms independent quantities and respects cancel',
      (tester) async {
    final cart = CartService();
    final small = product.copyWith(
        id: 'small',
        nombre: 'LED stop S',
        minOrderQty: 1,
        stock: 20,
        variantAttributeValue: 'S');
    final large = product.copyWith(
        id: 'large',
        nombre: 'LED stop L',
        minOrderQty: 2,
        stock: 20,
        variantAttributeValue: 'L');
    final family = product.copyWith(variants: [small, large]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 360,
                child: CatalogCartButton(
                    part: family, profile: buyer, cart: cart)))));
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar'), findsOneWidget);
    expect(cart.isEmpty, isTrue);

    // MOQ familiar = 5 (ficha). Se puede repartir: 3 + 2.
    final plusButtons = find.descendant(
      of: find.byType(VariantCartPickerSheet),
      matching: find.byIcon(Icons.add),
    );
    expect(plusButtons, findsWidgets);
    for (var i = 0; i < 3; i++) {
      await tester.tap(plusButtons.at(0));
      await tester.pump();
    }
    for (var i = 0; i < 2; i++) {
      await tester.tap(plusButtons.at(1));
      await tester.pump();
    }

    await tester.tap(find.descendant(
      of: find.byType(VariantCartPickerSheet),
      matching: find.text('Agregar al carrito'),
    ));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 3 + 2);
    expect(cart.lines.map((line) => line.part.id).toSet(),
        {'small', 'large'});

    // Re-open and cancel leaves cart unchanged.
    final before = cart.itemCount;
    await tester.tap(find.text('Agregar al carrito').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cart.itemCount, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'quick add becomes an editable quantity picker with minimum and stock limits',
      (tester) async {
    final cart = CartService();
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CatalogCartButton(
                part: product,
                profile: buyer,
                cart: cart,
                onOpenCart: () => opened = true))));
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();
    expect(cart.itemCount, 5);
    expect(cart.totalRef(), 60);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
            .onPressed,
        isNull);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(cart.itemCount, 6);
    await tester.enterText(find.byType(TextField), '1000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(cart.itemCount, 100);
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(cart.itemCount, 5);
    expect(opened, isFalse);
  });

  testWidgets(
      'quantity edits preserve published USD and REF while cart calculates volume',
      (tester) async {
    const priced = PartModel(
        id: 'volume',
        nombre: 'Pastilla',
        precio: 100,
        salePriceUsd: 90,
        stock: 100,
        minOrderQty: 5,
        ownerId: 'supplier',
        activeCampaignDiscountPercent: 15,
        discountRules: {
          'volume_tiers': [
            {'min_units': 10, 'percent_discount': 20}
          ],
          'usd_payment_discount_pct': 5,
        });
    final cart = CartService();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 180,
                child: Column(children: [
                  CatalogCartPrice(part: priced, cart: cart, bcvRate: 10),
                  CatalogCartButton(part: priced, profile: buyer, cart: cart),
                ])))));
    await tester.pump();
    expect(find.text('90.00 USD'), findsOneWidget);
    expect(find.text('100.00 REF'), findsOneWidget);
    expect(find.text('Bs 1.000,00'), findsOneWidget);
    expect(tester.getTopLeft(find.text('90.00 USD')).dy,
        lessThan(tester.getTopLeft(find.text('100.00 REF')).dy));
    expect(tester.getTopLeft(find.text('100.00 REF')).dy,
        lessThan(tester.getTopLeft(find.text('Bs 1.000,00')).dy));
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(cart.lines.single.precioUnitarioAliadoRef, 80);
    expect(cart.totalRef(), 800);
    expect(find.text('100.00 REF'), findsOneWidget);
    expect(find.text('90.00 USD'), findsOneWidget);
    expect(find.text('Bs 1.000,00'), findsOneWidget);
    expect(find.text('80.00 REF'), findsNothing);
    expect(find.text('76.00 USD'), findsNothing);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(cart.itemCount, 9);
    expect(cart.lines.single.precioUnitarioAliadoRef, 85);
    expect(find.text('100.00 REF'), findsOneWidget);
    expect(find.text('90.00 USD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'USD is not duplicated or offered for a foreign-currency-only supplier',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      CatalogProductPriceDisplay(
          listPriceUsd: 12, catalogGrid: true, bcvRate: 10),
      CatalogProductPriceDisplay(
          listPriceUsd: 20,
          catalogGrid: true,
          bcvRate: 10,
          ownerPagoSoloDivisas: true,
          discountRules: {'usd_payment_discount_pct': 5}),
    ]))));
    await tester.pump();
    expect(find.text('12.00 REF'), findsOneWidget);
    // Solo divisas: el precio de lista se etiqueta USD (sin incentivo %).
    expect(find.text('20.00 USD'), findsOneWidget);
    expect(find.text('20.00 REF'), findsNothing);
    expect(find.text('Bs 200,00'), findsNothing);
    expect(find.text('Precio USD'), findsNothing);
    expect(find.textContaining('19.00 USD'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'solo-divisas list price shows as USD without Bs and keeps promo USD first',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      CatalogProductPriceDisplay(
          listPriceUsd: 12,
          catalogGrid: true,
          bcvRate: 10,
          ownerPagoSoloDivisas: true),
      CatalogProductPriceDisplay(
          listPriceUsd: 12,
          salePriceUsd: 10,
          catalogGrid: true,
          bcvRate: 10,
          ownerPagoSoloDivisas: true),
    ]))));
    await tester.pump();
    expect(find.text('12.00 USD'), findsWidgets);
    expect(find.text('10.00 USD'), findsOneWidget);
    expect(find.textContaining('REF'), findsNothing);
    expect(find.textContaining('Bs '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'restoring or a suspended account cannot edit quantities already in the cart',
      (tester) async {
    final cart = CartService();
    CartProductActions.addMinimum(part: product, profile: buyer, cart: cart);
    cart.restoring = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 150,
                child: CatalogCartButton(
                    part: product, profile: buyer, cart: cart)))));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    CartProductActions.setQuantity(
        part: product, profile: buyer, cart: cart, quantity: 10);
    expect(cart.itemCount, 5);
    cart.restoring = false;
    const suspended = ProfileModel(
        id: 'ally',
        role: 'aliado',
        accountAccessStatus: 'active',
        pedidosSuspendidosMorosidad: true);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 150,
                child: CatalogCartButton(
                    part: product, profile: suspended, cart: cart)))));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    CartProductActions.setQuantity(
        part: product, profile: suspended, cart: cart, quantity: 10);
    expect(cart.itemCount, 5);
    expect(tester.takeException(), isNull);
  });

  test('repeated activation never increments an existing product', () {
    final cart = CartService();
    expect(
        CartProductActions.addMinimum(
            part: product, profile: buyer, cart: cart),
        5);
    expect(
        CartProductActions.addMinimum(
            part: product, profile: buyer, cart: cart),
        0);
    expect(cart.itemCount, 5);
  });

  test(
      'a cart being restored and products without an owner cannot be overwritten by quick add',
      () {
    final cart = CartService()..restoring = true;
    expect(
        CartProductActions.addMinimum(
            part: product, profile: buyer, cart: cart),
        0);
    expect(cart.isEmpty, isTrue);
    cart.restoring = false;
    expect(
        CartProductActions.addMinimum(
            part: const PartModel(
                id: 'no-owner', nombre: 'Repuesto', precio: 12, stock: 100),
            profile: buyer,
            cart: cart),
        0);
    expect(cart.isEmpty, isTrue);
  });

  for (final scenario in [
    (part: product.copyWith(stock: 0), profile: buyer),
    (part: product.copyWith(stock: 4), profile: buyer),
    (part: product.copyWith(isActive: false), profile: buyer),
    (
      part: product,
      profile: const ProfileModel(
          id: 'ally',
          role: 'aliado',
          accountAccessStatus: 'active',
          pedidosSuspendidosMorosidad: true)
    ),
    (
      part: product,
      profile: const ProfileModel(
          id: 'ally', role: 'aliado', accountAccessStatus: 'rejected')
    ),
  ]) {
    testWidgets(
        'quick add respects stock and account restrictions: ${scenario.part.stock}, ${scenario.profile.accountAccessStatus}, ${scenario.profile.pedidosSuspendidosMorosidad}',
        (tester) async {
      final cart = CartService();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CatalogCartButton(
                  part: scenario.part,
                  profile: scenario.profile,
                  cart: cart))));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(
          CartProductActions.addMinimum(
              part: scenario.part, profile: scenario.profile, cart: cart),
          0);
      expect(cart.isEmpty, isTrue);
    });
  }
}

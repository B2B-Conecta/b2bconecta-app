import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const buyer =
    ProfileModel(id: 'buyer', role: 'aliado', accountAccessStatus: 'active');

void main() {
  test('unit quotes round to the same four decimal places as Postgres', () {
    expect(
        ProductCatalogPricing.aliadoUnitRef(listPriceUsd: 52.123456), 52.1235);
    expect(
        ProductCatalogPricing.aliadoUnitUsdPaymentLine(
            refUnitUsd: 52.1235, salePriceUsd: 48.123456),
        48.1235);
  });
  for (final sale in [null, 48.0, 60.0, 0.0]) {
    test('REF stays 52 and divisas use only a valid USD offer: $sale', () {
      final part = PartModel(
          id: 'product',
          nombre: 'Disco',
          precio: 52,
          salePriceUsd: sale,
          stock: 100);
      final ref = part.precioUnitarioParaAliado(quantity: 5);
      expect(ref, 52);
      expect(
          ProductCatalogPricing.aliadoUnitUsdPaymentLine(
              refUnitUsd: ref, salePriceUsd: sale),
          sale == 48 ? 48 : 52);
    });
  }

  for (final onlyDivisas in [false, true]) {
    testWidgets(
        'missing BCV or supplier restriction requires divisas: $onlyDivisas',
        (tester) async {
      final cart = CartService.instance..clear();
      addTearDown(cart.clear);
      CartProductActions.addMinimum(
          part: PartModel(
              id: 'product',
              ownerId: 'supplier',
              nombre: 'Disco',
              precio: 52,
              salePriceUsd: 48,
              stock: 100,
              ownerPagoSoloDivisas: onlyDivisas),
          profile: buyer,
          cart: cart);
      await tester.pumpWidget(MaterialApp(
          home: CartScreen(
              profile: buyer, liveTasaBcv: onlyDivisas ? 10 : null)));
      await tester.pumpAndSettle();
      final continueButton =
          find.widgetWithText(FilledButton, 'Continuar con la entrega');
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      expect(find.text('260.00 REF'), findsWidgets);
      if (!onlyDivisas) {
        expect(find.text('Sin tasa'), findsWidgets);
        expect(find.text('Tasa BCV: 1 REF ='), findsNothing);
      }
      await tester.ensureVisible(find.text('Divisas (USD)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Divisas (USD)'));
      await tester.pumpAndSettle();
      expect(find.text('240.00 USD'), findsWidgets);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
      'volume excludes campaign; direct USD does not lower REF or stack USD incentives',
      () {
    const rules = {
      'volume_tiers': [
        {'min_units': 10, 'percent_discount': 20}
      ],
      'usd_payment_discount_pct': 5
    };
    final ref = ProductCatalogPricing.aliadoUnitRef(
        listPriceUsd: 100,
        discountRules: rules,
        quantity: 10,
        campaignDiscountPercent: 15);
    expect(ref, 80);
    expect(
        ProductCatalogPricing.aliadoUnitUsdPaymentLine(
            refUnitUsd: ref, salePriceUsd: 90, discountRules: rules),
        76);
    expect(
        ProductCatalogPricing.aliadoUnitUsdPaymentLine(
            refUnitUsd: 100, salePriceUsd: 90, discountRules: rules),
        90);
  });

  for (final sale in [null, 48.0]) {
    testWidgets('cart pairs REF with BCV Bs and keeps divisas for offer $sale',
        (tester) async {
      final cart = CartService.instance..clear();
      addTearDown(cart.clear);
      final part = PartModel(
          id: 'product',
          ownerId: 'supplier',
          nombre: 'Disco',
          precio: 52,
          salePriceUsd: sale,
          stock: 100);
      CartProductActions.addMinimum(part: part, profile: buyer, cart: cart);
      await tester.pumpWidget(
          const MaterialApp(home: CartScreen(profile: buyer, liveTasaBcv: 10)));
      await tester.pumpAndSettle();
      expect(cart.totalRef(), 260);
      expect(find.textContaining('52.00 REF / ud'), findsOneWidget);
      expect(find.text('260.00 REF'), findsWidgets);
      expect(find.text('Bolívares (REF)'), findsOneWidget);
      expect(find.text('Divisas (USD)'), findsOneWidget);
      expect(find.text('Bolívares'), findsNothing);
      expect(find.text('REF'), findsNothing);
      expect(find.text('Bs 520,00'), findsOneWidget);
      expect(find.text('Bs 2.600,00'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Divisas (USD)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Divisas (USD)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('${(sale ?? 52).toStringAsFixed(2)} USD / ud'),
          findsOneWidget);
      expect(find.text('${((sale ?? 52) * 5).toStringAsFixed(2)} USD'),
          findsWidgets);
      expect(find.text('Tasa BCV: 1 REF ='), findsNothing);
      expect(find.text('Bs 2.600,00'), findsNothing);
      await tester.tap(find.text('Bolívares (REF)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('52.00 REF / ud'), findsOneWidget);
      expect(find.text('Bs 520,00'), findsOneWidget);
      expect(find.text('Bs 2.600,00'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
      'new order freezes divisas without relabeling them as REF or discounting twice',
      () {
    final order = TransactionRequestModel.fromJson({
      'id': 'order',
      'aliado_id': 'buyer',
      'product_id': 'product',
      'importador_id': 'supplier',
      'status': 'pendiente',
      'cantidad': 5,
      'precio_total_usd': 240,
      'precio_base_aliado_total': 240,
      'total_ref': 260,
      'total_bs': 2600,
      'metodo_pago_moneda': 'DIVISAS',
      'discount_rules': {'checkout_pricing_version': 1},
      'product': {
        'discount_rules': {'usd_payment_discount_pct': 5}
      },
    });
    expect(order.amountCurrencyLabel, 'USD');
    expect(order.totalRef, 260);
    expect(order.precioTotalBsUi, 2600);
    expect(order.totalForPagoMetodo('zelle_divisas'), 240);
    expect(order.metodosPagoPermitidos, contains('zelle_divisas'));
    expect(order.metodosPagoPermitidos, isNot(contains('pago_movil')));
    expect(orderAmountCurrency([order]), 'USD');
  });
}

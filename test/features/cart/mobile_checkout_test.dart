import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/mobile_checkout_model.dart';
import 'package:motolink_pro_app/features/cart/mobile_checkout_screen.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/logistics/importer_carrier_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const profile = ProfileModel(
    id: 'ally',
    role: 'aliado',
    businessName: 'Taller Moto Ruices C.A.',
    estado: 'Miranda',
    ciudad: 'Caracas',
    direccion: 'Los Ruices, local 14',
    fiscalMapsUrl: 'https://maps.app.goo.gl/test');
List<CartLine> lines() => [
      CartLine(
          part: const PartModel(
              id: 'p1',
              ownerId: 'one',
              ownerBusinessName: 'Importadora Valencia',
              nombre: 'Disco EBC 245 mm',
              precio: 52,
              stock: 100),
          quantity: 5,
          precioUnitarioAliadoRef: 52),
      CartLine(
          part: const PartModel(
              id: 'p2',
              ownerId: 'two',
              ownerBusinessName: 'Motopartsvlz',
              nombre: 'Casco Venture 1.0 MIPS',
              precio: 80,
              stock: 100),
          quantity: 5,
          precioUnitarioAliadoRef: 80),
    ];
ImporterCarrierModel carrier(String supplier,
        {String? id,
        double? fee = 6,
        bool active = true,
        bool covers = true}) =>
    ImporterCarrierModel(
        id: id ?? 'carrier-$supplier',
        importadorId: supplier,
        companyName: 'Transporte $supplier',
        contactPhone: '02120000000',
        feeUsd: fee,
        isActive: active,
        coversDestination: covers);

void main() {
  Future<void> press(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    var target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 180,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester,
      {double width = 390,
      double scale = 1,
      bool payUsd = false,
      double? rate = 10,
      List<CartLine>? cartLines,
      ProfileModel buyer = profile,
      CheckoutCarrierLoader? loader,
      Future<String> Function(MobileCheckoutSubmission)? submit}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: MobileCheckoutScreen(
            profile: buyer,
            lines: cartLines ?? lines(),
            initialPayUsd: payUsd,
            rate: rate,
            credits: const {'one': 10},
            loadCarriers: loader ??
                (id, {state, city, latitude, longitude}) async => [carrier(id)],
            submit: submit ?? (_) async => 'order-12345678')));
    await tester.pumpAndSettle();
  }

  test('totals cap credit per supplier and keep unknown shipping separate', () {
    final totals = MobileCheckoutTotals(
        lines: lines(),
        payUsd: false,
        credits: const {'one': 900, 'two': 10},
        carriers: {'one': carrier('one')},
        supplierCount: 2,
        rate: 10);
    expect(totals.products, 660);
    expect(totals.credit, 270);
    expect(totals.netProducts, 390);
    expect(totals.quotedShippingUsd, 6);
    expect(totals.shippingPending, isTrue);
    expect(totals.estimatedTotal, isNull);
  });

  testWidgets(
      'review shows currency summary; optional change preserves delivery and reaches submission',
      (tester) async {
    MobileCheckoutSubmission? sent;
    await open(tester, width: 320, scale: 1.6, submit: (value) async {
      sent = value;
      return 'order-12345678';
    });
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    await press(tester, 'Cambiar');
    expect(find.text('Bolívares · REF al BCV'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Bolívares al BCV'), findsWidgets);
    expect(find.byType(RadioListTile<bool>), findsNothing);
    await press(tester, 'Cambiar');
    await press(tester, 'Divisas · USD');
    expect(find.text('USD'), findsOneWidget);
    expect(find.byType(RadioListTile<bool>), findsNothing);
    await press(tester, 'Cambiar entrega');
    await press(tester, 'Revisar pedido →');
    await press(tester, 'Confirmar pedido');
    expect(sent!.paysUsd('one'), isTrue);
    expect(sent!.paysUsd('two'), isFalse);
    expect(sent!.carriers['one']!['carrier_id'], 'carrier-one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('currency change keeps bolivares disabled without a BCV rate',
      (tester) async {
    await open(tester, payUsd: true, rate: null);
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    await press(tester, 'Cambiar');
    final bs = tester.widget<RadioListTile<bool>>(find.ancestor(
        of: find.text('Bolívares · REF al BCV'),
        matching: find.byType(RadioListTile<bool>)));
    expect(bs.onChanged, isNull);
    expect(find.text('No hay una tasa BCV disponible.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('known shipping yields an explicit estimate; zero differs from null',
      () {
    final totals = MobileCheckoutTotals(
        lines: lines(),
        payUsd: false,
        credits: const {'one': 10},
        carriers: {
          'one': carrier('one', fee: 0),
          'two': carrier('two', fee: 4)
        },
        supplierCount: 2,
        rate: 10);
    expect(totals.shippingPending, isFalse);
    expect(totals.estimatedTotal, 654);
    expect(totals.estimatedBs, 6540);
    final unknown = MobileCheckoutTotals(
        lines: lines(),
        payUsd: true,
        credits: const {},
        carriers: {
          'one': carrier('one', fee: null),
          'two': carrier('two', fee: 4)
        },
        supplierCount: 2);
    expect(unknown.shippingPending, isTrue);
    expect(unknown.estimatedTotal, isNull);
  });

  test(
      'USD incentive applies only to the selected supplier; totals keep currencies separate',
      () {
    final cartLines = [
      CartLine(
          part: const PartModel(
              id: 'discount',
              ownerId: 'one',
              nombre: 'Oferta',
              precio: 100,
              stock: 100,
              discountRules: {'usd_payment_discount_pct': 10}),
          quantity: 5,
          precioUnitarioAliadoRef: 100),
      ...lines().where((line) => line.part.ownerId == 'two'),
    ];
    final totals = MobileCheckoutTotals(
        lines: cartLines,
        payUsd: false,
        payUsdBySupplier: const {'one': true, 'two': false},
        credits: const {'one': 20, 'two': 10},
        carriers: {'one': carrier('one'), 'two': carrier('two', fee: 4)},
        supplierCount: 2,
        rate: 10);
    expect(totals.suppliers['one']!.products, 450);
    expect(totals.suppliers['one']!.usdSavings, 50);
    expect(totals.suppliers['two']!.products, 400);
    expect(totals.netUsd, 430);
    expect(totals.netRef, 390);
    expect(totals.mixedCurrencies, isTrue);
    expect(totals.estimatedTotal, isNull);
    expect(totals.estimatedBs, isNull);
    expect(totals.quotedShippingUsd, 10);
  });

  testWidgets(
      'supplier-only USD does not block bolivares for a different supplier',
      (tester) async {
    final cartLines = lines();
    cartLines[0] = CartLine(
        part: cartLines[0].part.copyWith(ownerPagoSoloDivisas: true),
        quantity: 5,
        precioUnitarioAliadoRef: 52);
    MobileCheckoutSubmission? sent;
    await open(tester, cartLines: cartLines, submit: (value) async {
      sent = value;
      return 'order-12345678';
    });
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    final firstCurrency = find.byKey(const ValueKey('currency-one'));
    await tester.ensureVisible(firstCurrency);
    await tester.tap(firstCurrency);
    await tester.pumpAndSettle();
    final bs = tester.widget<RadioListTile<bool>>(find.ancestor(
        of: find.text('Bolívares · REF al BCV'),
        matching: find.byType(RadioListTile<bool>)));
    expect(bs.onChanged, isNull);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('USD + Bs'), findsWidgets);
    await press(tester, 'Confirmar pedido');
    expect(sent!.currenciesBySupplier, {'one': 'DIVISAS', 'two': 'BOLIVARES'});
  });

  testWidgets(
      'delivery total is visible next to continue and updates to the chosen tariff',
      (tester) async {
    await open(tester,
        loader: (id, {state, city, latitude, longitude}) async => id == 'one'
            ? [carrier(id, id: 'fast', fee: 6), carrier(id, id: 'slow', fee: 4)]
            : [carrier(id, fee: 0)]);
    await press(tester, 'Continuar con la entrega →');
    expect(find.text('Envíos (2 proveedores)').hitTestable(), findsOneWidget);
    final options = find.byType(RadioListTile<String>);
    await tester.ensureVisible(options.first);
    await tester.tap(options.first);
    await tester.pumpAndSettle();
    expect(find.text('6.00 USD estimados').hitTestable(), findsOneWidget);
    await tester.ensureVisible(options.at(1));
    await tester.tap(options.at(1));
    await tester.pumpAndSettle();
    expect(find.text('4.00 USD estimados').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [(320.0, 1.0), (390.0, 1.6)]) {
    testWidgets(
        'three steps and confirmation fit $size, transport persists and submit runs once',
        (tester) async {
      final sent = <MobileCheckoutSubmission>[];
      await open(tester, width: size.$1, scale: size.$2, submit: (value) async {
        sent.add(value);
        return 'order-12345678';
      });
      await press(tester, 'Continuar con la entrega →');
      await press(tester, 'Revisar pedido →');
      expect(sent, isEmpty);
      await press(tester, 'Cambiar entrega');
      await press(tester, 'Revisar pedido →');
      await press(tester, 'Confirmar pedido');
      expect(sent, hasLength(1));
      expect(sent.single.carriers['one']!['carrier_id'], 'carrier-one');
      expect(sent.single.destination.useProfile, isTrue);
      expect(find.text('¡Tu pedido fue enviado!'), findsOneWidget);
      expect(find.textContaining('Referencia: #ORDER-12'), findsOneWidget);
      expect(find.text('Ver pedido'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'empty carrier configuration stays pending, never invents free pickup',
      (tester) async {
    await open(tester,
        loader: (id, {state, city, latitude, longitude}) async => []);
    await press(tester, 'Continuar con la entrega →');
    expect(find.text('Entrega a coordinar con el proveedor'), findsWidgets);
    await press(tester, 'Revisar pedido →');
    expect(find.text('Subtotal productos').hitTestable(), findsOneWidget);
    expect(find.text('Total estimado'), findsNothing);
    expect(find.textContaining('Retiro en tienda'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed transport load cannot confirm until a successful retry',
      (tester) async {
    var fail = true;
    await open(tester, loader: (id, {state, city, latitude, longitude}) async {
      if (fail) throw Exception('offline');
      return [carrier(id)];
    });
    await press(tester, 'Continuar con la entrega →');
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
                of: find.text('Revisar pedido →'),
                matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    fail = false;
    await press(tester, 'Reintentar transporte');
    await press(tester, 'Revisar pedido →');
    expect(find.text('Revisa tu pedido'), findsOneWidget);
  });

  testWidgets(
      'alternate address validates, survives back and invalidates destination quotes',
      (tester) async {
    final destinations = <String>[];
    await open(tester, loader: (id, {state, city, latitude, longitude}) async {
      destinations.add('$state/$city');
      return [carrier(id)];
    });
    await press(tester, 'Otra dirección');
    await press(tester, 'Continuar con la entrega →');
    expect(find.text('Dirección de entrega'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      final field = find.byType(TextFormField).at(i);
      if (field.evaluate().isEmpty) {
        await tester.scrollUntilVisible(field, 140,
            scrollable: find.byType(Scrollable).first);
      }
      await tester.ensureVisible(field);
      await tester.enterText(
          field, ['Carabobo', 'Valencia', 'Calle 1, galpón 3', 'https:'][i]);
    }
    await press(tester, 'Continuar con la entrega →');
    expect(find.text('Usa un enlace completo: https://…'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.enterText(
        find.byType(TextFormField).last, 'https://maps.app.goo.gl/other');
    await press(tester, 'Continuar con la entrega →');
    expect(destinations, ['Carabobo/Valencia', 'Carabobo/Valencia']);
    await press(tester, 'Cambiar dirección');
    await press(tester, 'Mi tienda');
    await press(tester, 'Continuar con la entrega →');
    expect(destinations.last, 'Miranda/Caracas');
    expect(destinations.length, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('send in progress blocks duplicate confirmation and back',
      (tester) async {
    final pending = Completer<String>();
    var sends = 0;
    await open(tester, submit: (_) {
      sends++;
      return pending.future;
    });
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(sends, 1);
    expect(find.byType(MobileCheckoutScreen), findsOneWidget);
    pending.complete('order-12345678');
    await tester.pumpAndSettle();
    expect(find.text('¡Tu pedido fue enviado!'), findsOneWidget);
  });

  testWidgets('ineligible transport is excluded and failures retain the review',
      (tester) async {
    await open(tester,
        loader: (id, {state, city, latitude, longitude}) async => [
              carrier(id),
              carrier(id, id: 'off', active: false),
              carrier(id, id: 'far', covers: false)
            ],
        submit: (_) async => throw const MobileCheckoutException(
            'El stock cambió. Revisa tu bolsa.'));
    await press(tester, 'Continuar con la entrega →');
    await press(tester, 'Revisar pedido →');
    await press(tester, 'Confirmar pedido');
    expect(find.text('El stock cambió. Revisa tu bolsa.'), findsOneWidget);
    expect(find.text('Revisa tu pedido'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

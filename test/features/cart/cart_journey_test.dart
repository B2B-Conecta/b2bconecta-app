import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_quantity_field.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

void main() {
  for (final scenario in [
    (size: const Size(1440, 900), scale: 1.0),
    (size: const Size(320, 740), scale: 1.0),
    (size: const Size(390, 844), scale: 1.6),
  ]) {
    testWidgets(
        'Bs and the full cart amount stay together at ${scenario.size}, text ${scenario.scale}',
        (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cart = CartService.instance..clear();
      addTearDown(cart.clear);
      cart.addOrIncrement(
          const PartModel(
              id: 'bs-line',
              ownerId: 'supplier',
              nombre: 'Disco EBC 245 mm',
              precio: 52,
              stock: 90),
          delta: 5,
          precioUnitarioAliadoRef: 52);
      await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!),
          home: const CartScreen(
              profile: ProfileModel(id: 'ally', role: 'aliado'),
              liveTasaBcv: 881.8769)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bolívares (REF)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bolívares (REF)'));
      await tester.pumpAndSettle();
      final amounts = find.text('Bs 229.287,99');
      expect(amounts, findsNWidgets(2));
      expect(find.text('260.00 REF'), findsNWidgets(2));
      expect(find.text('Tasa BCV: 1 REF ='), findsOneWidget);
      expect(find.text('Bs 881,8769'), findsOneWidget);
      for (final element in amounts.evaluate()) {
        final paragraph = tester.renderObject<RenderParagraph>(find.descendant(
            of: find.byElementPredicate((candidate) => candidate == element),
            matching: find.byType(RichText)));
        final boxes = paragraph.getBoxesForSelection(const TextSelection(
            baseOffset: 0, extentOffset: 'Bs 229.287,99'.length));
        expect(boxes.map((box) => box.top).toSet(), hasLength(1),
            reason: 'The currency and complete amount must share one line.');
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('cart currency tabs preserve effective volume prices',
      (tester) async {
    final cart = CartService.instance..clear();
    addTearDown(cart.clear);
    const part = PartModel(
        id: 'volume-cart',
        nombre: 'Pastilla con volumen',
        ownerId: 'supplier',
        precio: 100,
        salePriceUsd: 90,
        stock: 100,
        discountRules: {
          'volume_tiers': [
            {'min_units': 10, 'percent_discount': 20}
          ],
          'usd_payment_discount_pct': 5,
        });
    cart.addOrIncrement(part, delta: 10, precioUnitarioAliadoRef: 80);
    await tester.pumpWidget(const MaterialApp(
        home: CartScreen(
            profile: ProfileModel(
                id: 'ally', role: 'aliado', accountAccessStatus: 'active'),
            liveTasaBcv: 10)));
    await tester.pumpAndSettle();
    expect(find.textContaining('80.00 REF / ud'), findsOneWidget);
    await tester.ensureVisible(find.text('Divisas (USD)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Divisas (USD)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('76.00 USD / ud'), findsOneWidget);
    expect(find.textContaining('760.00 USD'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('direct quantity accepts units and clamps to minimum and stock',
      (tester) async {
    var quantity = 5;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => CartQuantityField(
                    quantity: quantity,
                    minimum: 5,
                    maximum: 25,
                    onChanged: (value) => setState(() => quantity = value))))));
    Future<void> edit(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    await edit('17');
    expect(quantity, 17);
    await edit('1');
    expect(quantity, 5);
    await edit('999999');
    expect(quantity, 25);
    await edit('');
    expect(quantity, 25);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(390, 844),
    const Size(1440, 900),
    const Size(568, 320)
  ]) {
    testWidgets('cart supports quantity and undo at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cart = CartService.instance..clear();
      addTearDown(cart.clear);
      cart.addOrIncrement(
          const PartModel(
              id: 'p1',
              ownerId: 'supplier',
              ownerBusinessName: 'Distribuidora de Repuestos',
              nombre: 'Pastillas de freno delanteras',
              precio: 12,
              stock: 100),
          precioUnitarioAliadoRef: 12);
      await tester.pumpWidget(const MaterialApp(
          home: CartScreen(
              profile: ProfileModel(id: 'ally', role: 'aliado'),
              liveTasaBcv: 50)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Revisa tu compra'), findsOneWidget);
      final productScroll = find
          .descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.byType(CartQuantityField), 80,
          scrollable: productScroll);
      await tester.enterText(find.byType(TextField), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(cart.itemCount, 12);
      await tester.scrollUntilVisible(find.text('Resumen del pedido'), 100,
          scrollable: productScroll);
      expect(find.text('Resumen del pedido'), findsOneWidget);
      if (size.width == 390) {
        await tester.ensureVisible(find.text('Continuar con la entrega'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar con la entrega'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Confirmar pedido'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(cart.itemCount, 12);
      }
      await tester.scrollUntilVisible(find.byTooltip('Quitar del carrito'), -80,
          scrollable: productScroll);
      await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Quitar del carrito')),
          alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar del carrito'));
      await tester.pumpAndSettle();
      expect(find.text('Su carrito está vacío'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(cart.itemCount, 12);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scenario in [
    (size: const Size(320, 640), scale: 1.0, dark: false),
    (size: const Size(800, 1000), scale: 1.0, dark: false),
    (size: const Size(390, 844), scale: 1.6, dark: false),
    (size: const Size(1440, 900), scale: 1.0, dark: true),
  ]) {
    testWidgets(
        'multiple suppliers adapt at ${scenario.size}, text ${scenario.scale}, dark ${scenario.dark}',
        (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.brightness = scenario.dark ? Brightness.dark : Brightness.light;
      addTearDown(() => AppColors.brightness = Brightness.light);
      final cart = CartService.instance..clear();
      addTearDown(cart.clear);
      for (final owner in ['supplier-a', 'supplier-b']) {
        cart.addOrIncrement(
            PartModel(
                id: owner,
                ownerId: owner,
                ownerBusinessName:
                    'Distribuidora de Repuestos y Accesorios del Centro C.A.',
                nombre:
                    'Pastillas de freno delanteras para motocicleta de alta cilindrada',
                sku: 'SKU-DE-REFERENCIA-MUY-LARGO-123456789',
                precio: 12,
                stock: 100,
                ownerMinOrderAmountRef: 100),
            precioUnitarioAliadoRef: 12);
      }
      await tester.pumpWidget(MaterialApp(
          theme: scenario.dark ? buildAppDarkTheme() : buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!),
          home: const CartScreen(
              profile: ProfileModel(id: 'ally', role: 'aliado'),
              liveTasaBcv: 50)));
      await tester.pumpAndSettle();
      final productScroll = find
          .descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(find.text('Bolívares (REF)'), 150,
          scrollable: productScroll);
      await tester.ensureVisible(find.text('Bolívares (REF)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bolívares (REF)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bs'), findsWidgets);
      await tester.scrollUntilVisible(
          find.text('Continuar con la entrega'), 120,
          scrollable: productScroll);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Continuar con la entrega'))
              .onPressed,
          isNull);
      expect(cart.supplierGroups.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

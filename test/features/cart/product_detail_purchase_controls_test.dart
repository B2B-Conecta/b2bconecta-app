import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_purchase_controls.dart';
import 'package:motolink_pro_app/features/catalog/product_stock_summary.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const buyer =
    ProfileModel(id: 'ally', role: 'aliado', accountAccessStatus: 'active');
const part = PartModel(
    id: 'product',
    nombre: 'Disco',
    ownerId: 'supplier',
    precio: 52,
    salePriceUsd: 48,
    stock: 30,
    stockReserved: 5);

Future<void> pumpControls(WidgetTester tester, CartService cart,
    {PartModel product = part,
    ProfileModel profile = buyer,
    VoidCallback? onOpen,
    double scale = 1,
    bool dark = false,
    bool compact = false,
    bool reduceMotion = false}) async {
  await tester.pumpWidget(MaterialApp(
      theme: dark ? buildAppDarkTheme() : buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion),
          child: child!),
      home: Scaffold(
          body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ProductDetailPurchaseControls(
                      part: product,
                      profile: profile,
                      cart: cart,
                      compact: compact,
                      onOpenCart: onOpen ?? () {},
                      onAsk: () {}))))));
  await tester.pump();
}

void main() {
  testWidgets('switching SKU keeps separate quantities and supplier minimums',
      (tester) async {
    final cart = CartService();
    final first = part.copyWith(id: 'variant-two', minOrderQty: 2);
    final second = part.copyWith(id: 'variant-one', minOrderQty: 1);
    await pumpControls(tester, cart, product: first, compact: true);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 2);
    await tester.enterText(find.byType(TextField), '9');
    await pumpControls(tester, cart, product: second, compact: true);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pumpAndSettle();
    expect(
        cart.lines.singleWhere((line) => line.part.id == first.id).quantity, 2);
    expect(cart.lines.singleWhere((line) => line.part.id == second.id).quantity,
        1);
    await pumpControls(tester, cart, product: first, compact: true);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '2');
    expect(cart.itemCount, 3);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 640), scale: 1.6),
    (size: const Size(568, 320), scale: 1.0),
  ]) {
    testWidgets('compact add reveals quantity at the same height: $scenario',
        (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cart = CartService();
      var opened = false;
      await pumpControls(tester, cart,
          compact: true, scale: scenario.scale, onOpen: () => opened = true);
      expect(find.byType(TextField), findsNothing);
      final slot = find.byKey(const Key('compact-purchase-slot'));
      final height = tester.getSize(slot).height;
      final before = tester.getRect(slot);
      await tester.tap(find.byKey(const Key('product-purchase-action')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(cart.itemCount, 5);
      expect(
          tester
              .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
              .duration,
          const Duration(milliseconds: 220));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Ver carrito'), findsOneWidget);
      expect(tester.getSize(slot).height, closeTo(height, .1));
      expect(tester.getRect(slot).top, closeTo(before.top, .1));
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pump();
      expect(cart.itemCount, 6);
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.byTooltip('Ver carrito'));
      expect(opened, isTrue);
      expect(cart.itemCount, 12);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion reveals the control immediately', (tester) async {
    final cart = CartService();
    await pumpControls(tester, cart, compact: true, reduceMotion: true);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero);
    expect(cart.itemCount, 5);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard activation is immediate and adds once', (tester) async {
    final cart = CartService();
    await pumpControls(tester, cart, compact: true);
    Focus.of(tester.element(find.text('Agregar al carrito'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(cart.itemCount, 5);
    expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reversing the reveal quickly never duplicates a field or a line',
      (tester) async {
    final cart = CartService();
    await pumpControls(tester, cart, compact: true);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pump(const Duration(milliseconds: 30));
    cart.removeProduct(part.id);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.text('Agregar al carrito').last);
    await tester.pumpAndSettle();
    expect(cart.lines.length, 1);
    expect(cart.itemCount, 5);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choose before adding, then edit the cart in place and open it',
      (tester) async {
    final cart = CartService();
    var opened = false;
    await pumpControls(tester, cart, onOpen: () => opened = true);
    expect(find.text('Añadirás 5 unidades'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(cart.isEmpty, isTrue);
    expect(find.text('Añadirás 12 unidades'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pump();
    expect(cart.itemCount, 12);
    expect(find.text('En tu carrito: 12 unidades'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar cantidad'));
    await tester.pump();
    expect(cart.itemCount, 13);
    cart.setQuantity(part.id, 20);
    await tester.pump();
    expect(find.text('En tu carrito: 20 unidades'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '18');
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    expect(opened, isTrue);
    expect(cart.itemCount, 18);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out of range entry explains minimum and available stock',
      (tester) async {
    final cart = CartService();
    await pumpControls(tester, cart);
    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('Mínimo 5 unidades.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Disponibles 25 unidades.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pump();
    expect(cart.itemCount, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding while typing commits the visible quantity',
      (tester) async {
    final cart = CartService();
    await pumpControls(tester, cart);
    await tester.enterText(find.byType(TextField), '17');
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pump();
    expect(cart.itemCount, 17);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stepping while typing starts from the visible quantity',
      (tester) async {
    final cart = CartService();
    await pumpControls(tester, cart);
    await tester.enterText(find.byType(TextField), '17');
    await tester.tap(find.byTooltip('Aumentar cantidad'));
    await tester.pump();
    expect(find.text('Añadirás 18 unidades'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-purchase-action')));
    await tester.pump();
    expect(cart.itemCount, 18);
    expect(tester.takeException(), isNull);
  });

  for (final product in [
    part.copyWith(stock: 0),
    part.copyWith(stock: 8),
    part.copyWith(isActive: false)
  ]) {
    testWidgets(
        'unavailable product cannot add or edit: ${product.stock}, ${product.isActive}',
        (tester) async {
      final cart = CartService();
      await pumpControls(tester, cart, product: product);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const Key('product-purchase-action')))
              .onPressed,
          isNull);
      expect(cart.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'restoring cart blocks addition and a suspended account cannot edit an existing line',
      (tester) async {
    final cart = CartService()..restoring = true;
    await pumpControls(tester, cart);
    expect(find.text('Recuperando…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    cart.restoring = false;
    cart.addOrIncrement(part, delta: 8, precioUnitarioAliadoRef: 52);
    await pumpControls(tester, cart,
        profile: const ProfileModel(
            id: 'ally',
            role: 'aliado',
            accountAccessStatus: 'active',
            pedidosSuspendidosMorosidad: true));
    expect(find.text('En tu carrito: 8 unidades'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('product-purchase-action')))
            .onPressed,
        isNotNull);
    expect(cart.itemCount, 8);
  });

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, dark: false),
    (size: const Size(320, 640), scale: 1.6, dark: true),
    (size: const Size(568, 320), scale: 1.0, dark: false),
    (size: const Size(1440, 900), scale: 1.0, dark: false),
  ]) {
    testWidgets('purchase controls fit $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.brightness = scenario.dark ? Brightness.dark : Brightness.light;
      addTearDown(() => AppColors.brightness = Brightness.light);
      await pumpControls(tester, CartService(),
          scale: scenario.scale, dark: scenario.dark);
      expect(find.text('Agregar al carrito'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'short stock and minimum use the same amber and dark stock is readable',
      (tester) async {
    AppColors.brightness = Brightness.dark;
    addTearDown(() => AppColors.brightness = Brightness.light);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppDarkTheme(),
        home: Scaffold(
            body: Column(children: [
          const ProductStockSummary(part: part),
          ProductStockSummary(part: part.copyWith(stock: 8)),
        ]))));
    final enough = tester.widget<Text>(find.text('25 en stock')).style!.color!;
    final background = AppColors.card;
    final contrast = (enough.computeLuminance() + .05) /
        (background.computeLuminance() + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
    expect(tester.widget<Text>(find.text('3 disponibles')).style?.color,
        AppColors.warningAmberOnDark);
    expect(find.text('Mín. 5 uds'), findsNWidgets(2));
  });
}

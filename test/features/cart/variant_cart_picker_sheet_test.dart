import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/variant_cart_picker_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const buyer =
    ProfileModel(id: 'ally', role: 'aliado', accountAccessStatus: 'active');

PartModel _sku({
  required String id,
  required String label,
  int moq = 1,
  int stock = 50,
  Map<String, String> attrs = const {},
}) {
  return PartModel(
    id: id,
    nombre: 'Casco Dual',
    precio: 10,
    stock: stock,
    minOrderQty: moq,
    ownerId: 'supplier',
    variantAttributeValue: label,
    variantAttributes: attrs,
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required PartModel part,
  required CartService cart,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: VariantCartPickerSheet(
        part: part,
        profile: buyer,
        cart: cart,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MOQ is family total: first + is 1 and confirm waits for sum',
      (tester) async {
    final cart = CartService();
    final options = [
      _sku(id: 'm', label: 'M', moq: 5, stock: 40),
      _sku(id: 'l', label: 'L', moq: 5, stock: 40),
    ];
    final part = options.first.copyWith(variants: options);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () => showVariantCartPickerSheet(
              context: context,
              part: part,
              profile: buyer,
              cart: cart,
            ),
            child: const Text('Open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Seleccionadas: 0/5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('Seleccionadas: 1/5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('variant-cart-confirm')));
    await tester.pump();
    expect(cart.isEmpty, isTrue);
    expect(find.textContaining('Mínimo 5 uds'), findsOneWidget);

    // Llega a 5 en la misma opción.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump();
    }
    expect(find.textContaining('Seleccionadas: 5/5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('variant-cart-confirm')));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 5);
    expect(cart.lines, hasLength(1));
  });

  testWidgets('can split family MOQ across variants (2+2+1)', (tester) async {
    final cart = CartService();
    final options = [
      _sku(id: 'a', label: 'A', moq: 5, stock: 40),
      _sku(id: 'b', label: 'B', moq: 5, stock: 40),
      _sku(id: 'c', label: 'C', moq: 5, stock: 40),
    ];
    final part = options.first.copyWith(variants: options);
    await _pumpSheet(tester, part: part, cart: cart);

    final plus = find.byIcon(Icons.add);
    await tester.tap(plus.at(0));
    await tester.pump();
    await tester.tap(plus.at(0));
    await tester.pump();
    await tester.tap(plus.at(1));
    await tester.pump();
    await tester.tap(plus.at(1));
    await tester.pump();
    await tester.tap(plus.at(2));
    await tester.pump();

    expect(find.textContaining('Seleccionadas: 5/5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('variant-cart-confirm')));
    await tester.pumpAndSettle();
    expect(cart.itemCount, 5);
    expect(cart.lines, hasLength(3));
    expect(cart.lines.map((l) => l.quantity).toList()..sort(), [1, 2, 2]);
  });

  testWidgets('multi-axis labels show attribute pairs per option',
      (tester) async {
    final cart = CartService();
    final options = [
      _sku(
        id: '42-red',
        label: '42 / Rojo',
        attrs: {'Medida': '42', 'Color': 'Rojo'},
      ),
      _sku(
        id: '43-blue',
        label: '43 / Azul',
        attrs: {'Medida': '43', 'Color': 'Azul'},
      ),
    ];
    final part = options.first.copyWith(variants: options);
    await _pumpSheet(tester, part: part, cart: cart);

    expect(find.text('Medida: 42 · Color: Rojo'), findsOneWidget);
    expect(find.text('Medida: 43 · Color: Azul'), findsOneWidget);
    expect(find.textContaining('Sin stock'), findsNothing);
    expect(find.textContaining('Mín.'), findsNothing);
  });

  testWidgets('row with stock below line MOQ stays selectable if stock >= 1',
      (tester) async {
    final cart = CartService();
    final options = [
      _sku(id: 'ok', label: 'OK', moq: 5, stock: 10),
      _sku(id: 'low', label: 'Low', moq: 5, stock: 2),
    ];
    final part = options.first.copyWith(variants: options);
    await _pumpSheet(tester, part: part, cart: cart);

    expect(find.textContaining('Stock insuficiente'), findsNothing);
    expect(find.textContaining('Stock 2'), findsOneWidget);

    final plusButtons = find.byIcon(Icons.add);
    expect(plusButtons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: plusButtons.at(i),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    }
  });

  testWidgets('cancel closes without mutating the cart', (tester) async {
    final cart = CartService();
    final options = [
      _sku(id: 'a', label: 'A', moq: 1, stock: 10),
      _sku(id: 'b', label: 'B', moq: 1, stock: 10),
    ];
    final part = options.first.copyWith(variants: options);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () => showVariantCartPickerSheet(
              context: context,
              part: part,
              profile: buyer,
              cart: cart,
            ),
            child: const Text('Open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(cart.isEmpty, isTrue);
  });
}

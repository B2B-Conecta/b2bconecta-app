import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_commerce.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/product_photo_gallery.dart';
import 'package:motolink_pro_app/features/catalog/product_variant_selector.dart';

const red = PartModel(
    id: 'red-m',
    nombre: 'Guantes rojos M',
    precio: 20,
    stock: 12,
    minOrderQty: 2,
    parentSku: 'gloves',
    ownerId: 'supplier',
    sku: 'RED-M',
    variantAttributes: {'Talla': 'M', 'Color': 'Rojo'});
const blue = PartModel(
    id: 'blue-m',
    nombre: 'Guantes azules M',
    precio: 25,
    salePriceUsd: 23,
    stock: 7,
    minOrderQty: 1,
    parentSku: 'gloves',
    ownerId: 'supplier',
    sku: 'BLUE-M',
    variantAttributes: {'Talla': 'M', 'Color': 'Azul'});
const large = PartModel(
    id: 'blue-l',
    nombre: 'Guantes azules L',
    precio: 30,
    stock: 9,
    minOrderQty: 3,
    parentSku: 'gloves',
    ownerId: 'supplier',
    sku: 'BLUE-L',
    variantAttributes: {'Talla': 'L', 'Color': 'Azul'});

void main() {
  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 640), scale: 1.6),
    (size: const Size(1440, 900), scale: 1.0),
  ]) {
    testWidgets('variant selection updates compact detail at $scenario',
        (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!),
          home: ProductDetailScreen(
              part: red.copyWith(variants: [red, blue, large]),
              guestPreview: true,
              onRegisterToOrder: () {})));
      await tester.pumpAndSettle();
      final selector = find.byType(ProductVariantSelector);
      expect(selector, findsOneWidget);
      final blueChoice =
          find.descendant(of: selector, matching: find.text('Azul'));
      await tester.ensureVisible(blueChoice);
      await tester.pumpAndSettle();
      await tester.tap(blueChoice);
      await tester.pumpAndSettle();
      var summary = tester.widget<ProductDetailPurchaseSummary>(
          find.byType(ProductDetailPurchaseSummary));
      expect(summary.part.id, blue.id);
      expect(summary.part.minOrderQtyEffective, 1);
      expect(summary.part.precio, 25);
      expect(summary.part.salePriceUsd, 23);
      expect(summary.part.stockForSale, 7);
      final largeChoice =
          find.descendant(of: selector, matching: find.text('L'));
      await tester.ensureVisible(largeChoice);
      await tester.pumpAndSettle();
      await tester.tap(largeChoice);
      await tester.pumpAndSettle();
      summary = tester.widget<ProductDetailPurchaseSummary>(
          find.byType(ProductDetailPurchaseSummary));
      expect(summary.part.id, large.id);
      expect(summary.part.minOrderQtyEffective, 3);
      expect(summary.part.precio, 30);
      if (find.byType(ProductPhotoGallery).evaluate().isEmpty) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
        await tester.pumpAndSettle();
      }
      expect(
          tester
              .widget<ProductPhotoGallery>(find.byType(ProductPhotoGallery))
              .productName,
          large.nombre);
      expect(tester.takeException(), isNull);
    });
  }
}

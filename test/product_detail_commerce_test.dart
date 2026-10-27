import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_commerce.dart';

void main() {
  testWidgets(
      'compact purchase area preserves promotional USD, base REF and Bs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 300,
      child: ProductDetailPurchaseSummary(
          bcvRate: 10,
          part: PartModel(
              id: 'purchase',
              nombre: 'Disco',
              precio: 52,
              salePriceUsd: 48,
              stock: 10,
              stockReserved: 2)),
    ))));
    await tester.pump();
    expect(find.text('48.00 USD'), findsOneWidget);
    expect(find.text('52.00 REF'), findsOneWidget);
    expect(find.text('Bs 520,00'), findsOneWidget);
    expect(find.text('8 en stock'), findsOneWidget);
    expect(find.text('Mín. 5 unidades'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reserved stock cannot appear eligible for the purchase minimum',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 300,
      child: ProductDetailPurchaseSummary(
          bcvRate: 10,
          part: PartModel(
              id: 'reserved',
              nombre: 'Disco',
              precio: 52,
              stock: 10,
              stockReserved: 7)),
    ))));
    await tester.pump();
    expect(find.text('3 disponibles'), findsOneWidget);
    expect(tester.widget<Text>(find.text('3 disponibles')).style?.color,
        AppColors.warningAmber);
    expect(find.text('Mín. 5 unidades'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'supplier row keeps company, location, rating and store navigation together',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 300,
      child: ProductDetailSupplier(
          onOpen: () => opened = true,
          part: const PartModel(
              id: 'supplier',
              nombre: 'Disco',
              precio: 52,
              stock: 10,
              ownerBusinessName: 'Repuestos del Centro',
              ownerEstado: 'Lara',
              ownerCiudad: 'Barquisimeto',
              ownerRatingAvg: 4.5,
              ownerRatingCount: 12)),
    ))));
    expect(find.text('Vendido por Repuestos del Centro'), findsOneWidget);
    expect(find.text('Lara · Barquisimeto'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text(' (12)'), findsOneWidget);
    await tester.tap(find.text('Vendido por Repuestos del Centro'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplier without reviews does not invent a rating',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 300,
      child: ProductDetailSupplier(
          part: PartModel(
              id: 'supplier',
              nombre: 'Disco',
              precio: 52,
              stock: 10,
              ownerBusinessName: 'Proveedor')),
    ))));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.text('Vendido por Proveedor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

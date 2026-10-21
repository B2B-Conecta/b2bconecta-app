import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_quick_filters.dart';
import 'package:motolink_pro_app/features/catalog/aliado_product_card.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  test('envío incluido cuenta como filtro activo del catálogo', () {
    const filters = CatalogFilters(onlyEnvioIncluido: true);
    expect(filters.hasAnyFilter, isTrue);
    expect(filters.copyWith().onlyEnvioIncluido, isTrue);
    expect(
      filters.copyWith(onlyEnvioIncluido: false).hasAnyFilter,
      isFalse,
    );
  });

  testWidgets('los chips rápidos se eligen de a uno', (tester) async {
    var selected = AliadoCatalogQuickFilter.all;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AliadoCatalogQuickFilters(
            selected: selected,
            onSelected: (filter) => selected = filter,
          ),
        ),
      ),
    );

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Promociones USD'), findsOneWidget);
    expect(find.text('Envío incluido'), findsOneWidget);
    expect(find.text('Mayor reputación'), findsOneWidget);

    await tester.tap(find.text('Promociones USD'));
    expect(selected, AliadoCatalogQuickFilter.usdPromo);
  });

  testWidgets('la vitrina muestra REF, USD promocional, Bs oculto sin tasa, stock y envío', (
    tester,
  ) async {
    final part = PartModel(
      id: 'sku-1',
      nombre: 'Pastilla de freno',
      precio: 100,
      salePriceUsd: 90,
      stock: 24,
      minOrderQty: 5,
      ownerBusinessName: 'Repuestos Delta',
      ownerRatingAvg: 4.8,
      ownerRatingCount: 12,
      ownerEnvioTipo: EnvioPolitica.incluido,
    );
    const profile = ProfileModel(id: 'aliado-1', role: 'aliado');

    Future<void> pumpCard(double width) async {
      final height = width /
          AliadoCatalogLayout.childAspectRatio(tileWidth: width);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: AliadoProductCard(
                  part: part,
                  profile: profile,
                  compact: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCard(168);
    expect(tester.takeException(), isNull);
    expect(find.text('100.00 REF'), findsOneWidget);
    expect(find.text('90.00 USD'), findsOneWidget);
    expect(find.text('-10%'), findsOneWidget);
    expect(find.textContaining('24 en stock'), findsOneWidget);
    expect(find.textContaining('Mín. 5 uds'), findsOneWidget);
    expect(find.text('Envío incluido'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Repuestos Delta'), findsOneWidget);

    await pumpCard(280);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el precio de grilla deja el REF como base', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogProductPriceDisplay(
            listPriceUsd: 50,
            salePriceUsd: 40,
            catalogGrid: true,
            compact: true,
            showPromotionChips: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('50.00 REF'), findsOneWidget);
    expect(find.text('40.00 USD'), findsOneWidget);
    expect(find.text('-20%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/catalog/sliver_catalog_card_rows.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';

void main() {
  test('narrow phones use one column and desktop adds product columns', () {
    expect(AliadoCatalogLayout.crossAxisCount(320), 1);
    expect(AliadoCatalogLayout.crossAxisCount(390), 2);
    expect(AliadoCatalogLayout.crossAxisCount(1440), 5);
    expect(AliadoCatalogLayout.crossAxisCount(390, textScale: 1.6), 1);
  });
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

  testWidgets(
      'la vitrina muestra REF, USD promocional, Bs oculto sin tasa, stock y envío',
      (
    tester,
  ) async {
    const part = PartModel(
      id: 'sku-1',
      nombre: 'Pastilla de freno',
      precio: 100,
      salePriceUsd: 90,
      discountRules: {'usd_payment_discount_pct': 10},
      stock: 24,
      minOrderQty: 5,
      ownerBusinessName: 'Repuestos Delta',
      ownerRatingAvg: 4.8,
      ownerRatingCount: 12,
      ownerEnvioTipo: EnvioPolitica.incluido,
    );
    const profile = ProfileModel(id: 'aliado-1', role: 'aliado');
    var opened = false;

    Future<void> pumpCard(double width) async {
      final height =
          width / AliadoCatalogLayout.childAspectRatio(tileWidth: width);
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
                  onTap: () => opened = true,
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
    expect(find.text('81.00 USD'), findsNothing);
    expect(find.text('-10%'), findsOneWidget);
    expect(find.textContaining('24 en stock'), findsOneWidget);
    expect(find.textContaining('Mín. 5 uds'), findsOneWidget);
    expect(find.text('Envío incluido'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Repuestos Delta'), findsOneWidget);
    expect(find.text('Foto no disponible'), findsOneWidget);
    await tester.tap(find.text(part.nombre));
    expect(opened, isTrue);

    await pumpCard(280);
    expect(tester.takeException(), isNull);
  });

  for (final grid in [true, false]) {
    testWidgets('el USD promocional conserva REF y Bs originales, grid: $grid',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: CatalogProductPriceDisplay(
                listPriceUsd: 52,
                salePriceUsd: 48,
                bcvRate: 881.876923076923,
                catalogGrid: grid,
                compact: true,
                prominent: true,
                showPromotionChips: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('48.00 USD'), findsOneWidget);
      expect(find.text('52.00 REF'), findsOneWidget);
      expect(find.text('48.00 REF'), findsNothing);
      expect(find.text('Bs 45.857,60'), findsOneWidget);
      expect(find.text('-8%'), findsOneWidget);
      expect(find.text('/ ud'), findsNothing);
      expect(find.text('Precio USD'), findsNothing);
      final usdRect = tester.getRect(find.text('48.00 USD'));
      final discountRect = tester.getRect(find.text('-8%'));
      expect(discountRect.left, greaterThan(usdRect.right));
      expect(discountRect.center.dy, closeTo(usdRect.center.dy, 0.1));
      expect(tester.widget<Text>(find.text('48.00 USD')).style?.color,
          AppColors.successGreen);
      expect(tester.getTopLeft(find.text('48.00 USD')).dy,
          lessThan(tester.getTopLeft(find.text('52.00 REF')).dy));
      expect(tester.getTopLeft(find.text('52.00 REF')).dy,
          lessThan(tester.getTopLeft(find.text('Bs 45.857,60')).dy));
      expect(tester.takeException(), isNull);
    });
  }

  for (final sale in <double?>[null, 0, -1, 52, 60]) {
    testWidgets('sin oferta USD válida se conserva REF y Bs, oferta: $sale',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CatalogProductPriceDisplay(
                  listPriceUsd: 52,
                  salePriceUsd: sale,
                  bcvRate: 10,
                  catalogGrid: true))));
      await tester.pump();
      expect(find.text('52.00 REF'), findsOneWidget);
      expect(find.text('Bs 520,00'), findsOneWidget);
      expect(find.text('Precio USD'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (width: 168.0, scale: 1.0, dark: false),
    (width: 220.0, scale: 1.0, dark: true),
    (width: 358.0, scale: 1.6, dark: false),
  ]) {
    testWidgets('card preserves actions and purchase information at $scenario',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.brightness = scenario.dark ? Brightness.dark : Brightness.light;
      addTearDown(() => AppColors.brightness = Brightness.light);
      var productOpened = false;
      var supplierOpened = false;
      final part = PartModel(
          id: 'long',
          nombre:
              'Pastillas de freno delanteras para motocicletas de alta cilindrada',
          precio: 100,
          salePriceUsd: 90,
          stock: 24,
          ownerId: 'supplier',
          category: 'Frenos',
          ownerBusinessName: 'Distribuidora de Repuestos del Centro C.A.',
          ownerRatingAvg: 4.8,
          ownerRatingCount: 12,
          ownerEnvioTipo: EnvioPolitica.incluido,
          hasWarranty: true,
          ownerCatalogVerifiedAt: DateTime(2026),
          ownerCatalogFeaturedUntil:
              DateTime.now().add(const Duration(days: 30)),
          distanceKmFromReference: 2.4,
          customFields: buildCustomFieldsPayload(
              values: {'marca': 'Yamaha', 'costo': '10'},
              aliadoVisibleKeys: {'marca'}));
      await tester.pumpWidget(MaterialApp(
          theme: scenario.dark ? buildAppDarkTheme() : buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: scenario.width,
                      height: AliadoCatalogLayout.cardHeight(
                          tileWidth: scenario.width,
                          showDistance: true,
                          textScale: scenario.scale),
                      child: AliadoProductCard(
                          part: part,
                          profile:
                              const ProfileModel(id: 'ally', role: 'aliado'),
                          compact: true,
                          showDistanceChips: true,
                          onTap: () => productOpened = true,
                          onImporterTap: () => supplierOpened = true))))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('100.00 REF'), findsOneWidget);
      expect(find.text('90.00 USD'), findsOneWidget);
      expect(find.text('24 en stock'), findsOneWidget);
      expect(find.text('Mín. 5 uds'), findsOneWidget);
      expect(find.text('A 2.4 km'), findsOneWidget);
      expect(find.text('Marca: Yamaha'), findsOneWidget);
      expect(find.textContaining('Costo'), findsNothing);
      expect(tester.getSize(find.byType(IconButton)).shortestSide,
          greaterThanOrEqualTo(44));
      await tester.tap(find.text(part.nombre));
      expect(productOpened, isTrue);
      await tester.tap(find.text(part.ownerBusinessName!));
      expect(supplierOpened, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('unavailable stock is stated without hiding the purchase minimum',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 220,
                height: AliadoCatalogLayout.cardHeight(tileWidth: 220),
                child: AliadoProductCard(
                    part: const PartModel(
                        id: 'empty', nombre: 'Repuesto', precio: 10, stock: 0),
                    profile: const ProfileModel(id: 'ally', role: 'aliado'),
                    compact: true,
                    onTap: () {})))));
    await tester.pump();
    expect(find.text('Sin stock'), findsWidgets);
    expect(find.text('Mín. 5 uds'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final withPromotion in [false, true]) {
    testWidgets(
        'catalog rows align cards, prices and purchase actions without a global fixed height, promotion: $withPromotion',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: CustomScrollView(slivers: [
        SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverCatalogCardRows(
                columns: 2,
                spacing: 10,
                itemCount: 2,
                itemBuilder: (context, index) => AliadoProductCard(
                    key: ValueKey('natural-$index'),
                    part: PartModel(
                        id: 'p$index',
                        nombre: index == 0
                            ? 'LED stop'
                            : 'Un nombre de repuesto que ocupa dos líneas',
                        precio: 12,
                        salePriceUsd: withPromotion && index == 1 ? 10 : null,
                        discountRules: withPromotion && index == 1
                            ? {'usd_payment_discount_pct': 10}
                            : null,
                        stock: 100,
                        ownerId: 'supplier',
                        ownerBusinessName: 'Proveedor'),
                    profile: const ProfileModel(
                        id: 'ally',
                        role: 'aliado',
                        accountAccessStatus: 'active'),
                    compact: true,
                    onTap: () {}))),
      ]))));
      await tester.pump();
      final firstHeight =
          tester.getSize(find.byKey(const ValueKey('natural-0'))).height;
      final secondHeight =
          tester.getSize(find.byKey(const ValueKey('natural-1'))).height;
      // A promotion adds one price line; it must not reserve a large empty body.
      expect(firstHeight, lessThan(withPromotion ? 440 : 390));
      expect(firstHeight, closeTo(secondHeight, 0.1));
      final buttons = [
        for (var index = 0; index < 2; index++)
          tester.getRect(find.descendant(
              of: find.byKey(ValueKey('natural-$index')),
              matching: find.byType(FilledButton)))
      ];
      expect(buttons[0].top, closeTo(buttons[1].top, 0.1));
      expect(buttons[0].bottom, closeTo(buttons[1].bottom, 0.1));
      final firstPrice = find.descendant(
          of: find.byKey(const ValueKey('natural-0')),
          matching: find.text('12.00 REF'));
      final secondPrice = find.descendant(
          of: find.byKey(const ValueKey('natural-1')),
          matching: find.text(withPromotion ? '10.00 USD' : '12.00 REF'));
      expect(tester.getTopLeft(firstPrice).dy,
          closeTo(tester.getTopLeft(secondPrice).dy, 0.1));
      final minimum = tester.getRect(find.text('Mín. 5 uds').first);
      final supplier = tester.getRect(find.text('Proveedor').first);
      expect(supplier.top - minimum.bottom, lessThan(withPromotion ? 95 : 40));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick add does not trigger the card detail navigation',
      (tester) async {
    final cart = CartService.instance..clear();
    addTearDown(cart.clear);
    var detailOpened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: 220,
                    child: AliadoProductCard(
                        part: const PartModel(
                            id: 'quick',
                            nombre: 'LED stop',
                            precio: 12,
                            stock: 100,
                            ownerId: 'supplier'),
                        profile: const ProfileModel(
                            id: 'ally',
                            role: 'aliado',
                            accountAccessStatus: 'active'),
                        compact: true,
                        onTap: () => detailOpened = true))))));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
    await tester.pump();
    expect(detailOpened, isFalse);
    expect(cart.lines.single.quantity, 5);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(cart.lines.single.quantity, 6);
    expect(detailOpened, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}

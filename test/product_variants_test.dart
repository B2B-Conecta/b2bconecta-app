import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'package:motolink_pro_app/features/catalog/aliado_product_card.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_variants.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

PartModel _part({
  required String id,
  required String sku,
  required double price,
  int stock = 20,
  String? parentSku,
  String? attribute,
  String? value,
  Map<String, String> attributes = const {},
}) {
  return PartModel(
    id: id,
    ownerId: 'importer-1',
    nombre: 'Aceite',
    precio: price,
    stock: stock,
    sku: sku,
    parentSku: parentSku,
    variantAttributeName: attribute,
    variantAttributeValue: value,
    variantAttributes: attributes,
  );
}

void main() {
  test('un producto sin parent_sku sigue siendo una sola tarjeta', () {
    final parts = [
      _part(id: 'a', sku: 'A', price: 10),
      _part(id: 'b', sku: 'B', price: 12),
    ];

    final cards = collapseProductVariants(parts);

    expect(cards, hasLength(2));
    expect(cards.every((part) => part.variantChoices.isEmpty), isTrue);
  });

  test('las filas con el mismo parent_sku salen en una tarjeta', () {
    final parts = [
      _part(
        id: '1l',
        sku: 'ACE-1',
        price: 8,
        parentSku: 'aceite',
        attribute: 'Presentación',
        value: '1 Litro',
        stock: 2,
      ),
      _part(
        id: '4l',
        sku: 'ACE-4',
        price: 24,
        parentSku: 'aceite',
        attribute: 'Presentación',
        value: '4 Litros',
      ),
      _part(id: 'solo', sku: 'FILTRO', price: 5),
    ];

    final cards = collapseProductVariants(parts);

    expect(cards, hasLength(2));
    final family = cards.firstWhere((part) => part.parentSku == 'aceite');
    expect(family.variantChoices, hasLength(2));
    expect(family.id, '4l');
    expect(family.variantChoices.map((part) => part.sku), ['ACE-1', 'ACE-4']);
    expect(family.variantAttributeHeading, 'Presentación');
  });

  test('la foto de la variante manda y, si no hay, queda la del producto abierto', () {
    final opened = _part(id: '1l', sku: 'ACE-1', price: 8).copyWith(
      imagenUrl: 'https://cdn.example/aceite.jpg',
    );
    final withPhoto = _part(id: '4l', sku: 'ACE-4', price: 24).copyWith(
      imagenUrl: 'https://cdn.example/garrafa.jpg',
    );
    final withoutPhoto = _part(id: '05', sku: 'ACE-05', price: 6);

    expect(
      variantGalleryUrls(selected: withPhoto, opened: opened),
      ['https://cdn.example/garrafa.jpg'],
    );
    expect(
      variantGalleryUrls(
        selected: withoutPhoto,
        opened: opened,
        family: [opened, withPhoto, withoutPhoto],
      ),
      ['https://cdn.example/aceite.jpg'],
    );
    expect(
      variantGalleryUrls(selected: opened, opened: opened),
      ['https://cdn.example/aceite.jpg'],
    );
  });

  test('la carga exige el valor cuando hay SKU padre', () {
    const row = CatalogImportNormalizedRow(
      rowIndex: 2,
      sku: 'ACE-1',
      name: 'Aceite',
      priceUsd: 8,
      stock: 10,
      parentSku: 'aceite',
    );

    final batch = CatalogImportValidator.validateBatch([row]);

    expect(batch.validRows, isEmpty);
    expect(batch.errors.single.code, 'REQUIRED_VARIANT_VALUE');
  });

  testWidgets('la tarjeta agrupada muestra cuántas opciones hay', (tester) async {
    final family = collapseProductVariants([
      _part(
        id: '1l',
        sku: 'ACE-1',
        price: 8,
        parentSku: 'aceite',
        attribute: 'Presentación',
        value: '1 Litro',
      ),
      _part(
        id: '4l',
        sku: 'ACE-4',
        price: 24,
        parentSku: 'aceite',
        attribute: 'Presentación',
        value: '4 Litros',
      ),
    ]).single;
    const profile = ProfileModel(id: 'aliado-1', role: 'aliado');
    const width = 180.0;
    final height =
        width / AliadoCatalogLayout.childAspectRatio(tileWidth: width);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: AliadoProductCard(
              part: family,
              profile: profile,
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('2 opciones'), findsOneWidget);
    expect(find.text('Aceite'), findsOneWidget);
  });

  test('la carga manda el SKU de la variante y el padre', () {
    const row = CatalogImportNormalizedRow(
      rowIndex: 3,
      sku: 'ACE-4',
      name: 'Aceite',
      priceUsd: 24,
      stock: 6,
      salePriceUsd: 20,
      parentSku: 'aceite',
      variantAttributeName: 'Presentación',
      variantAttributeValue: '4 Litros',
      variantAttributes: {'Presentación': '4 Litros'},
    );

    expect(row.toRpcJson(), {
      'row_index': 3,
      'sku': 'ACE-4',
      'name': 'Aceite',
      'price_usd': 24,
      'stock': 6,
      'has_warranty': false,
      'sale_price_usd': 20,
      'parent_sku': 'aceite',
      'variant_attribute_name': 'Presentación',
      'variant_attribute_value': '4 Litros',
      'variant_attributes': {'Presentación': '4 Litros'},
    });
  });

  test('parsea varios atributos desde la celda Excel', () {
    expect(
      parseVariantAttributesCell('Tamaño:M|Color:Rojo'),
      {'Tamaño': 'M', 'Color': 'Rojo'},
    );
    expect(
      parseVariantAttributesCell('{"Tamaño":"L","Color":"Negro"}'),
      {'Tamaño': 'L', 'Color': 'Negro'},
    );
    expect(parseVariantAttributesCell('sin-formato'), isNull);
  });

  test('varios ejes eligen la combinación exacta o la más cercana', () {
    final options = [
      _part(
        id: 'm-rojo',
        sku: 'C-M-R',
        price: 10,
        parentSku: 'casco',
        attribute: 'Tamaño / Color',
        value: 'M / Rojo',
        attributes: {'Tamaño': 'M', 'Color': 'Rojo'},
      ),
      _part(
        id: 'm-azul',
        sku: 'C-M-A',
        price: 10,
        parentSku: 'casco',
        attribute: 'Tamaño / Color',
        value: 'M / Azul',
        attributes: {'Tamaño': 'M', 'Color': 'Azul'},
      ),
      _part(
        id: 'l-rojo',
        sku: 'C-L-R',
        price: 12,
        parentSku: 'casco',
        attribute: 'Tamaño / Color',
        value: 'L / Rojo',
        attributes: {'Tamaño': 'L', 'Color': 'Rojo'},
      ),
    ];

    expect(variantAttributeAxes(options), ['Tamaño', 'Color']);
    expect(
      availableAttributeValues(
        options: options,
        axis: 'Color',
        selection: {'Tamaño': 'M', 'Color': 'Rojo'},
      ),
      ['Rojo', 'Azul'],
    );
    expect(
      pickVariantForAttributes(
        options: options,
        selection: {'Tamaño': 'L', 'Color': 'Rojo'},
      ).id,
      'l-rojo',
    );
    expect(
      pickVariantForAttributes(
        options: options,
        selection: {'Tamaño': 'L', 'Color': 'Azul'},
        preferredAxis: 'Color',
      ).id,
      'm-azul',
    );
  });

  test('la carga acepta atributos multi-eje sin valor_atributo suelto', () {
    const row = CatalogImportNormalizedRow(
      rowIndex: 4,
      sku: 'C-M-R',
      name: 'Casco',
      priceUsd: 40,
      stock: 3,
      parentSku: 'casco',
      variantAttributeName: 'Tamaño / Color',
      variantAttributeValue: 'M / Rojo',
      variantAttributes: {'Tamaño': 'M', 'Color': 'Rojo'},
    );

    final batch = CatalogImportValidator.validateBatch([row]);

    expect(batch.errors, isEmpty);
    expect(batch.validRows, hasLength(1));
    expect(
      batch.validRows.single.toRpcJson()['variant_attributes'],
      {'Tamaño': 'M', 'Color': 'Rojo'},
    );
  });

  test('la carga manda is_active solo si la fila lo define', () {
    const withVisibility = CatalogImportNormalizedRow(
      rowIndex: 5,
      sku: 'ACE-1',
      name: 'Aceite',
      priceUsd: 8,
      stock: 4,
      isActive: true,
    );
    const withoutVisibility = CatalogImportNormalizedRow(
      rowIndex: 6,
      sku: 'ACE-2',
      name: 'Aceite',
      priceUsd: 9,
      stock: 4,
    );

    expect(withVisibility.toRpcJson()['is_active'], isTrue);
    expect(withoutVisibility.toRpcJson().containsKey('is_active'), isFalse);

    final bad = CatalogImportValidator.validateBatch(const [
      CatalogImportNormalizedRow(
        rowIndex: 7,
        sku: 'ACE-3',
        name: 'Aceite',
        priceUsd: 9,
        stock: 1,
        isActiveInvalid: true,
      ),
    ]);
    expect(bad.validRows, isEmpty);
    expect(bad.errors.single.code, 'INVALID_IS_ACTIVE');
  });
}

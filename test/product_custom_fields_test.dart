import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';

void main() {
  test('formatProductCustomFieldLabel humaniza claves', () {
    expect(formatProductCustomFieldLabel('marca_proveedor'), 'Marca Proveedor');
    expect(formatProductCustomFieldLabel('col_codigo_barras'), 'Codigo Barras');
  });

  test('unmappedFileHeaders excluye columnas ya usadas', () {
    final out = unmappedFileHeaders(
      headers: ['SKU', 'Marca', 'Stock'],
      coreColumnSelections: {'sku': 'SKU'},
      customColumnSelections: {'marca': 'Marca'},
    );
    expect(out, ['Stock']);
  });

  test('buildCustomFieldsPayload guarda visibilidad tienda minorista', () {
    final payload = buildCustomFieldsPayload(
      values: {'marca': 'Yamaha', 'ubicacion': 'A-12'},
      aliadoVisibleKeys: {'marca'},
    );
    expect(payload['marca'], 'Yamaha');
    expect(payload['ubicacion'], 'A-12');
    expect(payload[kAliadoVisibleCustomFieldKeys], ['marca']);
  });

  test('productCustomFieldsDisplayEntries filtra vista tienda minorista', () {
    final fields = buildCustomFieldsPayload(
      values: {'marca': 'Yamaha', 'costo': '10'},
      aliadoVisibleKeys: {'marca'},
    );
    final all = productCustomFieldsDisplayEntries(fields);
    final aliado = productCustomFieldsDisplayEntries(fields, aliadoView: true);
    expect(all.length, 2);
    expect(aliado.length, 1);
    expect(aliado.first.key, 'marca');
  });

  testWidgets('la tarjeta muestra el campo publicado y oculta el interno', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductCustomFieldsAliadoChips(
            customFields: buildCustomFieldsPayload(
              values: {'precio_bs': '55', 'costo': '10'},
              aliadoVisibleKeys: {'precio_bs'},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Precio Bs: 55'), findsOneWidget);
    expect(find.textContaining('Costo'), findsNothing);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_field.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_mapping.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/flexible_catalog_import_service.dart';

void main() {
  group('FlexibleCatalogImportService', () {
    test('previewFile detecta cabeceras CSV', () {
      final csv = '''
Cod_Art,Descripcion,Precio_Mayor,Existencia
ABC-001,Filtro aceite,12.50,100
XYZ-002,Bujía,3,25
''';
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final preview = FlexibleCatalogImportService.previewFile(
        bytes: bytes,
        meta: const CatalogImportFileMeta(
          format: CatalogImportFileFormat.csv,
          headerRow: 1,
          dataStartsAtRow: 2,
        ),
      );

      expect(preview.headers, ['Cod_Art', 'Descripcion', 'Precio_Mayor', 'Existencia']);
      expect(preview.sampleRows.first['Cod_Art'], 'ABC-001');
      expect(preview.totalDataRowsEstimate, 2);
    });

    test('parseInBatches aplica mapeo dinámico ERP', () async {
      final csv = '''
Cod_Art,Descripcion,Precio_Mayor,Existencia,Marca
ABC-001,Filtro aceite,"12,50",100,Yamaha
ABC-001,Duplicado,10,5,Honda
XYZ-002,Bujía,3.00,25,NKG
''';
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final mapping = CatalogImportMapping(
        file: const CatalogImportFileMeta(
          format: CatalogImportFileFormat.csv,
          headerRow: 1,
          dataStartsAtRow: 2,
        ),
        options: const CatalogImportOptions(batchSize: 10),
        columnMap: {
          CatalogImportField.sku.key: const CatalogImportColumnBinding(
            source: 'Cod_Art',
            required: true,
          ),
          CatalogImportField.name.key: const CatalogImportColumnBinding(
            source: 'Descripcion',
            required: true,
          ),
          CatalogImportField.priceUsd.key: const CatalogImportColumnBinding(
            source: 'Precio_Mayor',
            required: true,
            transform: CatalogImportTransform.decimalComma,
          ),
          CatalogImportField.stock.key: const CatalogImportColumnBinding(
            source: 'Existencia',
            required: true,
          ),
        },
        customFieldsMap: {
          'marca': const CatalogImportColumnBinding(source: 'Marca'),
        },
      );

      final batches = await FlexibleCatalogImportService.parseInBatches(
        bytes: bytes,
        mapping: mapping,
      ).toList();

      expect(batches, hasLength(1));
      final batch = batches.first;
      expect(batch.validRows, hasLength(2));
      final bySku = {for (final r in batch.validRows) r.sku: r};
      expect(bySku['ABC-001']!.priceUsd, 12.5);
      expect(bySku['XYZ-002']!.priceUsd, 3.0);
      expect(bySku['ABC-001']!.customFields['marca'], 'Yamaha');
      expect(
        batch.errors.any((e) => e.code == 'DUPLICATE_SKU_IN_FILE'),
        isTrue,
      );
    });

    test('legacyTemplateMapping es compatible con plantilla fija', () {
      final mapping = FlexibleCatalogImportService.legacyTemplateMapping();
      expect(mapping.missingRequiredFields(), isEmpty);
      expect(mapping.columnMap['sku']?.source, 'sku');
      expect(mapping.columnMap['name']?.source, 'nombre');
    });

    test('CatalogImportMapping serializa payload de mapeo', () {
      final mapping = CatalogImportMapping(
        file: const CatalogImportFileMeta(name: 'erp.xlsx'),
        options: const CatalogImportOptions(
          upsertMode: CatalogImportUpsertMode.priceStockOnly,
        ),
        columnMap: {
          'sku': const CatalogImportColumnBinding(source: 'Cod_Art'),
        },
      );

      final json = mapping.toJson();
      final roundTrip = CatalogImportMapping.fromJson(json);
      expect(roundTrip.options.upsertMode, CatalogImportUpsertMode.priceStockOnly);
      expect(roundTrip.columnMap['sku']?.source, 'Cod_Art');
    });
  });

  group('CatalogImportValidator', () {
    test('validateBatch rechaza precio negativo', () {
      const row = CatalogImportNormalizedRow(
        rowIndex: 2,
        sku: 'A1',
        name: 'Producto',
        priceUsd: -1,
        stock: 10,
      );
      final result = CatalogImportValidator.validateBatch([row]);
      expect(result.validRows, isEmpty);
      expect(result.errors.first.code, 'INVALID_PRICE');
    });
  });
}

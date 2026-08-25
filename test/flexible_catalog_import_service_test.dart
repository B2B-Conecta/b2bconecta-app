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

    test('detectCsvDelimiter reconoce punto y coma, coma y tabulador', () {
      expect(
        FlexibleCatalogImportService.detectCsvDelimiter(
          'CODIGO;DESCRIPCION;MARCA;PRECIO',
        ),
        ';',
      );
      expect(
        FlexibleCatalogImportService.detectCsvDelimiter(
          'sku,name,price,stock',
        ),
        ',',
      );
      expect(
        FlexibleCatalogImportService.detectCsvDelimiter(
          'sku\tname\tprice',
        ),
        '\t',
      );
    });

    test('CSV con punto y coma (Profit/Excel VE) parte columnas y acepta precio 0', () async {
      final csv = '''
CODIGO;DESCRIPCION;MARCA;PRECIO
HV72016;BUJIAS D8TC HONGJU;HONGJU;52
KIT-00015;KIT DE CILINDRO BERA 150 B-12 RS MOTO;RS MOTO MARKET;0
F079;CINTA PARA RIN GS ROJO&AZUL LIDER;LIDER;4
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
      expect(preview.headers, ['CODIGO', 'DESCRIPCION', 'MARCA', 'PRECIO']);
      expect(preview.sampleRows.first['PRECIO'], '52');

      final mapping = CatalogImportMapping(
        file: const CatalogImportFileMeta(
          format: CatalogImportFileFormat.csv,
          headerRow: 1,
          dataStartsAtRow: 2,
        ),
        options: const CatalogImportOptions(batchSize: 50),
        columnMap: {
          CatalogImportField.sku.key: const CatalogImportColumnBinding(
            source: 'CODIGO',
            required: true,
          ),
          CatalogImportField.name.key: const CatalogImportColumnBinding(
            source: 'DESCRIPCION',
            required: true,
          ),
          CatalogImportField.priceUsd.key: const CatalogImportColumnBinding(
            source: 'PRECIO',
            required: true,
          ),
        },
      );

      final batches = await FlexibleCatalogImportService.parseInBatches(
        bytes: bytes,
        mapping: mapping,
      ).toList();
      expect(batches, hasLength(1));
      final batch = batches.first;
      expect(batch.errors, isEmpty);
      expect(batch.validRows, hasLength(3));
      final bySku = {for (final r in batch.validRows) r.sku: r};
      expect(bySku['HV72016']!.priceUsd, 52);
      expect(bySku['KIT-00015']!.priceUsd, 0);
      expect(bySku['KIT-00015']!.stock, 0);
      expect(bySku['F079']!.priceUsd, 4);
    });
  });

  group('CatalogImportValidator.parseImportNumber', () {
    test('normaliza moneda, coma decimal y miles', () {
      expect(CatalogImportValidator.parseImportNumber('0'), 0);
      expect(CatalogImportValidator.parseImportNumber('52'), 52);
      expect(CatalogImportValidator.parseImportNumber('12,50'), 12.5);
      expect(CatalogImportValidator.parseImportNumber('1.234,56'), 1234.56);
      expect(CatalogImportValidator.parseImportNumber('1,234.56'), 1234.56);
      expect(CatalogImportValidator.parseImportNumber('\$10.50'), 10.5);
      expect(CatalogImportValidator.parseImportNumber('USD 8'), 8);
      expect(CatalogImportValidator.parseImportNumber('  16  '), 16);
    });
  });

  group('CatalogImportValidator', () {
    test('validateBatch acepta precio 0', () {
      const row = CatalogImportNormalizedRow(
        rowIndex: 2,
        sku: 'A1',
        name: 'Producto',
        priceUsd: 0,
        stock: 0,
      );
      final result = CatalogImportValidator.validateBatch([row]);
      expect(result.errors, isEmpty);
      expect(result.validRows, hasLength(1));
    });

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

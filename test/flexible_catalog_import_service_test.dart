import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_field.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_mapping.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_header_guess.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/excel_catalog_service.dart';
import 'package:motolink_pro_app/features/inventory/flexible_catalog_import_service.dart';

void main() {
  group('FlexibleCatalogImportService', () {
    test('detecta la tabla CSV bajo una portada con un separador distinto',
        () async {
      final bytes = Uint8List.fromList(utf8.encode(
        'Inventario, noviembre\nPreparado para distribución\n\n'
        'Descripción;Existencias;Código;Precio mayor;Marca;Marca\n'
        'Bujía;0;00042;8,50;Marca A;Marca B\n'
        'Filtro;;00043;10;Marca A;Marca C\n',
      ));
      final prepared = FlexibleCatalogImportService.prepareFile(
        bytes: bytes,
        meta: const CatalogImportFileMeta(format: CatalogImportFileFormat.csv),
      );
      expect(prepared.file.headerRow, 4);
      expect(prepared.file.csvDelimiter, ';');
      expect(prepared.preview.sampleRowNumbers, [5, 6]);
      expect(prepared.preview.sampleRows.first['Marca (2)'], 'Marca B');
      final mapping = CatalogImportMapping(
        file: prepared.file,
        options: const CatalogImportOptions(dryRun: true),
        columnMap: {
          for (final entry
              in CatalogImportHeaderGuess.suggestAll(prepared.preview.headers)
                  .entries)
            entry.key: CatalogImportColumnBinding(source: entry.value!),
        },
      );
      final batches = await FlexibleCatalogImportService.parseInBatches(
        bytes: bytes,
        mapping: mapping,
      ).toList();
      final valid = batches.expand((batch) => batch.validRows).single;
      expect(valid.sku, '00042');
      expect(valid.stock, 0);
      expect(valid.priceUsd, 8.5);
      final error = batches.expand((batch) => batch.errors).single;
      expect(error.rowIndex, 6);
      expect(error.message, contains('Stock vacío'));

      final reviewed = await FlexibleCatalogImportService.buildReviewedWorkbook(
        bytes: bytes,
        mapping: mapping,
        corrections: {
          6: {'Existencias': '4'}
        },
      );
      final rows = Excel.decodeBytes(reviewed).tables.values.single.rows;
      expect(rows.first.map((cell) => cell?.value.toString()),
          ExcelCatalogService.templateHeaders);
      expect(rows[1][0]?.value, TextCellValue('00042'));
      expect(rows[2][5]?.value, TextCellValue('4'));
      expect(utf8.decode(bytes), contains('Filtro;;00043;10'));
    });

    test('encuentra la hoja de productos y mantiene el SKU visible de Excel',
        () async {
      final workbook = Excel.createExcel();
      workbook['Sheet1'].appendRow([TextCellValue('Portada')]);
      final sheet = workbook['Inventario'];
      sheet.appendRow([TextCellValue('Catálogo de repuestos')]);
      sheet.appendRow([null]);
      sheet.appendRow([
        for (final header in ['Código', 'Descripción', 'Precio', 'Existencia'])
          TextCellValue(header),
      ]);
      sheet.appendRow([
        IntCellValue(42),
        TextCellValue('Bujía'),
        IntCellValue(8),
        IntCellValue(0)
      ]);
      sheet.cell(CellIndex.indexByString('A4')).cellStyle = CellStyle(
        numberFormat: NumFormat.custom(formatCode: '000000'),
      );
      final bytes = Uint8List.fromList(workbook.encode()!);
      for (final extension in ['xlsx', 'xlsm']) {
        final prepared = FlexibleCatalogImportService.prepareFile(
          bytes: bytes,
          meta: CatalogImportFileMeta(name: 'inventario.$extension'),
        );
        expect(prepared.file.sheetName, 'Inventario');
        expect(prepared.file.headerRow, 3);
        expect(prepared.preview.sampleRows.single['Código'], '000042');
        final batches = await FlexibleCatalogImportService.parseInBatches(
          bytes: bytes,
          mapping: CatalogImportMapping(
            file: prepared.file,
            options: const CatalogImportOptions(dryRun: true),
            columnMap: {
              for (final entry in CatalogImportHeaderGuess.suggestAll(
                      prepared.preview.headers)
                  .entries)
                entry.key: CatalogImportColumnBinding(source: entry.value!),
            },
          ),
        ).toList();
        final row = batches.single.validRows.single;
        expect(row.sku, '000042');
        expect(row.rowIndex, 4);
      }
    });
    test('las correcciones se aplican a la fila física sin editar el CSV',
        () async {
      final bytes = Uint8List.fromList(utf8.encode(
        'sku,nombre,precio,stock\n\nSKU-1,Bujía,3,\nSKU-2,Filtro,8,4\n',
      ));
      const file = CatalogImportFileMeta(format: CatalogImportFileFormat.csv);
      final mapping = CatalogImportMapping(
        file: file,
        options: const CatalogImportOptions(dryRun: true),
        columnMap: const {
          'sku': CatalogImportColumnBinding(source: 'sku'),
          'name': CatalogImportColumnBinding(source: 'nombre'),
          'price_usd': CatalogImportColumnBinding(source: 'precio'),
          'stock': CatalogImportColumnBinding(source: 'stock'),
        },
      );
      final original = FlexibleCatalogImportService.readRows(
        bytes: bytes,
        meta: file,
        rowNumbers: {3, 4},
      );
      expect(original[3]?['sku'], 'SKU-1');
      expect(original[3]?['stock'], '');
      final batches = await FlexibleCatalogImportService.parseInBatches(
        bytes: bytes,
        mapping: mapping,
        corrections: {
          3: {'stock': '0'}
        },
      ).toList();
      expect(batches.expand((batch) => batch.errors), isEmpty);
      expect(batches.expand((batch) => batch.validRows).map((row) => row.stock),
          [0, 4]);
      expect(utf8.decode(bytes), contains('SKU-1,Bujía,3,\n'));
    });

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

      expect(preview.headers,
          ['Cod_Art', 'Descripcion', 'Precio_Mayor', 'Existencia']);
      expect(preview.sampleRows.first['Cod_Art'], 'ABC-001');
      expect(preview.sampleRows, hasLength(2));
      expect(preview.totalDataRowsEstimate, 2);
    });

    test('previewFile con sampleRowCount alto refleja todas las filas', () {
      final lines = [
        'sku,nombre,precio',
        for (var i = 1; i <= 12; i++) 'SKU-$i,Producto $i,${i + 1}.00',
      ];
      final bytes = Uint8List.fromList(utf8.encode(lines.join('\n')));
      final compact = FlexibleCatalogImportService.previewFile(
        bytes: bytes,
        meta: const CatalogImportFileMeta(
          format: CatalogImportFileFormat.csv,
          headerRow: 1,
          dataStartsAtRow: 2,
        ),
      );
      expect(compact.sampleRows, hasLength(5));
      expect(compact.totalDataRowsEstimate, 12);

      final details = FlexibleCatalogImportService.previewFile(
        bytes: bytes,
        meta: const CatalogImportFileMeta(
          format: CatalogImportFileFormat.csv,
          headerRow: 1,
          dataStartsAtRow: 2,
        ),
        sampleRowCount: FlexibleCatalogImportService.detailsPreviewMaxRows,
      );
      expect(details.sampleRows, hasLength(12));
      expect(details.totalDataRowsEstimate, 12);
      expect(details.sampleRows.last['sku'], 'SKU-12');
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
      expect(
          roundTrip.options.upsertMode, CatalogImportUpsertMode.priceStockOnly);
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

    test(
        'CSV con punto y coma (Profit/Excel VE) parte columnas y acepta precio 0',
        () async {
      final csv = '''
CODIGO;DESCRIPCION;MARCA;PRECIO;STOCK
HV72016;BUJIAS D8TC HONGJU;HONGJU;52;3
KIT-00015;KIT DE CILINDRO BERA 150 B-12 RS MOTO;RS MOTO MARKET;0;0
F079;CINTA PARA RIN GS ROJO&AZUL LIDER;LIDER;4;7
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
      expect(preview.headers,
          ['CODIGO', 'DESCRIPCION', 'MARCA', 'PRECIO', 'STOCK']);
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
          CatalogImportField.stock.key: const CatalogImportColumnBinding(
            source: 'STOCK',
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

  test('detecta SKU repetido entre lotes y distingue stock vacío de cero',
      () async {
    final mapping = CatalogImportMapping(
      file: const CatalogImportFileMeta(
        format: CatalogImportFileFormat.csv,
        headerRow: 1,
        dataStartsAtRow: 2,
      ),
      options: const CatalogImportOptions(batchSize: 50),
      columnMap: {
        for (final field in catalogImportRequiredFields)
          field.key:
              CatalogImportColumnBinding(source: field.key, required: true),
      },
    );
    final csv = [
      'sku,name,price_usd,stock',
      for (var i = 0; i < 50; i++) 'SKU-$i,Repuesto $i,10,0',
      'sku-0,Duplicado,10,4',
      'BLANK,Sin stock informado,10,',
      'FRACTION,Stock decimal,10,1.5',
    ].join('\n');
    final batches = await FlexibleCatalogImportService.parseInBatches(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      mapping: mapping,
    ).toList();
    final valid = batches.expand((batch) => batch.validRows);
    final errors = batches.expand((batch) => batch.errors);
    expect(valid, hasLength(50));
    expect(valid.every((row) => row.stock == 0), isTrue);
    expect(
        errors.map((error) => error.code),
        unorderedEquals([
          'DUPLICATE_SKU_IN_FILE',
          'PARSE_ERROR',
          'PARSE_ERROR',
        ]));
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_field.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_mapping.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_result.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_issue_scan.dart';
import 'package:motolink_pro_app/features/inventory/flexible_catalog_import_service.dart';

void main() {
  test('el estado deja de decir listo cuando el stock de la muestra está vacío',
      () {
    const scan = CatalogImportSampleScan(
      sampleSize: 5,
      emptyStock: 5,
      invalidStock: 0,
      emptyPrice: 0,
      invalidPrice: 0,
      emptySku: 0,
      emptyName: 0,
      commaPrices: 0,
      dotPrices: 0,
      stockMapped: true,
      priceMapped: true,
      skuMapped: true,
      nameMapped: true,
    );
    final status = CatalogImportLiveStatus.resolve(
      missingLabels: const [],
      scan: scan,
      estimatedRows: 35,
      emptyStockFill: null,
      emptyPriceFill: null,
      decimalCommaOn: false,
    );
    expect(status.clean, isFalse);
    expect(status.readyToSimulate, isTrue);
    expect(status.stockNeedsAction, isTrue);
    expect(status.message, 'Stock vacío en las 35 filas');
  });

  test('asignar 0 al stock vacío deja el lote listo para simular', () {
    final scan = CatalogImportSampleScan.inspect(
      rows: [
        {'sku': 'A', 'nombre': 'Filtro', 'precio': '10', 'stock': ''},
      ],
      skuColumn: 'sku',
      nameColumn: 'nombre',
      priceColumn: 'precio',
      stockColumn: 'stock',
      emptyStockFill: 0,
    );
    final status = CatalogImportLiveStatus.resolve(
      missingLabels: const [],
      scan: scan,
      estimatedRows: 1,
      emptyStockFill: 0,
      emptyPriceFill: null,
      decimalCommaOn: false,
    );
    expect(scan.emptyStock, 0);
    expect(status.clean, isTrue);
    expect(status.message, contains('stock vacío = 0'));
  });

  test('agrupa errores repetidos de stock y los distingue del precio', () {
    final groups = groupCatalogImportErrors(const [
      CatalogImportRowError(
        rowIndex: 2,
        code: 'PARSE_ERROR',
        message: 'Stock vacío. Indica 0 si no hay existencias.',
      ),
      CatalogImportRowError(
        rowIndex: 3,
        code: 'PARSE_ERROR',
        message: 'Stock vacío. Indica 0 si no hay existencias.',
      ),
      CatalogImportRowError(
        rowIndex: 4,
        code: 'INVALID_PRICE',
        message: 'Precio inválido: columna de precio vacía o no mapeada',
      ),
    ]);
    expect(groups.map((group) => group.kind), [
      CatalogImportIssueKind.emptyStock,
      CatalogImportIssueKind.missingPrice,
    ]);
    expect(groups.first.count, 2);
    expect(groups.first.blocking, isTrue);
    expect(groups.first.canFillStock, isTrue);
  });

  test('un relleno de stock vacío importa la fila en lugar de fallar', () async {
    final bytes = Uint8List.fromList(utf8.encode(
      'sku,nombre,precio,stock\n'
      'A1,Filtro,10,\n',
    ));
    final prepared = FlexibleCatalogImportService.prepareFile(
      bytes: bytes,
      meta: const CatalogImportFileMeta(format: CatalogImportFileFormat.csv),
    );
    final mapping = CatalogImportMapping(
      file: prepared.file,
      options: const CatalogImportOptions(emptyStockFill: 0),
      columnMap: {
        CatalogImportField.sku.key:
            const CatalogImportColumnBinding(source: 'sku'),
        CatalogImportField.name.key:
            const CatalogImportColumnBinding(source: 'nombre'),
        CatalogImportField.priceUsd.key:
            const CatalogImportColumnBinding(source: 'precio'),
        CatalogImportField.stock.key:
            const CatalogImportColumnBinding(source: 'stock'),
      },
    );
    expect(mapping.missingRequiredFields(), isEmpty);
    final batches = await FlexibleCatalogImportService.parseInBatches(
      bytes: bytes,
      mapping: mapping,
    ).toList();
    final row = batches.expand((batch) => batch.validRows).single;
    expect(row.stock, 0);
    expect(batches.expand((batch) => batch.errors), isEmpty);
  });
}

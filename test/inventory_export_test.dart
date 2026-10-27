import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/excel_catalog_service.dart';

void main() {
  test('la exportación alinea celdas con las cabeceras nuevas', () {
    expect(
      ExcelCatalogService.templateExampleRow,
      hasLength(ExcelCatalogService.templateHeaders.length),
    );

    final part = PartModel(
      id: 'p1',
      sku: 'ACE-4',
      nombre: 'Aceite 4T',
      descripcion: 'Garrafa',
      precio: 24,
      salePriceUsd: 20,
      stock: 12,
      minOrderQty: 2,
      parentSku: 'aceite',
      variantAttributeName: 'Presentación',
      variantAttributeValue: '4 Litros',
      category: 'Motor',
      compatibilidad: 'CG150',
      imagenUrl: 'https://cdn.example/aceite.jpg',
      hasWarranty: true,
    );

    final cells = ExcelCatalogService.inventoryExportCells(part);
    expect(cells, hasLength(ExcelCatalogService.templateHeaders.length));
    expect(cells[0], 'ACE-4');
    expect(cells[3], '24.00');
    expect(cells[4], '20.00');
    expect(cells[5], '12');
    expect(cells[6], '2');
    expect(cells[7], 'aceite');
    expect(cells[8], 'Presentación');
    expect(cells[9], '4 Litros');
    expect(cells[12], 'https://cdn.example/aceite.jpg');
    expect(cells[13], 'si');
  });

  test('las cabeceras incluyen variantes e imagen', () {
    final headers = ExcelCatalogService.templateHeaders;
    expect(headers, contains('parent_sku (opcional)'));
    expect(headers, contains('atributo (opcional)'));
    expect(headers, contains('valor_atributo (opcional)'));
    expect(headers, contains('url_imagen (opcional)'));
    expect(headers, contains('cantidad_minima'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_field.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_header_guess.dart';

void main() {
  test('suggestAll mapea columnas ERP típicas', () {
    final guessed = CatalogImportHeaderGuess.suggestAll([
      'Cod_Art',
      'Descripcion',
      'Precio_Mayor',
      'Existencia',
      'Marca',
    ]);

    expect(guessed[CatalogImportField.sku.key], 'Cod_Art');
    expect(guessed[CatalogImportField.name.key], 'Descripcion');
    expect(guessed[CatalogImportField.priceUsd.key], 'Precio_Mayor');
    expect(guessed[CatalogImportField.stock.key], 'Existencia');
  });

  test('suggestAll mapea cantidad_minima aparte del stock', () {
    final guessed = CatalogImportHeaderGuess.suggestAll([
      'Cod_Art',
      'Descripcion',
      'Precio_Mayor',
      'Existencia',
      'cantidad_minima',
    ]);

    expect(guessed[CatalogImportField.stock.key], 'Existencia');
    expect(guessed[CatalogImportField.minOrderQty.key], 'cantidad_minima');
  });
}

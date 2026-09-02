import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_field.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_header_guess.dart';
import 'package:motolink_pro_app/features/inventory/product_min_order_qty.dart';

void main() {
  group('ProductMinOrderQty', () {
    test('piso de plataforma es 5', () {
      expect(ProductMinOrderQty.resolve(null), 5);
      expect(ProductMinOrderQty.resolve(0), 5);
      expect(ProductMinOrderQty.resolve(1), 5);
      expect(ProductMinOrderQty.resolve(4), 5);
      expect(ProductMinOrderQty.resolve(5), 5);
      expect(ProductMinOrderQty.resolve(12), 12);
    });

    test('stock cubre el mínimo', () {
      expect(
        ProductMinOrderQty.stockCovers(stock: 5, minOrderQty: 5),
        isTrue,
      );
      expect(
        ProductMinOrderQty.stockCovers(stock: 4, minOrderQty: 5),
        isFalse,
      );
      expect(
        ProductMinOrderQty.stockCovers(stock: 12, minOrderQty: 6),
        isTrue,
      );
    });
  });

  group('PartModel min_order_qty', () {
    test('fromJson usa 5 si falta o viene bajo el piso', () {
      final missing = PartModel.fromJson({
        'id': 'p1',
        'name': 'Caucho',
        'price_usd': 10,
        'stock': 20,
      });
      expect(missing.minOrderQtyEffective, 5);
      expect(missing.stockCoversMinOrder, isTrue);

      final low = PartModel.fromJson({
        'id': 'p2',
        'name': 'Caucho',
        'price_usd': 10,
        'stock': 3,
        'min_order_qty': 1,
      });
      expect(low.minOrderQtyEffective, 5);
      expect(low.stockCoversMinOrder, isFalse);
    });
  });

  test('header guess no confunde cantidad_minima con stock', () {
    final guessed = CatalogImportHeaderGuess.suggestAll([
      'sku',
      'nombre',
      'precio',
      'stock',
      'cantidad_minima',
    ]);
    expect(guessed[CatalogImportField.stock.key], 'stock');
    expect(guessed[CatalogImportField.minOrderQty.key], 'cantidad_minima');
  });

  test('carrito arranca en el mínimo y no deja bajar de ese piso', () {
    final part = PartModel(
      id: 'p1',
      nombre: 'Caucho',
      precio: 10,
      stock: 20,
      minOrderQty: 5,
    );
    final cart = CartService.instance;
    cart.clear();
    cart.addOrIncrement(part, precioUnitarioAliadoRef: 11, delta: 1);
    expect(cart.lines, hasLength(1));
    expect(cart.lines.first.quantity, 5);

    cart.setQuantity('p1', 3);
    expect(cart.lines.first.quantity, 5);

    cart.setQuantity('p1', 8);
    expect(cart.lines.first.quantity, 8);
    cart.clear();
  });

  test('carrito no agrega si el stock no cubre el mínimo', () {
    final part = PartModel(
      id: 'p2',
      nombre: 'Aceite',
      precio: 4,
      stock: 3,
      minOrderQty: 6,
    );
    final cart = CartService.instance;
    cart.clear();
    cart.addOrIncrement(part, precioUnitarioAliadoRef: 4, delta: 6);
    expect(cart.lines, isEmpty);
    cart.clear();
  });
}

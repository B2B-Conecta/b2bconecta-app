import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/related_products.dart';

PartModel _part({
  required String id,
  required String ownerId,
  String? category,
  bool active = true,
  int stock = 20,
}) {
  return PartModel(
    id: id,
    ownerId: ownerId,
    nombre: 'Repuesto $id',
    precio: 10,
    stock: stock,
    isActive: active,
    category: category,
  );
}

void main() {
  test('fallback local sigue priorizando mismo proveedor', () {
    final current = _part(id: 'current', ownerId: 'moto', category: 'Cauchos');
    final related = pickRelatedProducts(
      current: current,
      candidates: [
        current,
        _part(id: 'other', ownerId: 'boxes', category: 'Cauchos'),
        _part(id: 'same', ownerId: 'moto', category: 'Cauchos'),
      ],
      limit: 6,
    );
    expect(related.map((p) => p.id).toList(), ['same', 'other']);
  });

  test('carrusel soporta menos resultados que el límite sin romper', () {
    final current = _part(id: 'current', ownerId: 'moto');
    final related = pickRelatedProducts(
      current: current,
      candidates: [_part(id: 'only', ownerId: 'moto')],
      limit: 6,
    );
    expect(related, hasLength(1));
    expect(kRelatedProductsSectionTitle.isNotEmpty, isTrue);
  });
}

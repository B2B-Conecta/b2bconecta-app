import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/catalog_ranking.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

PartModel _part({
  required String id,
  required String nombre,
  String? category,
  int? paidOrders,
  DateTime? featuredUntil,
}) {
  return PartModel(
    id: id,
    nombre: nombre,
    precio: 1,
    stock: 10,
    category: category,
    ownerCatalogPaidOrders30d: paidOrders,
    ownerCatalogFeaturedUntil: featuredUntil,
  );
}

void main() {
  test('ordena por categoría A–Z y por nombre dentro de cada una', () {
    final acc = _part(id: '2', nombre: 'Tapa', category: 'Accesorios');
    final motorB = _part(id: '3', nombre: 'Bujía', category: 'Motor');
    final motorA = _part(id: '1', nombre: 'Aceite', category: 'Motor');
    final sorted = [acc, motorB, motorA]
      ..sort(comparePartsByCategoryThenName);

    expect(sorted.map((p) => p.id).toList(), ['2', '1', '3']);
  });

  test('productos sin categoría quedan al final', () {
    final loose = _part(id: 'z', nombre: 'Sin cat');
    final motor = _part(id: 'm', nombre: 'Filtro', category: 'Motor');
    final sorted = [loose, motor]..sort(comparePartsByCategoryThenName);
    expect(sorted.first.id, 'm');
    expect(sorted.last.id, 'z');
  });

  test('boost por ventas prioriza más pedidos pagados', () {
    final low = _part(id: 'l', nombre: 'Poco', paidOrders: 1);
    final high = _part(id: 'h', nombre: 'Mucho', paidOrders: 40);
    final sorted = [low, high]..sort(comparePartsForCatalogBoost);
    expect(sorted.first.id, 'h');
  });

  test('destacado queda delante del boost por ventas', () {
    final regular = _part(id: 'r', nombre: 'Regular', paidOrders: 40);
    final featured = _part(
      id: 'f',
      nombre: 'Destacado',
      paidOrders: 1,
      featuredUntil: DateTime.now().add(const Duration(days: 7)),
    );
    final sorted = [regular, featured]..sort(comparePartsForCatalogBoost);
    expect(sorted.first.id, 'f');
  });

  test('destacados quedan delante al ordenar por featured', () {
    final plain = _part(id: 'p', nombre: 'Sin sello', paidOrders: 40);
    final featured = _part(
      id: 'f',
      nombre: 'Destacado',
      paidOrders: 1,
      featuredUntil: DateTime.now().add(const Duration(days: 7)),
    );
    final sorted = [plain, featured]..sort(comparePartsForCatalogFeatured);
    expect(sorted.first.id, 'f');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';

void main() {
  test('brake names refine a family-only category into the right child', () {
    final groups = webStoreCategoryFamiliesFromStock(const [
      WebCatalogStockItem(
        id: 'disco-ebc',
        name: 'Disco EBC 245 mm',
        category: 'Frenos',
      ),
      WebCatalogStockItem(
        id: 'disco-flotante',
        name: 'Disco flotante 260 mm',
        category: 'Frenos',
      ),
      WebCatalogStockItem(
        id: 'manilla',
        name: 'Manilla freno derecha',
        category: 'Frenos',
      ),
      WebCatalogStockItem(
        id: 'pastillas',
        name: 'Pastillas Ferodo delanteras',
        category: 'Frenos',
      ),
    ], includeEmpty: true);

    final frenos = groups.firstWhere((group) => group.label == 'Frenos');
    expect(frenos.hasInventory, isTrue);
    expect(frenos.productIds, hasLength(4));

    String child(String label) =>
        frenos.children.firstWhere((group) => group.label == label).hasInventory
            ? 'disponible'
            : 'vacio';

    expect(child('Frenos / Discos'), 'disponible');
    expect(child('Frenos / Manillas de freno'), 'disponible');
    expect(child('Frenos / Pastillas'), 'disponible');
    expect(child('Frenos / Bandas'), 'vacio');
    expect(
      webProductIdsForSelection(groups, 'Frenos / Discos'),
      ['disco-ebc', 'disco-flotante'],
    );
    expect(
      webProductIdsForSelection(groups, 'Frenos'),
      ['disco-ebc', 'disco-flotante', 'manilla', 'pastillas'],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/inventory_search.dart';

void main() {
  group('InventorySearch.sanitize', () {
    test('keeps sku separators used by suppliers', () {
      expect(InventorySearch.sanitize('ACE-4T_20W50.1'), 'ACE-4T_20W50.1');
    });

    test('strips or-filter breakers and ilike wildcards', () {
      expect(InventorySearch.sanitize('  foo%,(bar)  '), 'foo bar');
    });
  });

  group('InventorySearch.postgrestOrFilter', () {
    test('returns null for blank input', () {
      expect(InventorySearch.postgrestOrFilter(null), isNull);
      expect(InventorySearch.postgrestOrFilter('   '), isNull);
    });

    test('includes sku and quotes the pattern for dotted codes', () {
      final filter = InventorySearch.postgrestOrFilter('SKU.001');
      expect(filter, isNotNull);
      expect(filter, contains('sku.ilike."%SKU.001%"'));
      expect(filter, contains('name.ilike."%SKU.001%"'));
      expect(filter, contains('parent_sku.ilike."%SKU.001%"'));
      expect(filter, contains('variant_attribute_value.ilike."%SKU.001%"'));
      expect(filter, contains('description.ilike."%SKU.001%"'));
      expect(filter, contains('compatibility.ilike."%SKU.001%"'));
      expect(filter, contains('category.ilike."%SKU.001%"'));
    });
  });
}

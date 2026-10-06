import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_seals.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';

void main() {
  test('fromJson lee sellos Verificado y Destacado', () {
    final profile = ImporterStoreProfile.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'business_name': 'Repuestos Delta',
      'catalog_featured_until':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'catalog_verified_at': DateTime.now().toIso8601String(),
    });
    expect(profile.isCatalogVerified, isTrue);
    expect(profile.isCatalogFeatured, isTrue);
  });

  testWidgets('muestra ambos sellos en la fila', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImporterCatalogSealsRow(verified: true, featured: true),
        ),
      ),
    );
    expect(find.text('Verificado'), findsOneWidget);
    expect(find.text('Destacado'), findsOneWidget);
  });
}

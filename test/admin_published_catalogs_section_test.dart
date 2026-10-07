import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/admin_published_catalogs_section.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

const _importerA = '11111111-1111-1111-1111-111111111111';

ImporterOption _importer() {
  return const ImporterOption(
    id: _importerA,
    businessName: 'Mayorista Andino',
  );
}

PartModel _part() {
  return const PartModel(
    id: 'p1',
    ownerId: _importerA,
    nombre: 'Pastilla de freno',
    precio: 12.5,
    stock: 4,
    sku: 'FR-01',
    category: 'Frenos',
    isActive: true,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<PartModel>> Function({
    required String importerId,
    required int limit,
    required int offset,
  }) loadProducts,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminPublishedCatalogsSection(
          loadImporters: () async => [_importer()],
          loadProducts: loadProducts,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el admin ve solo los productos del mayorista elegido', (tester) async {
    String? queried;
    await _pump(
      tester,
      loadProducts: ({
        required String importerId,
        required int limit,
        required int offset,
      }) async {
        queried = importerId;
        return [_part()];
      },
    );

    expect(find.text('Catálogos publicados de mayoristas'), findsOneWidget);
    await tester.tap(find.text('Mayorista Andino'));
    await tester.pumpAndSettle();

    expect(queried, _importerA);
    expect(find.text('Pastilla de freno'), findsOneWidget);
    expect(find.text('SKU FR-01'), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Pausar'), findsNothing);
  });

  testWidgets('mayorista sin publicados muestra el estado vacío', (tester) async {
    await _pump(
      tester,
      loadProducts: ({
        required String importerId,
        required int limit,
        required int offset,
      }) async =>
          const [],
    );
    await tester.tap(find.text('Mayorista Andino'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este mayorista no tiene productos publicados.'),
      findsOneWidget,
    );
  });

  testWidgets('un fallo de carga ofrece reintento', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      loadProducts: ({
        required String importerId,
        required int limit,
        required int offset,
      }) async {
        calls++;
        if (calls == 1) throw Exception('red');
        return const [];
      },
    );
    await tester.tap(find.text('Mayorista Andino'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-catalogs-products-error')), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este mayorista no tiene productos publicados.'),
      findsOneWidget,
    );
    expect(calls, 2);
  });
}
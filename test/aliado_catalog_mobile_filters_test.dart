import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_filters_draft.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_filters_sheet.dart';
import 'package:motolink_pro_app/features/catalog/catalog_category_icon.dart';

void main() {
  testWidgets(
      'mobile filters apply a counted subcategory and included shipping',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const initial = AliadoCatalogFiltersDraft(
      categoryLabel: 'Todos',
      importerIds: {},
      ownerEstado: '',
      ownerCiudad: '',
      minPrice: '',
      maxPrice: '',
    );
    AliadoCatalogFiltersDraft? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await AliadoCatalogFiltersSheet.show(
                context,
                initial: result ?? initial,
                importers: const [],
                showCategoryCounts: true,
                categoryGroups: const [
                  AliadoCatalogCategoryGroup(
                    label: 'Frenos',
                    values: ['Discos'],
                    productIds: ['a', 'b'],
                    children: [
                      AliadoCatalogCategoryGroup(
                        label: 'Frenos / Discos',
                        values: ['Discos'],
                        productIds: ['a'],
                      ),
                    ],
                  ),
                ],
              );
            },
            child: const Text('Abrir filtros'),
          ),
        ),
      ),
    ));
    Future<void> tapText(String label) async {
      final finder = find.text(label);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tapText('Abrir filtros');
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(CatalogCategoryIcon), findsOneWidget);
    await tester.tap(find.byTooltip('Expandir Frenos'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(
      tester
          .widgetList<CatalogCategoryIcon>(find.byType(CatalogCategoryIcon))
          .map((icon) => icon.art),
      [CatalogCategoryArt.brakes, CatalogCategoryArt.brakes],
    );
    await tapText('Discos');
    await tapText('Envío incluido');
    await tapText('Aplicar filtros');

    expect(result?.categoryLabel, 'Frenos / Discos');
    expect(result?.onlyEnvioIncluido, isTrue);
    expect(result?.activePanelFilterCount, 2);

    await tapText('Abrir filtros');
    await tapText('Restablecer');
    await tapText('Aplicar filtros');
    expect(result?.categoryLabel, 'Todos');
    expect(result?.onlyEnvioIncluido, isFalse);
  });
}

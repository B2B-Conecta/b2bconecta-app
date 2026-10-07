import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/admin/admin_catalog_coverage.dart';
import 'package:motolink_pro_app/features/admin/admin_user_monitoring_panel.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';

const _published = ImporterOption(
  id: '11111111-1111-1111-1111-111111111111',
  businessName: 'Repuestos Delta',
);

const _without = ImporterOption(
  id: '22222222-2222-2222-2222-222222222222',
  businessName: 'Accesorios Punto Fijo',
);

void main() {
  test('separa importadores con y sin catálogo publicado', () {
    final coverage = splitImportersByPublishedCatalog(
      importers: const [_published, _without],
      publishedOwnerIds: {_published.id},
    );
    expect(coverage.published.map((e) => e.id), [_published.id]);
    expect(coverage.withoutCatalog.map((e) => e.id), [_without.id]);
  });

  testWidgets('el total de catálogos abre los proveedores', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserMonitoringPanel(
            loadRows: ({role, required period}) async => const [],
            loadCatalogCoverage: () async => const AdminCatalogCoverage(
              published: [_published],
              withoutCatalog: [_without],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);
    await tester.tap(find.byKey(const Key('admin-published-catalogs-stat')));
    await tester.pumpAndSettle();

    expect(find.text('Catálogos publicados · 1'), findsOneWidget);
    expect(find.text('Repuestos Delta'), findsOneWidget);
    expect(find.text('Sin catálogo publicado · 1'), findsOneWidget);
    expect(find.text('Accesorios Punto Fijo'), findsOneWidget);
    expect(
      find.text('Importadores registrados que aún no publican productos.'),
      findsOneWidget,
    );
  });
}

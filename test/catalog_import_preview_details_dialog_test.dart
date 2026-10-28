import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_result.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_preview_details_dialog.dart';

void main() {
  CatalogImportPreview previewWithRows(int count) {
    return CatalogImportPreview(
      headers: const ['sku', 'nombre', 'precio', 'stock', 'marca'],
      sampleRows: [
        for (var i = 1; i <= count; i++)
          {
            'sku': 'SKU-$i',
            'nombre': 'Producto $i',
            'precio': '${i + 1}.00',
            'stock': '${i * 2}',
            'marca': i.isEven ? 'Mobil' : 'NGK',
          },
      ],
      totalDataRowsEstimate: count,
    );
  }

  testWidgets('opens compact details with summary chips and sticky actions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () => showCatalogImportPreviewDetailsDialog(
              context: context,
              preview: previewWithRows(2),
              fileName: 'inventario.xlsx',
              coreHeaders: const {'sku', 'nombre', 'precio'},
              erpHeaders: const {'marca'},
            ),
            child: const Text('Open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Detalles de la carga'), findsOneWidget);
    expect(find.textContaining('3 clave(s)'), findsOneWidget);
    expect(find.textContaining('1 extra(s)'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    expect(find.text('Producto 1'), findsOneWidget);
    expect(find.text('Producto 2'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Detalles de la carga'), findsNothing);
  });

  testWidgets('paginates rows ten at a time and filters by SKU', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return FilledButton(
            onPressed: () => showCatalogImportPreviewDetailsDialog(
              context: context,
              preview: previewWithRows(23),
              fileName: 'inventario.xlsx',
              coreHeaders: const {'sku', 'nombre', 'precio'},
              erpHeaders: const {'marca'},
            ),
            child: const Text('Open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Producto 1'), findsOneWidget);
    expect(find.text('Producto 10'), findsOneWidget);
    expect(find.text('Producto 11'), findsNothing);

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Producto 11'), findsOneWidget);
    expect(find.text('Producto 1'), findsNothing);

    await tester.enterText(
      find.byType(TextField),
      'SKU-23',
    );
    await tester.pumpAndSettle();
    expect(find.text('Producto 23'), findsOneWidget);
    expect(find.text('Producto 11'), findsNothing);
  });
}

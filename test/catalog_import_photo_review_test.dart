import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_photo_review.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_photos.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/product_image_bulk_service.dart';

CatalogPhotoDraft _draft(String name, {String sku = '', bool approved = false}) {
  return CatalogPhotoDraft(
    file: ProductImageBulkFile(
      pathInZip: name,
      bytes: Uint8List.fromList(const [0]),
      extension: 'jpg',
      sku: sku,
      slot: 1,
    ),
    sku: sku,
    approved: approved,
  );
}

void main() {
  testWidgets('Solo pendientes stays active while a SKU is assigned',
      (tester) async {
    const ready = CatalogImportNormalizedRow(
      rowIndex: 2,
      sku: 'LISTO',
      name: 'Caucho',
      priceUsd: 10,
      stock: 1,
    );
    CatalogImportPhotoReview.rememberPendingOnly = true;
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogImportPhotoReview(
          drafts: [
            _draft('lista.jpg', sku: 'LISTO', approved: true),
            _draft('pendiente.jpg'),
          ],
          targets: {
            'listo': (row: ready, available: true),
          },
          invalidEntries: const [],
        ),
      ),
    );

    expect(find.text('lista.jpg'), findsNothing);
    expect(find.text('Sin código'), findsOneWidget);
    expect(find.textContaining('Solo pendientes · 1'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'PG01-04');
    await tester.pump();

    expect(find.textContaining('Solo pendientes · 1'), findsOneWidget);
    expect(find.text('Sin código'), findsNothing);
    expect(find.text('PG01-04'), findsOneWidget);
  });

  testWidgets('photo cards fit a phone width with the filter still on',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    CatalogImportPhotoReview.rememberPendingOnly = true;
    const ready = CatalogImportNormalizedRow(
      rowIndex: 2,
      sku: 'LISTO',
      name: 'Caucho',
      priceUsd: 10,
      stock: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogImportPhotoReview(
          drafts: [
            _draft('lista.jpg', sku: 'LISTO', approved: true),
            _draft('pendiente.jpg'),
          ],
          targets: {
            'listo': (row: ready, available: true),
          },
          invalidEntries: const [],
        ),
      ),
    );
    expect(find.text('lista.jpg'), findsNothing);
    expect(find.text('Sin código'), findsOneWidget);
    expect(find.textContaining('Solo pendientes · 1'), findsOneWidget);
  });

  CatalogPhotoDraft rowDraft(String sku, int row) {
    return CatalogPhotoDraft(
      file: ProductImageBulkFile(
        pathInZip: '$sku.jpg',
        bytes: Uint8List.fromList(const [0]),
        extension: 'jpg',
        sku: sku,
        slot: 1,
      ),
      sku: sku,
      sourceRowBinding: row,
      workbookPhoto: (
        bytes: Uint8List.fromList(const [0]),
        name: '$sku.jpg',
        extension: 'jpg',
        sourceRow: row,
        singleRow: true,
      ),
    );
  }

  testWidgets('photos follow document order and include in bulk',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    CatalogImportPhotoReview.rememberPendingOnly = false;
    CatalogImportNormalizedRow row(int index, String sku) {
      return CatalogImportNormalizedRow(
        rowIndex: index,
        sku: sku,
        name: sku,
        priceUsd: 1,
        stock: 1,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: CatalogImportPhotoReview(
          drafts: [
            rowDraft('C', 9),
            _draft('suelta.jpg'),
            rowDraft('A', 3),
          ],
          targets: {
            'c': (row: row(9, 'C'), available: true),
            'a': (row: row(3, 'A'), available: true),
          },
          invalidEntries: const [],
        ),
      ),
    );

    final suggested = find.textContaining('Sugerido · fila');
    expect(tester.getTopLeft(suggested.at(0)).dy,
        lessThan(tester.getTopLeft(suggested.at(1)).dy));
    expect(find.text('Sugerido · fila 3'), findsOneWidget);
    expect(find.text('Sugerido · fila 9'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Sugerido · fila 3')).dy,
      lessThan(tester.getTopLeft(find.text('Sugerido · fila 9')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Sugerido · fila 9')).dy,
      lessThan(tester.getTopLeft(find.text('Sin código')).dy),
    );

    await tester.tap(find.text('Incluir todas con SKU (2)'));
    await tester.pump();

    expect(find.text('2 de 3 fotos incluidas'), findsOneWidget);
    expect(find.text('Incluida'), findsNWidgets(2));
    expect(find.text('Incluir todas con SKU (0)'), findsOneWidget);

    await tester.tap(find.text('Desmarcar todas'));
    await tester.pump();
    expect(find.text('0 de 3 fotos incluidas'), findsOneWidget);
    expect(find.text('Incluida'), findsNothing);
  });

  testWidgets('photo grid stays within a desktop card', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    CatalogImportPhotoReview.rememberPendingOnly = false;
    const ready = CatalogImportNormalizedRow(
      rowIndex: 4,
      sku: 'A',
      name: 'A',
      priceUsd: 1,
      stock: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogImportPhotoReview(
          drafts: [rowDraft('A', 4), _draft('suelta.jpg')],
          targets: {
            'a': (row: ready, available: true),
          },
          invalidEntries: const [],
        ),
      ),
    );
    expect(find.text('Sugerido · fila 4'), findsOneWidget);
    expect(find.text('Incluir'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

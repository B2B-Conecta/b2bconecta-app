import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_photos.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/product_image_bulk_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/product_image_gallery_editor.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';

void main() {
  test('parseProductImageFilename slots', () {
    expect(parseProductImageFilename('ABC123.jpg')?.sku, 'ABC123');
    expect(parseProductImageFilename('ABC123.jpg')?.slot, 1);
    expect(parseProductImageFilename('ABC123_2.png')?.slot, 2);
    expect(parseProductImageFilename('ABC123-3.webp')?.slot, 3);
    expect(parseProductImageFilename('folder/XYZ.jpg')?.sku, 'XYZ');
    // SKUs que terminan en -02 / -03 no son slots de galería.
    expect(parseProductImageFilename('VAR70-ACE-02.jpg')?.sku, 'VAR70-ACE-02');
    expect(parseProductImageFilename('VAR70-ACE-02.jpg')?.slot, 1);
    expect(parseProductImageFilename('VAR70-AMO-03.jpg')?.sku, 'VAR70-AMO-03');
    expect(parseProductImageFilename('VAR70-AMO-03.jpg')?.slot, 1);
  });

  test('el ZIP bloquea la colisión entre SKU exacto y sufijo de foto', () {
    final zip = Uint8List.fromList(ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('ABC_2.jpg', 3, [255, 216, 255])),
    )!);
    final conflict = ProductImageBulkService.parseZipBytes(
      zip,
      knownSkuKeys: {'abc', 'abc_2'},
    );
    expect(conflict.uploadableSkuCount, 0);
    expect(conflict.invalidEntries.single, contains('SKU ambiguo'));
    final exact = ProductImageBulkService.parseZipBytes(
      zip,
      knownSkuKeys: {'abc_2'},
    );
    expect(exact.files.single.sku, 'ABC_2');
    expect(exact.files.single.slot, 1);
  });

  test('retiene un SKU ambiguo para resolverlo manualmente', () {
    final zip = Uint8List.fromList(ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('ABC_2.jpg', 3, [255, 216, 255])),
    )!);
    final preview = ProductImageBulkService.parseZipBytes(
      zip,
      knownSkuKeys: {'abc', 'abc_2'},
      keepAmbiguousForReview: true,
    );
    expect(preview.files.single.sku, isEmpty);
    expect(preview.invalidEntries, isEmpty);
  });

  test('la revisión exige SKU válido y una portada sin posiciones repetidas',
      () {
    const row = CatalogImportNormalizedRow(
      rowIndex: 2,
      sku: 'ABC',
      name: 'Disco',
      priceUsd: 10,
      stock: 3,
    );
    final target = {'abc': (row: row, available: true)};
    final file = ProductImageBulkFile(
      pathInZip: 'abc.jpg',
      bytes: Uint8List(1),
      extension: 'jpeg',
      sku: 'abc',
      slot: 1,
    );
    final cover = CatalogPhotoDraft(file: file, sku: ' ABC ', approved: true);
    final second = cover.copyWith(slot: 2);
    expect(
        CatalogPhotoDraft.assignmentErrors([cover, second], target), isEmpty);
    expect(CatalogPhotoDraft.assignmentErrors([cover, cover], target),
        contains('abc'));
    expect(
        CatalogPhotoDraft.assignmentErrors([second], target), contains('abc'));
    expect(
        CatalogPhotoDraft.assignmentErrors(
          [cover],
          {'abc': (row: row, available: false)},
        ),
        contains('abc'));
    expect(
        CatalogPhotoDraft.assignmentErrors(
          [cover.copyWith(sku: 'def')],
          target,
        ),
        contains('def'));
  });

  test('mergeProductImageUrls append respeta max 3', () {
    final out = mergeProductImageUrls(
      existing: ['a'],
      newBySlot: {2: 'b', 3: 'c'},
      mode: ProductImageBulkMergeMode.append,
    );
    expect(out, ['a', 'b', 'c']);
  });

  test('parseProductImageUrlsJson legacy fallback', () {
    final urls =
        parseProductImageUrlsJson(null, legacyImageUrl: 'http://x/a.jpg');
    expect(urls, ['http://x/a.jpg']);
  });

  test('una fila con portada legada cuenta como con fotos', () {
    expect(
      productRowHasPhotos(imageUrls: const [], imageUrl: 'https://x/a.jpg'),
      isTrue,
    );
    expect(productRowHasPhotos(imageUrls: const [], imageUrl: ''), isFalse);
    expect(productRowHasPhotos(imageUrls: const ['https://x/b.jpg']), isTrue);
  });

  test('producto sin image_urls ni portada queda sin fotos', () {
    final part = PartModel.fromJson({
      'id': 'p1',
      'name': 'Filtro',
      'price_usd': 10,
      'stock': 2,
      'image_urls': <dynamic>[],
    });
    expect(part.hasPhotos, isFalse);
    expect(part.coverImageUrl, isNull);
  });

  test('producto con fotos o portada legada queda con fotos', () {
    final withUrls = PartModel.fromJson({
      'id': 'p2',
      'name': 'Pastilla',
      'price_usd': 8,
      'stock': 4,
      'image_urls': ['https://cdn.example/a.jpg'],
    });
    final legacyOnly = PartModel.fromJson({
      'id': 'p3',
      'name': 'Disco',
      'price_usd': 12,
      'stock': 1,
      'image_url': 'https://cdn.example/legacy.jpg',
    });
    expect(withUrls.hasPhotos, isTrue);
    expect(legacyOnly.hasPhotos, isTrue);
  });

  testWidgets('la ficha muestra Tomar foto mientras haya cupo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGalleryEditor(
            slots: const [],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });

  testWidgets('Tomar foto desaparece al completar las 3 fotos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGalleryEditor(
            slots: [
              ProductImageEditSlot.url('https://cdn.example/1.jpg'),
              ProductImageEditSlot.url('https://cdn.example/2.jpg'),
              ProductImageEditSlot.url('https://cdn.example/3.jpg'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Tomar foto'), findsNothing);
  });

  testWidgets('tocar la foto del producto abre el zoom', (tester) async {
    final bytes = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGalleryEditor(
            slots: [
              ProductImageEditSlot.pending(bytes, 'gif'),
              ProductImageEditSlot.pending(bytes, 'gif'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Image).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Cerrar fotos'), findsOneWidget);
    expect(find.byTooltip('Acercar foto'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

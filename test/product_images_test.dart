import 'package:flutter/material.dart';
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
    final urls = parseProductImageUrlsJson(null, legacyImageUrl: 'http://x/a.jpg');
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
}

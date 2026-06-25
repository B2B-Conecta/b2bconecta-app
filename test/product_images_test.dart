import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/utils/product_images.dart';

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
}

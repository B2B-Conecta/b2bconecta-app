import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:motolink_pro_app/features/admin/promo_banner_crop_sheet.dart';
import 'package:motolink_pro_app/features/catalog/promo_banner_layout.dart';

void main() {
  test('web banner fit keeps the whole image inside 1320 × 493', () {
    final source = img.Image(width: 800, height: 800);
    img.fill(source, color: img.ColorRgb8(12, 80, 200));
    img.fillRect(
      source,
      x1: 0,
      y1: 360,
      x2: 799,
      y2: 439,
      color: img.ColorRgb8(220, 30, 30),
    );
    final bytes = Uint8List.fromList(img.encodePng(source));

    final fitted = fitPromoBannerImage(
      bytes,
      width: PromoBannerSpec.webFrameWidth.toInt(),
      height: PromoBannerSpec.webFrameHeight.toInt(),
    );

    final decoded = img.decodeJpg(fitted.bytes);
    expect(decoded, isNotNull);
    expect(fitted.width, 1320);
    expect(fitted.height, 493);
    expect(decoded!.width, 1320);
    expect(decoded.height, 493);
    final center = decoded.getPixel(660, 246);
    expect(center.r, greaterThan(180));
    expect(center.g, lessThan(80));
  });
}

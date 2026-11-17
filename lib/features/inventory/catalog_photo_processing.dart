import 'package:flutter/foundation.dart';

import 'catalog_photo_adjustments.dart';
import 'catalog_photo_segmentation_stub.dart'
    if (dart.library.js_interop) 'catalog_photo_segmentation_web.dart'
    as platform;

Future<({Uint8List bytes, Uint8List mask})> segmentCatalogPhoto(
    Uint8List bytes) async {
  final source = await compute(normalizeCatalogPhoto, bytes);
  return (
    bytes: source.bytes,
    mask: await platform.segmentCatalogPhoto(source.bytes)
  );
}

Future<CatalogEditedPhoto> renderCatalogBatchPhoto(
    Uint8List bytes, CatalogPhotoAdjustments settings) async {
  final cutout =
      settings.removeBackground ? await segmentCatalogPhoto(bytes) : null;
  return compute(renderCatalogPhotoWithMask, (
    request: (
      bytes: cutout?.bytes ?? bytes,
      adjustments: settings,
      preview: false,
      lossless: false,
    ),
    mask: cutout?.mask,
  ));
}

import 'dart:io';

import 'package:mobile_scanner/mobile_scanner.dart';

import 'product_image_bulk_service.dart';

bool get supportsInventoryPhotoQr =>
    Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

Future<List<String>> readInventoryPhotoQr(ProductImageBulkFile photo) async {
  if (!supportsInventoryPhotoQr) return const [];
  final directory = await Directory.systemTemp.createTemp('b2b_inventory_qr_');
  final file = File('${directory.path}/photo.${photo.extension}');
  final scanner = MobileScannerController(autoStart: false);
  try {
    await file.writeAsBytes(photo.bytes);
    final capture = await scanner.analyzeImage(
      file.path,
      formats: [BarcodeFormat.qrCode],
    );
    return [
      for (final barcode in capture?.barcodes ?? const <Barcode>[])
        if (barcode.rawValue case final value?) value,
    ];
  } finally {
    await scanner.dispose();
    if (await file.exists()) await file.delete();
    await directory.delete();
  }
}

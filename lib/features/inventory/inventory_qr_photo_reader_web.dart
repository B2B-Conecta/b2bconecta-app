import 'dart:js_interop';

import 'product_image_bulk_service.dart';

@JS('b2bCatalogReader.readPhotoQrs')
external JSPromise<JSArray<JSString>> _readPhotoQrs(JSUint8Array bytes);

const supportsInventoryPhotoQr = true;

Future<List<String>> readInventoryPhotoQr(ProductImageBulkFile photo) async =>
    (await _readPhotoQrs(photo.bytes.toJS).toDart)
        .toDart
        .map((value) => value.toDart)
        .toList();

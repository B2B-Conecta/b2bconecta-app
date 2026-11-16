import 'dart:js_interop';
import 'dart:typed_data';

@JS('b2bCatalogReader.preparePhoto')
external JSPromise<JSUint8Array> _preparePhoto(JSUint8Array bytes);

Future<Uint8List> segmentCatalogPhoto(Uint8List bytes) async {
  final mask = await _preparePhoto(bytes.toJS).toDart;
  return mask.toDart;
}

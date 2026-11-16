import 'dart:typed_data';

import 'catalog_photo_source.dart';
import 'catalog_document_reader_stub.dart'
    if (dart.library.js_interop) 'catalog_document_reader_web.dart' as platform;

typedef CatalogDocumentSheet = ({
  String name,
  Uint8List csv,
  List<CatalogSourcePhoto> photos,
  List<String> notices,
  int headerOffset,
});

Future<List<CatalogDocumentSheet>> readCatalogDocument(
  Uint8List bytes,
  String name,
  void Function(String) onProgress,
) =>
    platform.readCatalogDocument(bytes, name, onProgress);

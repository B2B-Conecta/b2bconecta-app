import 'dart:typed_data';

import 'catalog_document_reader.dart';

Future<List<CatalogDocumentSheet>> readCatalogDocument(
  Uint8List bytes,
  String name,
  void Function(String) onProgress,
) async =>
    throw UnsupportedError(
        'Abre Inventario en la web para importar XLS o PDF.');

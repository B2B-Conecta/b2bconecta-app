import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'catalog_document_reader.dart';
import 'catalog_photo_source.dart';
import 'product_images.dart';

@JS('b2bCatalogReader')
extension type _Reader(JSObject _) implements JSObject {
  external JSPromise<_Result> read(
      JSUint8Array bytes, String name, JSFunction progress);
}

extension type _Result(JSObject _) implements JSObject {
  external String? get error;
  external JSArray<_Sheet> get sheets;
  external JSArray<JSString> get notes;
}

extension type _Sheet(JSObject _) implements JSObject {
  external String get name;
  external String get csv;
  external JSArray<_Photo> get photos;
  external JSArray<JSString> get notes;
  external int get headerOffset;
}

extension type _Photo(JSObject _) implements JSObject {
  external JSUint8Array get bytes;
  external String get name;
  external int? get row;
  external bool get singleRow;
}

@JS('b2bCatalogReader')
external _Reader? get _reader;

Future<List<CatalogDocumentSheet>> readCatalogDocument(
  Uint8List bytes,
  String name,
  void Function(String) onProgress,
) async {
  final reader = _reader;
  if (reader == null) {
    throw const FormatException('El lector web todavía no está disponible.');
  }
  final result = await reader
      .read(
          bytes.toJS,
          name,
          ((String message) {
            onProgress(message);
          }).toJS)
      .toDart;
  if (result.error case final error?) throw FormatException(error);
  final notices = result.notes.toDart.map((note) => note.toDart).toList();
  return result.sheets.toDart.map((sheet) {
    final photos = <CatalogSourcePhoto>[];
    final issues = [
      ...notices,
      ...sheet.notes.toDart.map((note) => note.toDart)
    ];
    for (final photo in sheet.photos.toDart) {
      var ext = photo.name.split('.').last.toLowerCase();
      if (!isAllowedProductImageExtension(ext)) {
        issues.add('${photo.name}: formato de imagen incompatible.');
        continue;
      }
      if (ext == 'jpg') ext = 'jpeg';
      photos.add((
        bytes: photo.bytes.toDart,
        name: photo.name,
        extension: ext,
        sourceRow: photo.row,
        singleRow: photo.singleRow,
      ));
    }
    return (
      name: sheet.name,
      csv: Uint8List.fromList(utf8.encode(sheet.csv)),
      photos: photos,
      notices: issues,
      headerOffset: sheet.headerOffset,
    );
  }).toList();
}

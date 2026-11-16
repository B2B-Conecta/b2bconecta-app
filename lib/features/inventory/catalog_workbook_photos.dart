import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'catalog_photo_source.dart';
import 'product_images.dart';

/// Reads worksheet drawings by their package relationships and physical rows.
CatalogPhotoSource readWorkbookPhotos(
  ({Uint8List bytes, String? sheetName}) request,
) {
  final reader = _WorkbookPhotoReader(ZipDecoder().decodeBytes(request.bytes));
  return reader.read(request.sheetName);
}

class _WorkbookPhotoReader {
  _WorkbookPhotoReader(this.archive);

  final Archive archive;
  final _documents = <String, XmlDocument?>{};
  final _media = <String, Uint8List>{};
  final _issues = <String>[];
  int _totalBytes = 0;

  static const _maxPhotoBytes = 10 * 1024 * 1024;
  static const _maxTotalBytes = 100 * 1024 * 1024;
  static const _maxXmlBytes = 20 * 1024 * 1024;
  static const _officeRelationships =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _strictRelationships =
      'http://purl.oclc.org/ooxml/officeDocument/relationships';

  CatalogPhotoSource read(String? sheetName) {
    const workbook = 'xl/workbook.xml';
    final sheets = _elements(_xml(workbook), 'sheet');
    final sheet = sheetName == null
        ? sheets.firstOrNull
        : sheets
            .where((node) => node.getAttribute('name') == sheetName)
            .firstOrNull;
    final name = sheet?.getAttribute('name');
    final sheetPart = sheet == null
        ? null
        : _relationships(workbook)[_relationshipId(sheet, 'id')];
    final photos = <CatalogSourcePhoto>[];
    if (sheetPart != null) {
      final drawings = _relationships(sheetPart);
      for (final reference in _elements(_xml(sheetPart), 'drawing')) {
        final drawing = drawings[_relationshipId(reference, 'id')];
        if (drawing != null) _readDrawing(drawing, photos);
      }
    }
    return (sheet: name, photos: photos, issues: _issues);
  }

  void _readDrawing(String path, List<CatalogSourcePhoto> photos) {
    final related = _relationships(path);
    final document = _xml(path);
    if (document == null) return;
    for (final anchor in document.rootElement.childElements) {
      final picture = _child(anchor, 'pic');
      if (picture == null) continue;
      final blip = _elements(picture, 'blip').firstOrNull;
      final target =
          blip == null ? null : related[_relationshipId(blip, 'embed')];
      final name = target?.split('/').last ?? 'Imagen de Excel';
      final from = _child(anchor, 'from');
      final to = _child(anchor, 'to');
      final zeroBasedRow = _number(_child(from, 'row'));
      final sourceRow =
          zeroBasedRow != null && zeroBasedRow >= 0 ? zeroBasedRow + 1 : null;
      final end = _number(_child(to, 'row'));
      final endOffset = _number(_child(to, 'rowOff'));
      final singleRow = sourceRow != null &&
          (anchor.name.local == 'oneCellAnchor' ||
              (anchor.name.local == 'twoCellAnchor' &&
                  (end == zeroBasedRow ||
                      (end == sourceRow && endOffset == 0))));
      final extension = name.split('.').last.toLowerCase();
      final location = sourceRow == null ? name : '$name (fila $sourceRow)';
      if (target == null || !isAllowedProductImageExtension(extension)) {
        _issues.add('$location: imagen externa o formato incompatible.');
        continue;
      }
      final bytes = _imageBytes(target);
      if (bytes == null) {
        _issues
            .add('$location: imagen vacía, dañada o supera el límite de peso.');
        continue;
      }
      photos.add((
        bytes: bytes,
        name: name,
        extension: extension == 'jpg' ? 'jpeg' : extension,
        sourceRow: sourceRow,
        singleRow: singleRow,
      ));
    }
  }

  Uint8List? _imageBytes(String path) {
    final previous = _media[path];
    if (previous != null) return previous;
    final file = archive.findFile(path);
    if (file == null ||
        !file.isFile ||
        file.isSymbolicLink ||
        file.size <= 0 ||
        file.size > _maxPhotoBytes ||
        _totalBytes + file.size > _maxTotalBytes) {
      return null;
    }
    try {
      final content = file.content;
      if (content is! List<int> || content.length != file.size) return null;
      _totalBytes += content.length;
      return _media[path] =
          content is Uint8List ? content : Uint8List.fromList(content);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _relationships(String part) {
    final separator = part.lastIndexOf('/') + 1;
    final folder = part.substring(0, separator);
    final name = part.substring(separator);
    final document = _xml('${folder}_rels/$name.rels');
    return {
      for (final node in _elements(document, 'Relationship'))
        if (node.getAttribute('Id') case final id?)
          if (node.getAttribute('TargetMode')?.toLowerCase() != 'external')
            if (_resolve(folder, node.getAttribute('Target'))
                case final target?)
              id: target,
    };
  }

  String? _resolve(String folder, String? raw) {
    if (raw == null || raw.isEmpty || raw.contains(RegExp(r'[\\:#?]'))) {
      return null;
    }
    final resolved =
        Uri.tryParse('https://workbook.invalid/$folder')?.resolve(raw);
    if (resolved == null || resolved.host != 'workbook.invalid') return null;
    final path = resolved.pathSegments.join('/');
    return path.startsWith('xl/') && archive.findFile(path) != null
        ? path
        : null;
  }

  XmlDocument? _xml(String path) => _documents.putIfAbsent(path, () {
        final file = archive.findFile(path);
        if (file == null || file.isSymbolicLink) return null;
        if (file.size > _maxXmlBytes) {
          _issues.add('$path: se superó el límite de lectura.');
          return null;
        }
        try {
          return XmlDocument.parse(utf8.decode(file.content as List<int>));
        } catch (_) {
          _issues.add('$path: no se pudo leer.');
          return null;
        }
      });

  static Iterable<XmlElement> _elements(XmlNode? node, String name) =>
      node?.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == name) ??
      const [];

  static XmlElement? _child(XmlElement? node, String name) =>
      node?.childElements.where((e) => e.name.local == name).firstOrNull;

  static int? _number(XmlElement? node) => int.tryParse(node?.innerText ?? '');

  static String? _relationshipId(XmlElement node, String name) =>
      node.getAttribute(name, namespace: _officeRelationships) ??
      node.getAttribute(name, namespace: _strictRelationships);
}

import 'package:file_saver/file_saver.dart';

const imageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'bmp',
};

bool storedFileIsImage(String fileName, [String? url]) {
  final ext = storedFileExtension(fileName, url);
  return imageExtensions.contains(ext);
}

String storedFileExtension(String fileName, [String? url]) {
  String extOf(String value) {
    final clean = value.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot == clean.length - 1) return '';
    return clean.substring(dot + 1).toLowerCase();
  }

  final fromName = extOf(fileName.trim());
  if (fromName.isNotEmpty) return fromName;
  if (url == null || url.isEmpty) return '';
  final path = Uri.tryParse(url)?.path ?? '';
  return extOf(path);
}

String storedFileBaseName(String fileName, String ext) {
  var name = fileName.trim();
  if (name.isEmpty) return 'archivo';
  if (ext.isNotEmpty && name.toLowerCase().endsWith('.$ext')) {
    name = name.substring(0, name.length - ext.length - 1);
  }
  name = name.replaceAll(RegExp(r'[\\/]+'), '_').trim();
  return name.isEmpty ? 'archivo' : name;
}

String storedFileDisplayName(String? fileName, String url) {
  final given = fileName?.trim();
  if (given != null && given.isNotEmpty) return given;
  final path = Uri.tryParse(url)?.pathSegments;
  if (path == null || path.isEmpty) return 'Archivo';
  return Uri.decodeComponent(path.last);
}

MimeType storedFileMimeType(String ext) {
  return switch (ext) {
    'pdf' => MimeType.pdf,
    'png' => MimeType.png,
    'jpg' || 'jpeg' => MimeType.jpeg,
    'gif' => MimeType.gif,
    'bmp' => MimeType.bmp,
    _ => MimeType.other,
  };
}

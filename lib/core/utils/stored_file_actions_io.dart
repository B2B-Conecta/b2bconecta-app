import 'dart:io' show Platform;

import 'package:file_saver/file_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import 'stored_file_name.dart';

Future<void> openStoredFileExternally(String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok) {
    throw StateError('No se pudo abrir el archivo.');
  }
}

Future<void> downloadStoredFile(String url, String fileName) async {
  final ext = storedFileExtension(fileName, url);
  final name = storedFileBaseName(fileName, ext);
  final mime = storedFileMimeType(ext);
  if (Platform.isIOS || Platform.isMacOS) {
    final path = await FileSaver.instance.saveAs(
      name: name,
      link: LinkDetails(link: url),
      ext: ext,
      mimeType: mime,
    );
    if (path == null || path.isEmpty) {
      throw StateError('Descarga cancelada.');
    }
    return;
  }
  await FileSaver.instance.saveFile(
    name: name,
    link: LinkDetails(link: url),
    ext: ext,
    mimeType: mime,
  );
}

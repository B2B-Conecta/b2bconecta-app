// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Abre el enlace en otra pestaña en el mismo toque, sin esperar otra red.
Future<void> openStoredFileExternally(String url) {
  _clickAnchor(url, downloadName: null, newTab: true);
  return Future.value();
}

/// Descarga el archivo. En iPhone el navegador no permite forzar la descarga
/// de un enlace externo, así que lo abre para guardarlo desde allí.
Future<void> downloadStoredFile(String url, String fileName) {
  final agent = html.window.navigator.userAgent;
  final ios = agent.contains('iPhone') ||
      agent.contains('iPad') ||
      agent.contains('iPod');
  _clickAnchor(
    url,
    downloadName: _safeFileName(fileName),
    newTab: ios,
  );
  return Future.value();
}

void _clickAnchor(
  String url, {
  required String? downloadName,
  required bool newTab,
}) {
  final anchor = html.AnchorElement(href: url)
    ..rel = 'noopener noreferrer'
    ..style.display = 'none';
  if (newTab) anchor.target = '_blank';
  if (downloadName != null && downloadName.isNotEmpty) {
    anchor.download = downloadName;
  }
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

String _safeFileName(String fileName) {
  final cleaned = fileName.trim().replaceAll(RegExp(r'[\\/]+'), '_');
  return cleaned.isEmpty ? 'archivo' : cleaned;
}

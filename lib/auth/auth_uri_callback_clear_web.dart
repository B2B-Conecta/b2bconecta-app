// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Quita parámetros Auth (`code`, `error`, …) y el fragmento `#...` de la URL.
void clearAuthUriCallback() {
  final location = html.window.location;
  final uri = Uri.parse(location.href);
  final params = Map<String, String>.from(uri.queryParameters)
    ..remove('code')
    ..remove('type')
    ..remove('error')
    ..remove('error_code')
    ..remove('error_description');

  final search = params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

  final path = html.window.location.pathname;
  html.window.history.replaceState(null, '', '$path$search');
}

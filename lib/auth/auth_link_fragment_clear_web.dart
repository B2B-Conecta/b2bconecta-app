// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Quita `#access_token=...` / `#error=...` de la barra de dirección (web).
void clearAuthUriFragment() {
  final path = html.window.location.pathname;
  final search = html.window.location.search;
  html.window.history.replaceState(null, '', '$path$search');
}

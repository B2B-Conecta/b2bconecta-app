// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void replaceBrowserPath(String path, {String query = ''}) {
  html.window.history.replaceState(null, '', _join(path, query));
}

void pushBrowserPath(String path, {String query = ''}) {
  html.window.history.pushState(null, '', _join(path, query));
}

String _join(String path, String query) {
  final q = query.trim();
  if (q.isEmpty) return path;
  return '$path${q.startsWith('?') ? q : '?$q'}';
}

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Navegación a la home de la app (limpia query legal en web).
void navigateToAppHome() {
  final origin = html.window.location.origin;
  html.window.location.assign('$origin/');
}

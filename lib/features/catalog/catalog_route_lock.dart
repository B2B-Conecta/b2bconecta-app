import 'package:flutter/widgets.dart';

/// Ignora toques repetidos mientras se abre una ficha o una vitrina.
abstract final class CatalogRouteLock {
  static bool _busy = false;

  static bool tryHold() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  static void release() {
    _busy = false;
  }

  static Future<T?> push<T>(BuildContext context, Route<T> route) {
    if (_busy) return Future<T?>.value(null);
    _busy = true;
    return pushHeld(context, route);
  }

  /// La ruta ya está reservada con [tryHold]. Se libera al frame siguiente
  /// para que la ficha nueva pueda abrir relacionados o volver atrás.
  static Future<T?> pushHeld<T>(BuildContext context, Route<T> route) {
    final future = Navigator.of(context).push<T>(route);
    WidgetsBinding.instance.addPostFrameCallback((_) => _busy = false);
    return future;
  }
}

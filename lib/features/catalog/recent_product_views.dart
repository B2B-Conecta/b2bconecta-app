import 'package:flutter/foundation.dart';

/// Historial local de la cuenta durante la sesión de la aplicación.
abstract final class RecentProductViews {
  static final _revision = ValueNotifier(0);
  static Listenable get changes => _revision;
  static String? _viewerId;
  static final _ids = <String>[];

  static List<String> forViewer(String id) =>
      id == _viewerId ? List.unmodifiable(_ids) : const [];

  static void record(String viewerId, String productId) {
    if (productId.isEmpty) return;
    if (_viewerId != viewerId) {
      _viewerId = viewerId;
      _ids.clear();
    }
    if (_ids.isNotEmpty && _ids.first == productId) return;
    _ids.remove(productId);
    _ids.insert(0, productId);
    if (_ids.length > 8) _ids.removeLast();
    _revision.value++;
  }
}

import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

/// Favoritos de la tienda minorista. El corazón y la pestaña leen la misma lista.
class AliadoFavoritesService extends ChangeNotifier {
  AliadoFavoritesService._();

  static final AliadoFavoritesService instance = AliadoFavoritesService._();

  final Set<String> _ids = {};
  List<PartModel> _parts = const [];
  bool _loaded = false;
  Future<void>? _inFlight;

  bool get loaded => _loaded;

  List<PartModel> get parts => _parts;

  bool contains(String productId) => _ids.contains(productId.trim());

  Future<void> refresh() {
    final current = _inFlight;
    if (current != null) return current;
    final run = _refresh();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<void> _refresh() async {
    final res = await SupabaseAccess.client.rpc('list_aliado_product_favorites');
    final rows = SupabaseAccess.decodeRpcJsonArray(res);
    final next = <PartModel>[];
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final part = PartModel.fromJson(Map<String, dynamic>.from(row));
      if (part.id.isEmpty) continue;
      next.add(part);
      ids.add(part.id);
    }
    _parts = next;
    _ids
      ..clear()
      ..addAll(ids);
    _loaded = true;
    notifyListeners();
  }

  /// Devuelve true si el producto quedó guardado.
  Future<bool> toggle(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return false;
    final next = !_ids.contains(id);
    if (next) {
      _ids.add(id);
    } else {
      _ids.remove(id);
      _parts = _parts.where((p) => p.id != id).toList(growable: false);
    }
    notifyListeners();
    try {
      final saved = await SupabaseAccess.client.rpc(
        'set_aliado_product_favorite',
        params: <String, dynamic>{
          'p_product_id': id,
          'p_saved': next,
        },
      );
      final isSaved = saved == true;
      if (isSaved != next) {
        await _refresh();
      } else if (isSaved) {
        await _refresh();
      }
      return isSaved;
    } catch (e) {
      if (next) {
        _ids.remove(id);
      } else {
        _ids.add(id);
      }
      notifyListeners();
      rethrow;
    }
  }
}

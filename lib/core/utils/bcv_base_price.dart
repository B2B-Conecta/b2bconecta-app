import 'package:motolink_pro_app/core/data/supabase_service.dart';

/// Precio en Bs del precio base REF: `REF × tasa BCV`.
///
/// Cache de proceso; llamar [refresh] al reanudar la app o al abrir el badge.
class BcvBasePrice {
  BcvBasePrice._();

  static double? _rate;
  static DateTime? _updatedAt;
  static String? _effectiveDate;
  static Future<double?>? _loading;
  static DateTime? _fetchedAt;

  static double? get cachedRate => _rate;
  static DateTime? get cachedUpdatedAt => _updatedAt;
  static String? get cachedEffectiveDate => _effectiveDate;

  static Future<double?> currentRate() {
    final known = _rate;
    if (known != null && known > 0 && !_isStale()) {
      return Future<double?>.value(known);
    }
    return refresh();
  }

  static bool _isStale() {
    final at = _fetchedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > const Duration(minutes: 5);
  }

  /// Vuelve a leer `app_global_config.tasa_bcv` (valor más reciente).
  static Future<double?> refresh({bool force = false}) {
    if (!force && _rate != null && _rate! > 0 && !_isStale()) {
      return Future<double?>.value(_rate);
    }
    return _loading ??= SupabaseService.fetchGlobalTasaBcvRecord().then((rec) {
      if (rec != null && rec.tasa > 0) {
        _rate = rec.tasa;
        _updatedAt = rec.updatedAt;
        _effectiveDate = rec.effectiveDate;
        _fetchedAt = DateTime.now();
      }
      _loading = null;
      return _rate;
    });
  }

  static void invalidate() {
    _rate = null;
    _updatedAt = null;
    _effectiveDate = null;
    _fetchedAt = null;
    _loading = null;
  }

  static double? bsForRef(double? refUsd, double? rate) {
    if (refUsd == null || refUsd < 0 || rate == null || rate <= 0) return null;
    return refUsd * rate;
  }
}

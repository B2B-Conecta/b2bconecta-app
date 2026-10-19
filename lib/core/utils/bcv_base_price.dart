import 'package:motolink_pro_app/core/data/supabase_service.dart';

/// Precio en Bs del precio base REF: `REF × tasa BCV`.
class BcvBasePrice {
  BcvBasePrice._();

  static double? _rate;
  static Future<double?>? _loading;

  static Future<double?> currentRate() {
    final known = _rate;
    if (known != null && known > 0) return Future<double?>.value(known);
    return _loading ??= SupabaseService.fetchGlobalTasaBcv().then((rate) {
      if (rate != null && rate > 0) _rate = rate;
      _loading = null;
      return _rate;
    });
  }

  static double? bsForRef(double? refUsd, double? rate) {
    if (refUsd == null || refUsd < 0 || rate == null || rate <= 0) return null;
    return refUsd * rate;
  }
}

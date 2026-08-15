import 'package:shared_preferences/shared_preferences.dart';

/// Control local: pop-up promocional como máximo 1 vez cada 24 h por campaña.
abstract final class PromoPopupFrequency {
  PromoPopupFrequency._();

  static const _prefix = 'promo_popup_shown_';
  static const _dayMs = 24 * 60 * 60 * 1000;

  static Future<bool> shouldShow(String campaignId) async {
    final id = campaignId.trim();
    if (id.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('$_prefix$id');
    if (last == null) return true;
    return DateTime.now().millisecondsSinceEpoch - last >= _dayMs;
  }

  static Future<void> markShown(String campaignId) async {
    final id = campaignId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_prefix$id',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

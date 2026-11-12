import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del panel admin (web) para avisos.
class AdminNotificationPrefs {
  AdminNotificationPrefs._();

  static const _muteKey = 'admin_notif_mute_all';
  static const _newOrderKey = 'admin_notif_new_orders';
  static const _kycKey = 'admin_notif_kyc_talleres';
  static const _supportKey = 'admin_notif_support_messages';
  static const _weeklyDigestKey = 'admin_notif_weekly_digest';
  static const _bcvKey = 'admin_notif_bcv';
  static const _platformKey = 'admin_notif_platform_updates';

  /// Legacy keys (migración).
  static const _legacySoundKey = 'admin_notif_sound';
  static const _legacyDailyEmailKey = 'admin_notif_daily_email';

  bool muteAll = false;
  bool newOrderAlerts = true;
  bool kycPendingAlerts = true;
  bool supportMessageAlerts = true;
  bool weeklyDigest = false;
  bool bcvRateAlerts = true;
  bool platformUpdates = true;

  static Future<AdminNotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final hasNewOrder = prefs.containsKey(_newOrderKey);
    final hasWeekly = prefs.containsKey(_weeklyDigestKey);
    return AdminNotificationPrefs._()
      ..muteAll = prefs.getBool(_muteKey) ?? false
      ..newOrderAlerts = hasNewOrder
          ? (prefs.getBool(_newOrderKey) ?? true)
          : (prefs.getBool(_legacySoundKey) ?? true)
      ..kycPendingAlerts = prefs.getBool(_kycKey) ?? true
      ..supportMessageAlerts = prefs.getBool(_supportKey) ?? true
      ..weeklyDigest = hasWeekly
          ? (prefs.getBool(_weeklyDigestKey) ?? false)
          : (prefs.getBool(_legacyDailyEmailKey) ?? false)
      ..bcvRateAlerts = prefs.getBool(_bcvKey) ?? true
      ..platformUpdates = prefs.getBool(_platformKey) ?? true;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, muteAll);
    await prefs.setBool(_newOrderKey, newOrderAlerts);
    await prefs.setBool(_kycKey, kycPendingAlerts);
    await prefs.setBool(_supportKey, supportMessageAlerts);
    await prefs.setBool(_weeklyDigestKey, weeklyDigest);
    await prefs.setBool(_bcvKey, bcvRateAlerts);
    await prefs.setBool(_platformKey, platformUpdates);
  }
}

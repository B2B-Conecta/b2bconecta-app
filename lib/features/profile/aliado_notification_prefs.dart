import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales de alertas in-app del portal minorista.
class AliadoNotificationPrefs {
  AliadoNotificationPrefs._();

  static const _ordersKey = 'aliado_notif_order_approved';
  static const _kycKey = 'aliado_notif_kyc_reminders';
  static const _messagesKey = 'aliado_notif_wholesale_messages';

  bool orderApproved = true;
  bool kycReminders = true;
  bool wholesaleMessages = true;

  static Future<AliadoNotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AliadoNotificationPrefs._()
      ..orderApproved = prefs.getBool(_ordersKey) ?? true
      ..kycReminders = prefs.getBool(_kycKey) ?? true
      ..wholesaleMessages = prefs.getBool(_messagesKey) ?? true;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ordersKey, orderApproved);
    await prefs.setBool(_kycKey, kycReminders);
    await prefs.setBool(_messagesKey, wholesaleMessages);
  }
}

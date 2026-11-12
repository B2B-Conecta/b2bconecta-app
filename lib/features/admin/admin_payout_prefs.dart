import 'package:shared_preferences/shared_preferences.dart';

/// Método de cobro local del panel admin (Zelle / cuenta bancaria).
class AdminPayoutPrefs {
  AdminPayoutPrefs({
    this.method = 'zelle',
    this.label = 'Zelle',
    this.mask = '•••• 4892',
  });

  static const _methodKey = 'admin_payout_method';
  static const _labelKey = 'admin_payout_label';
  static const _maskKey = 'admin_payout_mask';

  /// `zelle` | `bank`
  String method;
  String label;
  String mask;

  String get displayLine {
    final m = method == 'bank'
        ? (label.trim().isEmpty ? 'Banco Nacional' : label)
        : (label.trim().isEmpty ? 'Zelle' : label);
    return '$m · $mask';
  }

  static Future<AdminPayoutPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AdminPayoutPrefs(
      method: prefs.getString(_methodKey) ?? 'zelle',
      label: prefs.getString(_labelKey) ?? 'Zelle',
      mask: prefs.getString(_maskKey) ?? '•••• 4892',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_methodKey, method);
    await prefs.setString(_labelKey, label);
    await prefs.setString(_maskKey, mask);
  }
}

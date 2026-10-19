/// Fila de `list_admin_incomplete_signups`: Auth sin ficha en `profiles`.
class IncompleteSignupRow {
  const IncompleteSignupRow({
    required this.userId,
    this.email,
    this.phone,
    this.displayName,
    this.createdAt,
    this.lastSignInAt,
    this.emailConfirmedAt,
  });

  final String userId;
  final String? email;
  final String? phone;
  final String? displayName;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? emailConfirmedAt;

  bool get emailConfirmed => emailConfirmedAt != null;

  String get title {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    final tel = phone?.trim();
    if (tel != null && tel.isNotEmpty) return tel;
    return 'Sin correo';
  }

  factory IncompleteSignupRow.fromJson(Map<String, dynamic> json) {
    String? text(dynamic raw) {
      final value = raw?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    DateTime? date(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return IncompleteSignupRow(
      userId: json['user_id']?.toString() ?? '',
      email: text(json['email']),
      phone: text(json['phone']),
      displayName: text(json['display_name']),
      createdAt: date(json['created_at']),
      lastSignInAt: date(json['last_sign_in_at']),
      emailConfirmedAt: date(json['email_confirmed_at']),
    );
  }
}

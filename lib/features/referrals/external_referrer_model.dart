/// Vendedor externo de referidos (admin).
class ExternalReferrerModel {
  const ExternalReferrerModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.code,
    required this.active,
    this.notes,
    this.referredCount = 0,
    this.lastReferralAt,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String code;
  final bool active;
  final String? notes;
  final int referredCount;
  final DateTime? lastReferralAt;
  final DateTime? createdAt;

  factory ExternalReferrerModel.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      final t = v?.toString().trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    return ExternalReferrerModel(
      id: (json['referrer_id'] ?? json['id'])?.toString() ?? '',
      fullName: text(json['full_name']) ?? '',
      phone: text(json['phone']) ?? '',
      email: text(json['email']) ?? '',
      code: text(json['code'] ?? json['referral_code']) ?? '',
      active: json['active'] == true || json['active']?.toString() == 'true',
      notes: text(json['notes']),
      referredCount: int.tryParse('${json['referred_count'] ?? 0}') ?? 0,
      lastReferralAt: json['last_referral_at'] != null
          ? DateTime.tryParse(json['last_referral_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

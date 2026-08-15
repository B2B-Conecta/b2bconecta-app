/// Fila de `list_admin_referral_stats`.
class AdminReferralStatRowModel {
  const AdminReferralStatRowModel({
    required this.referrerId,
    this.businessName,
    this.rif,
    this.role,
    this.referralCode,
    this.referredCount = 0,
    this.lastReferralAt,
  });

  final String referrerId;
  final String? businessName;
  final String? rif;
  final String? role;
  final String? referralCode;
  final int referredCount;
  final DateTime? lastReferralAt;

  factory AdminReferralStatRowModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    String? text(dynamic v) {
      final t = v?.toString().trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    return AdminReferralStatRowModel(
      referrerId: json['referrer_id']?.toString() ?? '',
      businessName: text(json['business_name']),
      rif: text(json['rif']),
      role: text(json['role']),
      referralCode: text(json['referral_code']),
      referredCount: parseInt(json['referred_count']),
      lastReferralAt: json['last_referral_at'] != null
          ? DateTime.tryParse(json['last_referral_at'].toString())
          : null,
    );
  }
}

/// Fila de `list_admin_referred_users`.
class AdminReferredUserRowModel {
  const AdminReferredUserRowModel({
    required this.profileId,
    this.businessName,
    this.rif,
    this.role,
    this.referredAt,
    this.accountAccessStatus,
    this.createdAt,
  });

  final String profileId;
  final String? businessName;
  final String? rif;
  final String? role;
  final DateTime? referredAt;
  final String? accountAccessStatus;
  final DateTime? createdAt;

  factory AdminReferredUserRowModel.fromJson(Map<String, dynamic> json) {
    String? text(dynamic v) {
      final t = v?.toString().trim();
      if (t == null || t.isEmpty) return null;
      return t;
    }

    return AdminReferredUserRowModel(
      profileId: json['profile_id']?.toString() ?? '',
      businessName: text(json['business_name']),
      rif: text(json['rif']),
      role: text(json['role']),
      referredAt: json['referred_at'] != null
          ? DateTime.tryParse(json['referred_at'].toString())
          : null,
      accountAccessStatus: text(json['account_access_status']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

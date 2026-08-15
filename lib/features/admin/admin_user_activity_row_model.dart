/// Fila de `list_admin_user_activity_monitoring` (panel admin).
class AdminUserActivityRowModel {
  const AdminUserActivityRowModel({
    required this.profileId,
    this.businessName,
    this.rif,
    this.role,
    this.estado,
    this.ciudad,
    this.loginCountPeriod = 0,
    this.loginCountToday = 0,
    this.ordersCountPeriod = 0,
    this.ordersDeliveredPeriod = 0,
    this.ordersVolumeUsdPeriod = 0,
    this.ordersInProgressPeriod = 0,
    this.lastLoginAt,
  });

  final String profileId;
  final String? businessName;
  final String? rif;
  final String? role;
  final String? estado;
  final String? ciudad;
  final int loginCountPeriod;
  final int loginCountToday;
  final int ordersCountPeriod;
  final int ordersDeliveredPeriod;
  final double ordersVolumeUsdPeriod;
  final int ordersInProgressPeriod;
  final DateTime? lastLoginAt;

  bool get isAliado => role?.trim().toLowerCase() == 'aliado';
  bool get isImportador => role?.trim().toLowerCase() == 'importador';

  String get ordersLabel => isImportador ? 'Ventas' : 'Compras';

  factory AdminUserActivityRowModel.fromJson(Map<String, dynamic> json) {
    double parseUsd(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? lastLogin;
    final rawLast = json['last_login_at'];
    if (rawLast != null) {
      lastLogin = DateTime.tryParse(rawLast.toString());
    }

    return AdminUserActivityRowModel(
      profileId: json['profile_id']?.toString() ?? '',
      businessName: json['business_name']?.toString(),
      rif: json['rif']?.toString(),
      role: json['role']?.toString(),
      estado: json['estado']?.toString(),
      ciudad: json['ciudad']?.toString(),
      loginCountPeriod: parseInt(json['login_count_period']),
      loginCountToday: parseInt(json['login_count_today']),
      ordersCountPeriod: parseInt(json['orders_count_period']),
      ordersDeliveredPeriod: parseInt(json['orders_delivered_period']),
      ordersVolumeUsdPeriod: parseUsd(json['orders_volume_usd_period']),
      ordersInProgressPeriod: parseInt(json['orders_in_progress_period']),
      lastLoginAt: lastLogin,
    );
  }
}

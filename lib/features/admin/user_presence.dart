/// Ventana de "en línea". Varias pestañas comparten la misma cuenta.
const userPresenceOnlineWindow = Duration(minutes: 5);

/// La consulta de presencia del panel admin solo la puede pedir un administrador.
bool canQueryAdminPresence(String? role) =>
    role?.trim().toLowerCase() == 'administrador';

bool userPresenceIsOnline(
  DateTime? lastSeen,
  DateTime now, {
  Duration window = userPresenceOnlineWindow,
}) {
  if (lastSeen == null) return false;
  final age = now.difference(lastSeen.toLocal());
  if (age.isNegative) return true;
  return age <= window;
}

class AdminUserPresenceRow {
  const AdminUserPresenceRow({
    required this.profileId,
    required this.displayName,
    this.businessName,
    this.role,
    this.lastSeenAt,
  });

  final String profileId;
  final String displayName;
  final String? businessName;
  final String? role;
  final DateTime? lastSeenAt;

  bool isOnlineAt(DateTime now) => userPresenceIsOnline(lastSeenAt, now);

  factory AdminUserPresenceRow.fromJson(Map<String, dynamic> json) {
    DateTime? seen;
    final raw = json['last_seen_at'];
    if (raw != null) seen = DateTime.tryParse(raw.toString());
    final name = json['display_name']?.toString().trim();
    return AdminUserPresenceRow(
      profileId: json['profile_id']?.toString() ?? '',
      displayName: (name == null || name.isEmpty) ? 'Usuario' : name,
      businessName: json['business_name']?.toString(),
      role: json['role']?.toString(),
      lastSeenAt: seen,
    );
  }
}

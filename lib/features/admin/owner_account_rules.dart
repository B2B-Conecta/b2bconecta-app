/// Reglas de la pestaña Cuentas (solo owner). La autoridad real está en SQL.
abstract final class OwnerAccountRules {
  static bool canManageTarget({
    required bool viewerIsOwner,
    required String viewerId,
    required String targetId,
    required bool targetIsOwner,
  }) {
    if (!viewerIsOwner) return false;
    if (viewerId.isEmpty || targetId.isEmpty) return false;
    if (targetId == viewerId) return false;
    if (targetIsOwner) return false;
    return true;
  }

  /// Estado visible en el panel owner. No usa la palabra Superadmin.
  static String statusLabelEs({
    required String? role,
    required String? accountAccessStatus,
    DateTime? deactivatedAt,
  }) {
    if (deactivatedAt != null) return 'Eliminada';
    final access = accountAccessStatus?.trim();
    if (access == 'rejected') {
      final r = role?.trim().toLowerCase();
      if (r == 'administrador') return 'Bloqueada';
      return 'Bloqueada';
    }
    if (access == 'active') return 'Activa';
    if (access == 'pending_review') return 'En revisión';
    if (access == 'draft') return 'Borrador';
    return 'Sin estado';
  }
}

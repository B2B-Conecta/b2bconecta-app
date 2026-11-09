/// Reglas de la pestaña Cuentas. La autoridad real está en SQL.
///
/// El propietario (`is_owner`) gestiona cualquier cuenta que no sea la suya
/// ni otro propietario. Un administrador sin ese flag crea, edita el
/// expediente y elimina solo tiendas minoristas y mayoristas.
abstract final class OwnerAccountRules {
  /// Cambio de rol a administrador y catálogo: solo el propietario.
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

  /// Corregir rol B2B (minorista ↔ mayorista). Admin u owner.
  /// Asignar `administrador` sigue en [canManageTarget].
  static bool canChangeB2bRole({
    required bool viewerIsOwner,
    required String? viewerRole,
    required String viewerId,
    required String targetId,
    required bool targetIsOwner,
    required String? targetRole,
  }) {
    if (viewerId.isEmpty || targetId.isEmpty) return false;
    if (targetId == viewerId) return false;
    if (targetIsOwner) return false;
    final target = targetRole?.trim().toLowerCase();
    if (target != 'aliado' && target != 'importador') return false;
    if (viewerIsOwner) return true;
    return viewerRole?.trim().toLowerCase() == 'administrador';
  }

  /// Alta de cuentas de administración: solo el propietario.
  static bool canAssignAdminRole({required bool viewerIsOwner}) =>
      viewerIsOwner;

  /// Expediente, bloqueo, baja lógica y borrado de Auth.
  ///
  /// El propietario alcanza también a otros administradores. Un admin solo
  /// alcanza cuentas `aliado` o `importador`.
  static bool canDeleteTarget({
    required bool viewerIsOwner,
    required String? viewerRole,
    required String viewerId,
    required String targetId,
    required bool targetIsOwner,
    required String? targetRole,
  }) {
    if (viewerId.isEmpty || targetId.isEmpty) return false;
    if (targetId == viewerId) return false;
    if (targetIsOwner) return false;
    if (viewerIsOwner) return true;
    if (viewerRole?.trim().toLowerCase() != 'administrador') return false;
    final role = targetRole?.trim().toLowerCase();
    return role == 'aliado' || role == 'importador';
  }

  /// Baja lógica: deja de entrar; historial y correo se conservan.
  static const softDeleteActionLabel = 'Dar de baja';

  /// Título del diálogo de baja lógica.
  static const softDeleteDialogTitle = 'Dar de baja la cuenta';

  /// Borrado de Auth: quita la cuenta y libera el correo para reutilizarlo.
  static const hardDeleteActionLabel = 'Borrar y liberar correo';

  /// Título del diálogo de borrado definitivo.
  static const hardDeleteDialogTitle = 'Borrar y liberar el correo';

  /// Estado visible en el panel owner. No usa la palabra Superadmin.
  static String statusLabelEs({
    required String? role,
    required String? accountAccessStatus,
    DateTime? deactivatedAt,
  }) {
    if (deactivatedAt != null) return 'Dada de baja';
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

  /// Borrador o en revisión: el owner puede habilitar con el expediente ya cargado.
  static bool canActivateAccess({
    required String? accountAccessStatus,
    DateTime? deactivatedAt,
  }) {
    if (deactivatedAt != null) return false;
    final access = accountAccessStatus?.trim();
    return access == 'draft' || access == 'pending_review';
  }

  /// Confirmación de borrado definitivo: debe coincidir el correo de Auth.
  static bool hardDeleteConfirmMatches({
    required String typed,
    required String? email,
  }) {
    final t = typed.trim().toLowerCase();
    final e = email?.trim().toLowerCase();
    if (t.isEmpty || e == null || e.isEmpty) return false;
    return t == e;
  }
}

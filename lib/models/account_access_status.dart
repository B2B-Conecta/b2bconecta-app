/// Control de acceso a la app para aliados (`profiles.account_access_status`).
abstract final class AccountAccessStatus {
  static const draft = 'draft';
  static const pendingReview = 'pending_review';
  static const active = 'active';
  static const rejected = 'rejected';

  static String labelEs(String? status) {
    switch (status?.trim()) {
      case draft:
        return 'Borrador — complete su registro';
      case pendingReview:
        return 'Pendiente de aprobación MotoLink';
      case active:
        return 'Acceso habilitado';
      case rejected:
        return 'Solicitud rechazada';
      default:
        return 'Pendiente de registro';
    }
  }

  /// Importadores/admin omiten este gate; aliados sin fila explícita → borrador.
  static bool allowsAppAccess({
    required String? role,
    required String? accountAccessStatus,
  }) {
    if (role?.trim().toLowerCase() != 'aliado') return true;
    return accountAccessStatus?.trim() == active;
  }
}

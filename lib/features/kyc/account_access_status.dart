/// Control de acceso a la app (`profiles.account_access_status`).
/// Aplica a aliados y mayoristas (`importador`).
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
        return 'Pendiente de aprobación B2B Conecta';
      case active:
        return 'Acceso habilitado';
      case rejected:
        return 'Solicitud rechazada';
      default:
        return 'Pendiente de registro';
    }
  }

  /// Admin siempre entra. Aliado e importador requieren `active`.
  static bool allowsAppAccess({
    required String? role,
    required String? accountAccessStatus,
  }) {
    final r = role?.trim().toLowerCase();
    if (r == 'administrador') return true;
    if (r != 'aliado' && r != 'importador') return true;
    return accountAccessStatus?.trim() == active;
  }
}

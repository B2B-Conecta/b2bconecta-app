/// Acciones sensibles del panel admin. Reflejan `_assert_administrador` en SQL.
///
/// La autoridad real sigue en las funciones RPC; aquí solo se decide si el
/// botón se muestra. Un rol vacío o desconocido no ve ninguna acción.
abstract final class AdminActionRules {
  static bool _isAdmin(String? viewerRole) =>
      viewerRole?.trim().toLowerCase() == 'administrador';

  /// Aprobar o rechazar documentos KYC y cambiar el KYC global del perfil.
  static bool canReviewKyc({required String? viewerRole}) =>
      _isAdmin(viewerRole);

  /// Habilitar o rechazar el acceso de una cuenta a la plataforma.
  static bool canSetAccountAccess({required String? viewerRole}) =>
      _isAdmin(viewerRole);

  /// Tasa global, tasa por importador y tramos por volumen.
  static bool canEditCommissionRates({required String? viewerRole}) =>
      _isAdmin(viewerRole);

  /// Configuración global de la plataforma (p. ej. tasa BCV).
  static bool canEditPlatformConfig({required String? viewerRole}) =>
      _isAdmin(viewerRole);
}

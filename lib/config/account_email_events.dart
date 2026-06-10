/// Eventos de correo transaccional (Edge Function `send-account-email`).
abstract final class AccountEmailEvent {
  static const registrationSubmitted = 'registration_submitted';
  static const profileApproved = 'profile_approved';
}

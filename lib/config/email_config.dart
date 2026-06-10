/// Remitente y mensajes de correo transaccional MotoLink.
abstract final class EmailConfig {
  static const smtpUser = 'motolink.admin@gmail.com';
  static const smtpFrom = 'MotoLink <motolink.admin@gmail.com>';
  static const smtpHost = 'smtp.gmail.com';
  static const smtpPort = '587';
  static const supportEmail = smtpUser;
}

/// Resultado del envío (sin detalles técnicos para la UI).
enum EmailDispatchOutcome {
  sent,
  skipped,
  failed,
}

extension EmailDispatchOutcomeMessages on EmailDispatchOutcome {
  String registrationSubmittedSnackBar() {
    return switch (this) {
      EmailDispatchOutcome.sent =>
        'Solicitud enviada. Revise su correo: le enviamos la confirmación.',
      EmailDispatchOutcome.skipped || EmailDispatchOutcome.failed =>
        'Solicitud enviada. MotoLink revisará su registro. '
            'Si no recibe un correo en unos minutos, revise la carpeta de spam '
            'o escriba a ${EmailConfig.supportEmail}.',
    };
  }

  String profileApprovedSnackBar() {
    return switch (this) {
      EmailDispatchOutcome.sent =>
        'Acceso habilitado. El aliado recibirá un correo de bienvenida.',
      EmailDispatchOutcome.skipped || EmailDispatchOutcome.failed =>
        'Acceso habilitado. Si el aliado no recibe correo, avísele por otro medio.',
    };
  }
}

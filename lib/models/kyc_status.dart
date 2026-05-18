/// Estado de verificación documental (`profiles.kyc_status`) para aliados e importadores.
abstract final class KycStatus {
  static const pendiente = 'pendiente';
  static const enRevision = 'en_revision';
  static const aprobado = 'aprobado';
  static const rechazado = 'rechazado';

  static String labelEs(String? status) {
    switch (status?.trim()) {
      case pendiente:
        return 'Pendiente de envío';
      case enRevision:
        return 'En revisión MotoLink';
      case aprobado:
        return 'Aprobado';
      case rechazado:
        return 'Rechazado';
      default:
        return 'Pendiente por validación';
    }
  }
}

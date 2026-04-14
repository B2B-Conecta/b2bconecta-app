/// Estado de revisión por archivo (`profile_documents.review_status`).
abstract final class DocumentReviewStatus {
  static const pendiente = 'pendiente';
  static const enRevision = 'en_revision';
  static const aprobado = 'aprobado';
  static const rechazado = 'rechazado';

  static String labelEs(String? status) {
    switch (status?.trim()) {
      case pendiente:
        return 'Listo para enviar a revisión';
      case enRevision:
        return 'En revisión MotoLink';
      case aprobado:
        return 'Aprobado';
      case rechazado:
        return 'Rechazado — suba un nuevo archivo';
      default:
        return '—';
    }
  }
}

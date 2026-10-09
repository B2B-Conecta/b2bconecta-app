/// Estado de revisión por archivo (`profile_documents.review_status`).
abstract final class DocumentReviewStatus {
  static const pendiente = 'pendiente';
  static const enRevision = 'en_revision';
  static const aprobado = 'aprobado';
  static const rechazado = 'rechazado';

  /// El dueño puede sustituir un archivo que aún no está en revisión ni aprobado.
  static bool ownerCanReplace(String? status) {
    switch (status?.trim()) {
      case enRevision:
      case aprobado:
        return false;
      default:
        return true;
    }
  }

  static String labelEs(String? status) {
    switch (status?.trim()) {
      case pendiente:
        return 'Listo para enviar a revisión';
      case enRevision:
        return 'En revisión B2B Conecta';
      case aprobado:
        return 'Aprobado';
      case rechazado:
        return 'Rechazado — suba un nuevo archivo';
      default:
        return '—';
    }
  }
}

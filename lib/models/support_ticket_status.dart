/// Estados de `support_tickets`.
abstract final class SupportTicketStatus {
  static const abierto = 'abierto';
  static const enRevision = 'en_revision';
  static const cerrado = 'cerrado';

  static const openStatuses = [abierto, enRevision];

  static String labelEs(String status) {
    switch (status.trim()) {
      case abierto:
        return 'Abierto';
      case enRevision:
        return 'En revisión';
      case cerrado:
        return 'Cerrado';
      default:
        return status;
    }
  }

  static bool isOpen(String status) =>
      openStatuses.contains(status.trim());
}

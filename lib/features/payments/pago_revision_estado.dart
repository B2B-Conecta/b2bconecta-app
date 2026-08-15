/// Estado de revisión del comprobante (`transaction_requests.pago_estado_revision`).
abstract final class PagoRevisionEstado {
  static const pendiente = 'pendiente';
  static const enRevision = 'en_revision';
  static const aprobado = 'aprobado';
  static const rechazado = 'rechazado';
}

import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';

/// Fase del flujo factura proveedor → pago aliado, por bloque importador.
enum AliadoImportadorPagoFase {
  enCurso,
  esperandoFacturaProveedor,
  pendientePago,
  comprobanteEnRevision,
  pagoConfirmado,
  cerradoSinPago,
}

AliadoImportadorPagoFase fasePagoBloqueImportador(
  List<TransactionRequestModel> chunk,
) {
  if (chunk.isEmpty) return AliadoImportadorPagoFase.cerradoSinPago;

  final activo = chunk.any(
    (r) =>
        r.status != TransactionRequestStatus.rechazado &&
        !r.canceladoPorAliado &&
        !r.anuladoPorMotolink,
  );
  if (!activo) return AliadoImportadorPagoFase.cerradoSinPago;

  if (chunk.every(
    (r) => r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado,
  )) {
    return AliadoImportadorPagoFase.pagoConfirmado;
  }

  final puedePagar = chunk.any(
    (r) => TransactionRequestStatus.aliadoDeclaracionPagoMultietapa
        .contains(r.status),
  );
  if (!puedePagar) return AliadoImportadorPagoFase.enCurso;

  final tieneFacturaProveedor = chunk.any((r) => r.hasProveedorFactura);

  if (!tieneFacturaProveedor) {
    return AliadoImportadorPagoFase.esperandoFacturaProveedor;
  }

  final enRevision = chunk.any(
    (r) =>
        r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.enRevision ||
        (r.hasComprobantePago &&
            r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.pendiente),
  );
  if (enRevision) return AliadoImportadorPagoFase.comprobanteEnRevision;

  return AliadoImportadorPagoFase.pendientePago;
}

bool bloqueImportadorPagoConfirmado(List<TransactionRequestModel> chunk) =>
    fasePagoBloqueImportador(chunk) == AliadoImportadorPagoFase.pagoConfirmado;

String fasePagoBloqueLabelEs(AliadoImportadorPagoFase fase) {
  switch (fase) {
    case AliadoImportadorPagoFase.esperandoFacturaProveedor:
      return 'Esperando factura del proveedor';
    case AliadoImportadorPagoFase.pendientePago:
      return 'Tu pago pendiente';
    case AliadoImportadorPagoFase.comprobanteEnRevision:
      return 'Comprobante en revisión';
    case AliadoImportadorPagoFase.pagoConfirmado:
      return 'Pago confirmado';
    case AliadoImportadorPagoFase.enCurso:
      return 'En preparación / envío';
    case AliadoImportadorPagoFase.cerradoSinPago:
      return '—';
  }
}

double subtotalBloqueImportador(List<TransactionRequestModel> chunk) =>
    chunk.fold<double>(0, (s, r) => s + r.precioTotal);

/// Subtotal REF base (sin descuento divisas) para la pasarela de pago.
double refSubtotalBloqueImportador(List<TransactionRequestModel> chunk) =>
    chunk.fold<double>(0, (s, r) => s + r.refBaseTotalForPago);

/// Cuántos importadores del carrito ya tienen el pago confirmado por el importador.
int importadoresConPagoConfirmado(
  List<List<TransactionRequestModel>> porImportador,
) =>
    porImportador.where(bloqueImportadorPagoConfirmado).length;

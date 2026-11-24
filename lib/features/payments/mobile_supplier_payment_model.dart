import '../orders/shared/transaction_request_model.dart';
import '../orders/shared/order_payment_pricing.dart';
import '../orders/shared/transaction_request_status.dart';
import 'pago_metodo.dart';
import 'pago_revision_estado.dart';

/// One declaration covers one supplier, never the entire mixed-currency cart.
class SupplierPaymentDeclaration {
  const SupplierPaymentDeclaration(
      {required this.submissionId,
      required this.method,
      required this.reference,
      required this.paidOn,
      required this.amount,
      required this.currency,
      this.previousSubmissionId = '',
      this.note = ''});
  final String submissionId,
      method,
      reference,
      currency,
      note,
      previousSubmissionId;
  final DateTime paidOn;
  final double amount;
  Map<String, dynamic> toJson() => {
        'submission_id': submissionId,
        'previous_submission_id': previousSubmissionId,
        'reference': reference.trim(),
        'paid_on':
            '${paidOn.year.toString().padLeft(4, '0')}-${paidOn.month.toString().padLeft(2, '0')}-${paidOn.day.toString().padLeft(2, '0')}',
        'amount': amount,
        'currency': currency,
        'note': note.trim(),
      };
}

class MobileSupplierPaymentQuote {
  MobileSupplierPaymentQuote(this.lines, this.method);
  final List<TransactionRequestModel> lines;
  final String? method;
  bool get bolivares =>
      lines.first.metodoPagoMoneda == 'BOLIVARES' ||
      (lines.first.metodoPagoMoneda != 'DIVISAS' &&
          PagoMetodo.isBolivares(method));
  String get currency => bolivares ? 'BS' : 'USD';
  double get productTotal =>
      OrderPaymentPricing.previewForLines(lines: lines, pagoMetodo: method)
          .total;
  double? get rate =>
      lines.first.tasaBcvAplicada ?? lines.first.tasaBcvSnapshot;
  double? get payable {
    if (!bolivares) return productTotal;
    if (lines.every(
        (l) => l.hasCheckoutPriceSnapshot && l.precioTotalBsUi != null)) {
      return lines.fold<double>(0, (sum, l) => sum + l.precioTotalBsUi!);
    }
    if (lines.every((l) => (l.tasaBcvAplicada ?? l.tasaBcvSnapshot ?? 0) > 0)) {
      return lines.fold<double>(
          0,
          (sum, l) =>
              sum +
              OrderPaymentPricing.previewForRequest(
                          request: l, pagoMetodo: method)
                      .total *
                  (l.tasaBcvAplicada ?? l.tasaBcvSnapshot!));
    }
    return null;
  }

  List<String> get methods => lines.first.metodosPagoPermitidos
      .where((method) =>
          lines.every((l) => l.metodosPagoPermitidos.contains(method)) &&
          (lines.first.metodoPagoMoneda == null ||
              (lines.first.metodoPagoMoneda == 'DIVISAS'
                  ? !PagoMetodo.isBolivares(method)
                  : PagoMetodo.isBolivares(method))))
      .toList();
}

bool supplierPaymentEditable(List<TransactionRequestModel> lines) =>
    lines.isNotEmpty &&
    lines.any((l) => l.hasProveedorFactura) &&
    lines.every((l) =>
        TransactionRequestStatus.aliadoDeclaracionPagoMultietapa
            .contains(l.status) &&
        !l.canceladoPorAliado &&
        !l.canceladoPorImportador &&
        !l.anuladoPorMotolink &&
        l.pagoEstadoRevisionEfectivo != PagoRevisionEstado.aprobado);

String supplierPaymentStatus(List<TransactionRequestModel> lines) {
  if (lines.every(
      (l) => l.pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado)) {
    return 'Pago confirmado';
  }
  if (lines.any(
      (l) => l.pagoEstadoRevisionEfectivo == PagoRevisionEstado.rechazado)) {
    return 'Comprobante rechazado';
  }
  if (lines.any((l) =>
      l.pagoEstadoRevisionEfectivo == PagoRevisionEstado.enRevision ||
      l.hasComprobantePago)) return 'Pendiente de revisión';
  return lines.any((l) => l.hasProveedorFactura)
      ? 'Pendiente de pago'
      : 'Esperando factura';
}

/// Accept decimal comma/dot and a single conventional thousands format.
double? parseDeclaredPaymentAmount(String text) {
  var value = text.trim().replaceAll(' ', '');
  if (value.contains(',') && value.contains('.')) {
    if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
      if (!RegExp(r'^\d{1,3}(\.\d{3})*,\d{1,2}$').hasMatch(value)) return null;
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      if (!RegExp(r'^\d{1,3}(,\d{3})*\.\d{1,2}$').hasMatch(value)) return null;
      value = value.replaceAll(',', '');
    }
  } else {
    value = value.replaceAll(',', '.');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final result = double.tryParse(value);
  return result != null && result.isFinite && result > 0 && result <= 1e12
      ? result
      : null;
}

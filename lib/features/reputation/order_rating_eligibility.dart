import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

bool pedidoCanceladoParaValoracion(TransactionRequestModel r) {
  if (r.status != TransactionRequestStatus.rechazado) return false;
  if (r.canceladoPorAliado || r.canceladoPorImportador) return true;
  final motivoAliado = r.aliadoCancelacionMotivo?.trim() ?? '';
  final motivoImportador = r.importadorCancelacionMotivo?.trim() ?? '';
  return motivoAliado.isNotEmpty || motivoImportador.isNotEmpty;
}

/// Aliado puede valorar importador tras entrega o cancelación del pedido.
bool lineaElegibleValoracionAliado(TransactionRequestModel r) {
  if (r.anuladoPorMotolink) return false;
  if (r.status == TransactionRequestStatus.entregado &&
      !r.canceladoPorAliado) {
    return true;
  }
  return pedidoCanceladoParaValoracion(r);
}

/// Importador puede valorar aliado tras entrega o cancelación.
bool lineaElegibleValoracionImportador(TransactionRequestModel r) {
  if (r.status == TransactionRequestStatus.entregado) return true;
  return pedidoCanceladoParaValoracion(r);
}

String orderRatingCommentWithCancellationReason(
  String motivo, {
  String? additional,
}) {
  final m = motivo.trim();
  final base = m.isEmpty ? '' : 'Motivo de cancelación: $m';
  final extra = additional?.trim() ?? '';
  if (base.isEmpty) return extra;
  if (extra.isEmpty) return base;
  return '$base\n\n$extra';
}

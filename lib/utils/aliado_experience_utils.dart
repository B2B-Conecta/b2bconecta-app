import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';

/// Valoración del aliado ya guardada en servidor.
bool aliadoTieneValoracionRegistrada(TransactionRequestModel r) =>
    r.aliadoExperienceSubmittedAt != null;

/// Líneas entregadas que aún pueden / deben valorarse.
Iterable<TransactionRequestModel> lineasEntregadasParaValorar(
  Iterable<TransactionRequestModel> lines,
) {
  return lines.where(
    (r) =>
        r.status == TransactionRequestStatus.entregado &&
        !r.canceladoPorAliado &&
        !r.anuladoPorMotolink,
  );
}

bool aliadoGrupoPendienteValoracion(List<TransactionRequestModel> lines) {
  return lineasEntregadasParaValorar(lines)
      .any((r) => !aliadoTieneValoracionRegistrada(r));
}

/// Primera línea del grupo con valoración (p. ej. tras RPC por importador).
TransactionRequestModel? primeraLineaConValoracion(
  List<TransactionRequestModel> lines,
) {
  for (final r in lines) {
    if (aliadoTieneValoracionRegistrada(r)) return r;
  }
  return null;
}

String aliadoValoracionResumenCortoEs(TransactionRequestModel r) {
  if (!aliadoTieneValoracionRegistrada(r)) {
    return 'Valoración pendiente';
  }
  final stars = r.aliadoExperienceStars ?? 0;
  return 'Valorado · $stars/5';
}

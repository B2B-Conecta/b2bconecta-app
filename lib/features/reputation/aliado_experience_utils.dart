import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'order_rating_eligibility.dart';

/// Valoración del aliado ya guardada en servidor.
bool aliadoTieneValoracionRegistrada(TransactionRequestModel r) =>
    r.aliadoExperienceSubmittedAt != null;

/// Líneas que el aliado puede valorar (entregadas o canceladas).
Iterable<TransactionRequestModel> lineasEntregadasParaValorar(
  Iterable<TransactionRequestModel> lines,
) {
  return lines.where(lineaElegibleValoracionAliado);
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

/// Líneas del grupo (o una sola) pendientes de valorar por el aliado.
List<TransactionRequestModel> aliadoLineasPendientesValoracion(
  List<TransactionRequestModel> lines, {
  String? importadorId,
}) {
  final entregadas = lineasEntregadasParaValorar(lines).toList();
  if (importadorId != null && importadorId.trim().isNotEmpty) {
    return entregadas
        .where((r) => r.ownerId == importadorId.trim())
        .where((r) => !aliadoTieneValoracionRegistrada(r))
        .toList();
  }
  return entregadas
      .where((r) => !aliadoTieneValoracionRegistrada(r))
      .toList();
}

bool aliadoGrupoTieneValoracionPendiente(
  List<TransactionRequestModel> lines, {
  String? importadorId,
}) =>
    aliadoLineasPendientesValoracion(lines, importadorId: importadorId)
        .isNotEmpty;

/// Primera línea con la que abrir el sheet (pendiente o ya valorada).
TransactionRequestModel aliadoLineaReferenciaValoracion(
  List<TransactionRequestModel> lines, {
  String? importadorId,
}) {
  final pendientes =
      aliadoLineasPendientesValoracion(lines, importadorId: importadorId);
  if (pendientes.isNotEmpty) return pendientes.first;
  final entregadas = lineasEntregadasParaValorar(lines);
  if (importadorId != null && importadorId.trim().isNotEmpty) {
    return entregadas.firstWhere(
      (r) => r.ownerId == importadorId.trim(),
      orElse: () => lines.first,
    );
  }
  return primeraLineaConValoracion(lines) ??
      entregadas.firstOrNull ??
      lines.first;
}

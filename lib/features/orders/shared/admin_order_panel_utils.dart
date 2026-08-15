import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'aliado_order_grouping.dart';

/// Agrupa filas del mismo carrito (`checkout_group_id`) para listas admin.
List<List<TransactionRequestModel>> groupAdminOrdersForDisplay(
  List<TransactionRequestModel> flat,
) =>
    groupAliadoOrdersByCheckout(flat);

String adminCheckoutGroupTitle(List<TransactionRequestModel> lines) {
  if (lines.isEmpty) return 'Pedido';
  if (lines.length == 1) {
    return lines.single.tituloFichaPrincipalPedido;
  }
  final importers = lines
      .map((e) => e.ownerId.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final base = tituloCheckoutGrupoAliado(lines);
  if (importers.length > 1) {
    return '$base · ${importers.length} importadores';
  }
  return base;
}

String adminCheckoutGroupStatusLabel(List<TransactionRequestModel> lines) {
  if (lines.isEmpty) return '';
  final st0 = lines.first.status;
  if (lines.every((r) => r.status == st0)) {
    return TransactionRequestStatus.labelEs(st0);
  }
  return 'Varios estados';
}

bool adminCheckoutGroupEsMoroso(List<TransactionRequestModel> lines) =>
    lines.any((r) => r.esPedidoMoroso);

double adminCheckoutGroupTotalRef(List<TransactionRequestModel> lines) =>
    lines.fold<double>(0, (s, r) => s + r.precioTotal);

int adminCheckoutGroupTotalUds(List<TransactionRequestModel> lines) =>
    lines.fold<int>(0, (s, r) => s + r.totalUnidadesAliado);

String adminCheckoutGroupResumenLinea(List<TransactionRequestModel> lines) {
  final uds = adminCheckoutGroupTotalUds(lines);
  final ref = adminCheckoutGroupTotalRef(lines);
  if (lines.length == 1) {
    return '$uds uds · Total (aliado) ${ref.toStringAsFixed(2)} REF';
  }
  final importers = lines
      .map((e) => e.ownerId.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  return '$uds uds · ${lines.length} líneas · '
      '${importers.length} importador(es) · '
      '${ref.toStringAsFixed(2)} REF total';
}

/// Primera línea morosa del grupo (para banner / acciones).
TransactionRequestModel adminCheckoutGroupMorosoRef(
  List<TransactionRequestModel> lines,
) {
  return lines.firstWhere(
    (r) => r.esPedidoMoroso,
    orElse: () => lines.first,
  );
}

String adminLineStatusChipLabel(TransactionRequestModel r) =>
    TransactionRequestStatus.labelEs(r.status);

import 'package:motolink_pro_app/features/orders/shared/order_chat_access.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';

/// Filtro de la bandeja de hilos de pedido.
enum OrderChatInboxFilter {
  all,
  active,
  closed,
  unread,
}

/// Un hilo de chat = líneas de un mismo carrito con el mismo importador.
class OrderChatThread {
  const OrderChatThread({
    required this.primaryRequestId,
    required this.requestIds,
    required this.title,
    required this.counterpartName,
    required this.status,
    required this.statusLabel,
    required this.canReply,
    this.inDeliveryGrace = false,
    this.updatedAt,
    this.productSku,
    this.aliadoName,
    this.importerName,
  });

  final String primaryRequestId;
  final List<String> requestIds;
  final String title;
  final String counterpartName;
  final String status;
  final String statusLabel;
  final bool canReply;

  /// Pedido recibido y todavía dentro de los 7 días de observaciones.
  final bool inDeliveryGrace;
  final DateTime? updatedAt;
  final String? productSku;
  final String? aliadoName;
  final String? importerName;

  String get searchBlob {
    final parts = <String>[
      title,
      counterpartName,
      statusLabel,
      status,
      if (productSku != null) productSku!,
      if (aliadoName != null) aliadoName!,
      if (importerName != null) importerName!,
    ];
    return parts.join(' ').toLowerCase();
  }
}

List<OrderChatThread> orderChatThreadsFromOrders(
  List<TransactionRequestModel> orders, {
  required AppHomeRole role,
}) {
  if (orders.isEmpty) return const [];
  final out = <OrderChatThread>[];
  for (final cart in groupAliadoOrdersByCheckout(orders)) {
    final chunks = groupCheckoutLinesByImportador(cart);
    final groups = chunks.isEmpty ? <List<TransactionRequestModel>>[cart] : chunks;
    for (final lines in groups) {
      if (lines.isEmpty) continue;
      out.add(_threadFromLines(lines, role: role));
    }
  }
  return out;
}

OrderChatThread _threadFromLines(
  List<TransactionRequestModel> lines, {
  required AppHomeRole role,
}) {
  final primary = lines.first;
  final names = lines
      .map((l) => l.productName?.trim())
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toList();
  final title = names.isEmpty
      ? 'Pedido'
      : names.toSet().length == 1
          ? names.first
          : '${lines.length} productos';

  final importer = (primary.ownerBusinessName ?? '').trim();
  final aliado = (primary.aliadoBusinessName ?? '').trim();
  final counterpart = switch (role) {
    AppHomeRole.aliado => importer.isNotEmpty ? importer : 'Mayorista',
    AppHomeRole.importador => aliado.isNotEmpty ? aliado : 'Tienda minorista',
      AppHomeRole.administrador => () {
        final joined = [
          if (aliado.isNotEmpty) aliado,
          if (importer.isNotEmpty) importer,
        ].join(' · ');
        return joined.isEmpty ? 'Pedido' : joined;
      }(),
  };

  final statuses = lines.map((l) => l.status).toSet();
  final status = statuses.length == 1 ? statuses.first : primary.status;
  final statusLabel = statuses.length == 1
      ? TransactionRequestStatus.labelEs(status)
      : 'Varios estados';

  DateTime? latest;
  for (final l in lines) {
    final t = l.updatedAt ?? l.createdAt;
    if (t == null) continue;
    if (latest == null || t.isAfter(latest)) latest = t;
  }

  final sku = lines
      .map((l) => l.productSku?.trim())
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ');

  return OrderChatThread(
    primaryRequestId: primary.id,
    requestIds: lines.map((l) => l.id).toList(growable: false),
    title: title,
    counterpartName: counterpart,
    status: status,
    statusLabel: statusLabel,
    canReply: orderLinesAllowChatReply(lines),
    inDeliveryGrace: orderLinesChatDeliveryGrace(lines),
    updatedAt: latest,
    productSku: sku.isEmpty ? null : sku,
    aliadoName: aliado.isEmpty ? null : aliado,
    importerName: importer.isEmpty ? null : importer,
  );
}

List<OrderChatThread> filterOrderChatThreads({
  required List<OrderChatThread> threads,
  required String query,
  required OrderChatInboxFilter filter,
  required int Function(List<String> ids) unreadFor,
}) {
  final q = query.trim().toLowerCase();
  var out = threads.where((t) {
    if (q.isNotEmpty && !t.searchBlob.contains(q)) return false;
    switch (filter) {
      case OrderChatInboxFilter.all:
        return true;
      case OrderChatInboxFilter.active:
        return t.canReply;
      case OrderChatInboxFilter.closed:
        return !t.canReply;
      case OrderChatInboxFilter.unread:
        return unreadFor(t.requestIds) > 0;
    }
  }).toList();

  out.sort((a, b) {
    final ua = unreadFor(a.requestIds);
    final ub = unreadFor(b.requestIds);
    if (ua > 0 && ub == 0) return -1;
    if (ua == 0 && ub > 0) return 1;
    final ta = a.updatedAt;
    final tb = b.updatedAt;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });
  return out;
}

Future<List<TransactionRequestModel>> fetchOrdersForChatInbox(
  AppHomeRole role,
) {
  switch (role) {
    case AppHomeRole.aliado:
      return SupabaseService.fetchMyPedidosActivosYCerradosForAliado();
    case AppHomeRole.importador:
      return SupabaseService.fetchUnifiedTransactionRequestsForImporter();
    case AppHomeRole.administrador:
      return SupabaseService.fetchUnifiedTransactionRequestsForAdmin();
  }
}

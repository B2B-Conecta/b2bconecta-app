import 'package:flutter/material.dart';
import '../../../core/data/supabase_service.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/notifications/notification_related_order_match.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_access.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_thread.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_widget.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_entry.dart';
import 'package:motolink_pro_app/features/orders/shared/order_motolink_thread_section.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'mobile_chat_widgets.dart';
import 'mobile_order_action_widgets.dart';

export 'package:motolink_pro_app/features/orders/shared/order_chat_access.dart';
export 'package:motolink_pro_app/features/orders/shared/order_chat_widget.dart'
    show OrderChatWidget, OrderFloatingChat;

/// Flags de respuesta del hilo, alineados a Pedidos.
({bool aliado, bool admin, bool importador}) orderChatInboxReplyFlags({
  required AppHomeRole role,
  required OrderChatThread thread,
}) {
  return (
    aliado: role == AppHomeRole.aliado && thread.canReply,
    admin: role == AppHomeRole.administrador,
    importador: role == AppHomeRole.importador && thread.canReply,
  );
}

String orderChatTitleForLines(
  List<TransactionRequestModel> lines, {
  String? counterpart,
  AppHomeRole viewerRole = AppHomeRole.administrador,
}) {
  if (lines.isNotEmpty) {
    final ref = OrderListEntry(lines, viewerRole: viewerRole).reference;
    return 'Chat Pedido $ref';
  }
  final name = counterpart?.trim();
  if (name != null && name.isNotEmpty) return 'Chat · $name';
  return 'Chat del pedido';
}

bool _preferFloatingChat(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
}

/// Abre el hilo existente desde la bandeja, con los mismos permisos que Pedidos.
void openOrderChatFromInbox({
  required BuildContext context,
  required AppHomeRole role,
  required OrderChatThread thread,
  VoidCallback? onThreadChanged,
}) {
  final ids = thread.requestIds;
  final merged = ids.length > 1 ? ids : null;
  final title = orderChatTitleForLines(
    thread.lines,
    counterpart: thread.counterpartName,
    viewerRole: role,
  );
  final flags = orderChatInboxReplyFlags(role: role, thread: thread);
  showOrderChatSheet(
    context: context,
    transactionRequestId: thread.primaryRequestId,
    mergedThreadRequestIds: merged,
    orderLines: thread.lines,
    allowReplyAsAliado: flags.aliado,
    allowReplyAsAdmin: flags.admin,
    allowReplyAsImportador: flags.importador,
    deliveryGrace: thread.inDeliveryGrace,
    title: title,
    onThreadChanged: onThreadChanged,
  );
}

Future<void> showOrderChatSheet({
  required BuildContext context,
  required String transactionRequestId,
  List<String>? mergedThreadRequestIds,
  List<TransactionRequestModel> orderLines = const [],
  List<List<TransactionRequestModel>>? supplierThreads,
  int initialSupplierIndex = 0,
  required bool allowReplyAsAliado,
  required bool allowReplyAsAdmin,
  bool allowReplyAsImportador = false,
  bool deliveryGrace = false,
  String title = 'Chat del pedido',
  VoidCallback? onThreadChanged,
}) {
  final resolvedTitle =
      orderLines.isNotEmpty ? orderChatTitleForLines(orderLines) : title;

  if (_preferFloatingChat(context)) {
    return OrderFloatingChat.show(
      context: context,
      transactionRequestId: transactionRequestId,
      mergedThreadRequestIds: mergedThreadRequestIds,
      orderLines: orderLines,
      supplierThreads: supplierThreads ?? const [],
      initialSupplierIndex: initialSupplierIndex,
      allowReplyAsAliado: allowReplyAsAliado,
      allowReplyAsAdmin: allowReplyAsAdmin,
      allowReplyAsImportador: allowReplyAsImportador,
      deliveryGrace: deliveryGrace,
      title: resolvedTitle,
      onThreadChanged: onThreadChanged,
    );
  }

  final viewerRole = allowReplyAsAliado
      ? AppHomeRole.aliado
      : allowReplyAsImportador
          ? AppHomeRole.importador
          : allowReplyAsAdmin
              ? AppHomeRole.administrador
              : (SupabaseService.currentUserId ==
                      orderLines.firstOrNull?.aliadoId
                  ? AppHomeRole.aliado
                  : AppHomeRole.importador);
  final thread =
      orderChatThreadsFromOrders(orderLines, role: viewerRole).firstOrNull;
  return Navigator.of(context)
      .push<void>(MaterialPageRoute(
          builder: (routeContext) => OrderMotolinkThreadSection(
                mobileAppBarBuilder: (actions) => MobileChatAppBar(
                    title: thread?.counterpartName ?? title,
                    subtitle: orderLines
                            .any((line) => line.postventaDevolucionAt != null)
                        ? 'Posventa · ${mobileOrderReference(orderLines)}'
                        : 'Chat del pedido',
                    showAvatar: thread != null,
                    logoPath: viewerRole == AppHomeRole.aliado
                        ? orderLines.firstOrNull?.ownerLogoStoragePath
                        : orderLines.firstOrNull?.aliadoLogoStoragePath,
                    actions: actions),
                transactionRequestId: transactionRequestId,
                mergedThreadRequestIds: mergedThreadRequestIds,
                orderLines: orderLines,
                allowReplyAsAliado: allowReplyAsAliado,
                allowReplyAsAdmin: allowReplyAsAdmin,
                allowReplyAsImportador: allowReplyAsImportador,
                deliveryGrace: deliveryGrace,
                onThreadChanged: onThreadChanged,
                suppressBuiltinTitle: true,
                expandMessages: true,
                conversationContext: thread == null
                    ? null
                    : MobileOrderChatCard(
                        thread: thread,
                        onOpenOrder: () => Navigator.pop(routeContext)),
              )))
      .whenComplete(() {
    NotificationProvider.active?.reload();
  });
}

/// Abre el chat del pedido que coincide con el `related_id` de una notificación.
void openOrderChatForNotification({
  required BuildContext context,
  required List<TransactionRequestModel> rows,
  required String relatedId,
  required bool asAliado,
  VoidCallback? onThreadChanged,
}) {
  final line = findTransactionForNotificationRelatedId(rows, relatedId);
  if (line == null) return;
  List<TransactionRequestModel>? chunk;
  for (final cart in groupAliadoOrdersByCheckout(rows)) {
    if (!cart.any((row) => row.id == line.id)) continue;
    final chunks = groupCheckoutLinesByImportador(cart);
    final groups =
        chunks.isEmpty ? <List<TransactionRequestModel>>[cart] : chunks;
    for (final group in groups) {
      if (group.any((row) => row.id == line.id)) {
        chunk = group;
        break;
      }
    }
  }
  final lines = chunk ?? <TransactionRequestModel>[line];
  final counterpart = asAliado
      ? lines.first.ownerBusinessName?.trim()
      : lines.first.aliadoBusinessName?.trim();
  showOrderChatSheet(
    context: context,
    transactionRequestId: lines.first.id,
    mergedThreadRequestIds:
        lines.length > 1 ? lines.map((row) => row.id).toList() : null,
    orderLines: lines,
    allowReplyAsAliado: asAliado && orderLinesAllowChatReply(lines),
    allowReplyAsAdmin: false,
    allowReplyAsImportador: !asAliado && orderLinesAllowChatReply(lines),
    deliveryGrace: orderLinesChatDeliveryGrace(lines),
    title: orderChatTitleForLines(
      lines,
      counterpart: counterpart,
      viewerRole: asAliado ? AppHomeRole.aliado : AppHomeRole.importador,
    ),
    onThreadChanged: onThreadChanged,
  );
}

/// Icono de chat en la ficha cerrada; no expande el pedido.
class OrderChatIconButton extends StatelessWidget {
  const OrderChatIconButton({
    super.key,
    required this.relatedOrderIds,
    required this.onOpen,
    this.showLabel = false,
  });

  final List<String> relatedOrderIds;
  final VoidCallback onOpen;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.active;
    final listenable = provider ?? _silent;
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final unread = provider?.unreadMensajeCountFor(relatedOrderIds) ?? 0;
        final theme = B2BThemeExtension.of(context);
        if (showLabel) {
          return OutlinedButton.icon(
            onPressed: onOpen,
            icon: LucideIcon(
              LucideGlyph.messageSquare,
              size: 16,
              color: theme.brand,
            ),
            label: Text(unread > 0 ? 'Chat ($unread)' : 'Chat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.brand,
              minimumSize: const Size(0, 38),
              side: BorderSide(color: theme.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return IconButton(
          tooltip: unread > 0
              ? 'Mensajes del pedido ($unread sin leer)'
              : 'Mensajes del pedido',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          visualDensity: VisualDensity.standard,
          onPressed: onOpen,
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: Theme.of(context).colorScheme.error,
            label: Text(
              unread > 9 ? '9+' : '$unread',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.surfaceCard,
              ),
            ),
            child: LucideIcon(
              LucideGlyph.messageSquare,
              color: unread > 0 ? theme.brand : theme.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

/// CTA compacto en la sección Mensajes (no ocupa todo el ancho).
class OrderOpenChatButton extends StatelessWidget {
  const OrderOpenChatButton({
    super.key,
    required this.relatedOrderIds,
    required this.onPressed,
    this.label,
  });

  final List<String> relatedOrderIds;
  final VoidCallback onPressed;

  /// Si viene vacío, el botón conserva el texto «Abrir chat».
  final String? label;

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.active;
    final listenable = provider ?? _silent;
    final theme = B2BThemeExtension.of(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final unread = provider?.unreadMensajeCountFor(relatedOrderIds) ?? 0;
        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Theme.of(context).colorScheme.error,
              label: Text(
                unread > 9 ? '9+' : '$unread',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: theme.surfaceCard,
                ),
              ),
              child: LucideIcon(
                LucideGlyph.messageSquare,
                size: 16,
                color: theme.brand,
              ),
            ),
            label: Text(
              label ??
                  (unread > 0 ? 'Abrir chat ($unread)' : 'Abrir chat'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: theme.brand,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.brandContainer,
              foregroundColor: theme.brand,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}

final ChangeNotifier _silent = ChangeNotifier();

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/features/orders/shared/order_motolink_thread_section.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

/// Pedido aún negociable en el hilo (ni entregado ni rechazado).
bool orderChatReplyOpen(String status) {
  return status != TransactionRequestStatus.entregado &&
      status != TransactionRequestStatus.rechazado;
}

Future<void> showOrderChatSheet({
  required BuildContext context,
  required String transactionRequestId,
  List<String>? mergedThreadRequestIds,
  required bool allowReplyAsAliado,
  required bool allowReplyAsAdmin,
  bool allowReplyAsImportador = false,
  String title = 'Chat del pedido',
  VoidCallback? onThreadChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.82;
      return SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.brand, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: OrderMotolinkThreadSection(
                    key: ValueKey<String>(
                      'sheet-${mergedThreadRequestIds?.join('-') ?? transactionRequestId}',
                    ),
                    transactionRequestId: transactionRequestId,
                    mergedThreadRequestIds: mergedThreadRequestIds,
                    allowReplyAsAliado: allowReplyAsAliado,
                    allowReplyAsAdmin: allowReplyAsAdmin,
                    allowReplyAsImportador: allowReplyAsImportador,
                    onThreadChanged: onThreadChanged,
                    suppressBuiltinTitle: true,
                    suppressInlineHelp: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(() {
    NotificationProvider.active?.reload();
  });
}

/// Icono de chat en la ficha cerrada; no expande el pedido.
class OrderChatIconButton extends StatelessWidget {
  const OrderChatIconButton({
    super.key,
    required this.relatedOrderIds,
    required this.onOpen,
  });

  final List<String> relatedOrderIds;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.active;
    final listenable = provider ?? _silent;
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final unread = provider?.unreadMensajeCountFor(relatedOrderIds) ?? 0;
        return IconButton(
          tooltip: unread > 0 ? 'Chat ($unread sin leer)' : 'Chat del pedido',
          visualDensity: VisualDensity.compact,
          onPressed: onOpen,
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.brand,
            label: Text(
              unread > 9 ? '9+' : '$unread',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            child: Icon(
              unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: unread > 0 ? AppColors.brand : AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}

/// CTA en la sección Mensajes de la ficha: abre el chat en una vista nueva.
class OrderOpenChatButton extends StatelessWidget {
  const OrderOpenChatButton({
    super.key,
    required this.relatedOrderIds,
    required this.onPressed,
  });

  final List<String> relatedOrderIds;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.active;
    final listenable = provider ?? _silent;
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final unread = provider?.unreadMensajeCountFor(relatedOrderIds) ?? 0;
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(
              unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: 18,
            ),
            label: Text(
              unread > 0 ? 'Ver chat ($unread sin leer)' : 'Ver chat',
            ),
          ),
        );
      },
    );
  }
}

final ChangeNotifier _silent = ChangeNotifier();

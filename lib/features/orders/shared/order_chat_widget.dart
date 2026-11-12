import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_entry.dart';
import 'package:motolink_pro_app/features/orders/shared/order_motolink_thread_section.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

/// Host de overlay del chat flotante (escritorio / web).
class OrderFloatingChat {
  OrderFloatingChat._();

  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isOpen => _entry != null;

  static Future<void> show({
    required BuildContext context,
    required String transactionRequestId,
    List<String>? mergedThreadRequestIds,
    List<TransactionRequestModel> orderLines = const [],
    required bool allowReplyAsAliado,
    required bool allowReplyAsAdmin,
    bool allowReplyAsImportador = false,
    bool deliveryGrace = false,
    String? title,
    VoidCallback? onThreadChanged,
    bool startMinimized = false,
  }) {
    close();
    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<void>();
    _completer = completer;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => OrderChatWidget(
        transactionRequestId: transactionRequestId,
        mergedThreadRequestIds: mergedThreadRequestIds,
        orderLines: orderLines,
        allowReplyAsAliado: allowReplyAsAliado,
        allowReplyAsAdmin: allowReplyAsAdmin,
        allowReplyAsImportador: allowReplyAsImportador,
        deliveryGrace: deliveryGrace,
        title: title,
        onThreadChanged: onThreadChanged,
        initiallyMinimized: startMinimized,
        onDismiss: () {
          entry.remove();
          if (_entry == entry) _entry = null;
          if (!completer.isCompleted) completer.complete();
          NotificationProvider.active?.reload();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    return completer.future;
  }

  static void close() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    final c = _completer;
    _completer = null;
    if (c != null && !c.isCompleted) c.complete();
  }
}

/// Widget flotante minimizable del chat de pedido (`OrderChatWidget`).
class OrderChatWidget extends StatefulWidget {
  const OrderChatWidget({
    super.key,
    required this.transactionRequestId,
    required this.allowReplyAsAliado,
    required this.allowReplyAsAdmin,
    required this.onDismiss,
    this.mergedThreadRequestIds,
    this.orderLines = const [],
    this.allowReplyAsImportador = false,
    this.deliveryGrace = false,
    this.title,
    this.onThreadChanged,
    this.initiallyMinimized = false,
  });

  final String transactionRequestId;
  final List<String>? mergedThreadRequestIds;
  final List<TransactionRequestModel> orderLines;
  final bool allowReplyAsAliado;
  final bool allowReplyAsAdmin;
  final bool allowReplyAsImportador;
  final bool deliveryGrace;
  final String? title;
  final VoidCallback? onThreadChanged;
  final VoidCallback onDismiss;
  final bool initiallyMinimized;

  @override
  State<OrderChatWidget> createState() => _OrderChatWidgetState();
}

class _OrderChatWidgetState extends State<OrderChatWidget> {
  late bool _minimized;

  @override
  void initState() {
    super.initState();
    _minimized = widget.initiallyMinimized;
  }

  String get _title {
    final custom = widget.title?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    if (widget.orderLines.isEmpty) return 'Chat del pedido';
    final ref = OrderListEntry(
      widget.orderLines,
      viewerRole: AppHomeRole.administrador,
    ).reference;
    return 'Chat Pedido $ref';
  }

  String get _subtitle {
    final lines = widget.orderLines;
    if (lines.isEmpty) {
      return 'Taller · Importador · B2B Conecta';
    }
    final retail = lines.first.aliadoBusinessName?.trim();
    final importer = lines.first.ownerBusinessName?.trim();
    final parts = <String>[
      if (retail != null && retail.isNotEmpty) retail else 'Taller minorista',
      if (importer != null && importer.isNotEmpty) importer else 'Importador',
      'B2B Conecta',
    ];
    return parts.join(' · ');
  }

  List<String> get _relatedIds {
    final merged = widget.mergedThreadRequestIds;
    if (merged != null && merged.isNotEmpty) return merged;
    if (widget.orderLines.isNotEmpty) {
      return widget.orderLines.map((e) => e.id).toList();
    }
    return [widget.transactionRequestId];
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          // Sin barrier: el detalle del pedido sigue interactivo.
          Positioned(
            right: 24,
            bottom: 24 + bottomPad,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _minimized
                  ? _Fab(
                      key: const ValueKey('fab'),
                      relatedOrderIds: _relatedIds,
                      onOpen: () => setState(() => _minimized = false),
                    )
                  : _Panel(
                      key: const ValueKey('panel'),
                      theme: theme,
                      title: _title,
                      subtitle: _subtitle,
                      relatedOrderIds: _relatedIds,
                      onMinimize: () => setState(() => _minimized = true),
                      onClose: widget.onDismiss,
                      child: OrderMotolinkThreadSection(
                        key: ValueKey<String>(
                          'float-${widget.mergedThreadRequestIds?.join('-') ?? widget.transactionRequestId}',
                        ),
                        transactionRequestId: widget.transactionRequestId,
                        mergedThreadRequestIds: widget.mergedThreadRequestIds,
                        orderLines: widget.orderLines,
                        allowReplyAsAliado: widget.allowReplyAsAliado,
                        allowReplyAsAdmin: widget.allowReplyAsAdmin,
                        allowReplyAsImportador: widget.allowReplyAsImportador,
                        deliveryGrace: widget.deliveryGrace,
                        onThreadChanged: widget.onThreadChanged,
                        suppressBuiltinTitle: true,
                        suppressInlineHelp: true,
                        expandMessages: true,
                        emptyHint:
                            '¿Tienes una duda sobre este pedido? Escribe aquí para iniciar la conversación',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({
    super.key,
    required this.relatedOrderIds,
    required this.onOpen,
  });

  final List<String> relatedOrderIds;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final provider = NotificationProvider.active;
    return ListenableBuilder(
      listenable: provider ?? _silent,
      builder: (context, _) {
        final unread = provider?.unreadMensajeCountFor(relatedOrderIds) ?? 0;
        return Material(
          color: theme.brand,
          elevation: 8,
          shadowColor: theme.textPrimary.withOpacity(0.28),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onOpen,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  LucideIcon(
                    LucideGlyph.messageSquare,
                    size: 22,
                    color: theme.surfaceCard,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: theme.surfaceCard,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: theme.surfaceCard,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.relatedOrderIds,
    required this.onMinimize,
    required this.onClose,
    required this.child,
  });

  final B2BThemeExtension theme;
  final String title;
  final String subtitle;
  final List<String> relatedOrderIds;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final width = media.width < 420 ? media.width - 32.0 : 380.0;
    final height = (media.height * 0.72).clamp(420.0, 540.0);

    return Material(
      color: theme.dialogSurface,
      elevation: 16,
      shadowColor: theme.textPrimary.withOpacity(0.32),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              decoration: BoxDecoration(
                color: theme.surfaceCard,
                border: Border(
                  bottom: BorderSide(color: theme.borderSubtle),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.brandContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: LucideIcon(
                      LucideGlyph.messageSquare,
                      size: 18,
                      color: theme.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: NotificationProvider.active ?? _silent,
                    builder: (context, _) {
                      final unread = NotificationProvider.active
                              ?.unreadMensajeCountFor(relatedOrderIds) ??
                          0;
                      if (unread <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 4, top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: theme.surfaceCard,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Minimizar',
                    onPressed: onMinimize,
                    visualDensity: VisualDensity.compact,
                    icon: LucideIcon(
                      LucideGlyph.minus,
                      size: 16,
                      color: theme.textSecondary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    icon: LucideIcon(
                      LucideGlyph.close,
                      size: 16,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

final ChangeNotifier _silent = ChangeNotifier();

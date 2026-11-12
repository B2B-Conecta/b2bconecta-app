import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/notifications/in_app_notification_model.dart';
import 'package:motolink_pro_app/core/notifications/notification_center_sheet.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

enum _NotifFilter { all, unread, orders, kycUsers }

/// Abre el centro: popover anclado en desktop/web; sheet en móvil.
Future<void> openNotificationCenter({
  required BuildContext context,
  required NotificationProvider provider,
  BuildContext? anchorContext,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  final usePopover = width >= AppBreakpoints.adminDesktop;
  if (!usePopover) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => NotificationCenterSheet(provider: provider),
    );
    return;
  }

  final anchor = anchorContext ?? context;
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      builder: (_) => NotificationCenterSheet(provider: provider),
    );
    return;
  }

  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final anchorRect = Rect.fromLTWH(
    topLeft.dx,
    topLeft.dy,
    box.size.width,
    box.size.height,
  );
  final overlaySize = overlay.size;
  const panelW = 400.0;
  const panelH = 520.0;
  var left = anchorRect.right - panelW;
  if (left < 12) left = 12;
  if (left + panelW > overlaySize.width - 12) {
    left = overlaySize.width - panelW - 12;
  }
  var top = anchorRect.bottom + 8;
  if (top + panelH > overlaySize.height - 12) {
    top = (overlaySize.height - panelH - 12).clamp(12.0, overlaySize.height);
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar notificaciones',
    barrierColor: Colors.black.withOpacity(0.18),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, anim, secondary) {
      return SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: panelW,
              height: panelH,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: Material(
                  color: Colors.transparent,
                  child: Shortcuts(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(LogicalKeyboardKey.escape):
                          DismissIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        DismissIntent: CallbackAction<DismissIntent>(
                          onInvoke: (_) {
                            Navigator.of(ctx).maybePop();
                            return null;
                          },
                        ),
                      },
                      child: Focus(
                        autofocus: true,
                        child: NotificationCenterPopover(
                          provider: provider,
                          onClose: () => Navigator.of(ctx).maybePop(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Panel flotante 400×520 anclado a la campana.
class NotificationCenterPopover extends StatefulWidget {
  const NotificationCenterPopover({
    super.key,
    required this.provider,
    required this.onClose,
  });

  final NotificationProvider provider;
  final VoidCallback onClose;

  @override
  State<NotificationCenterPopover> createState() =>
      _NotificationCenterPopoverState();
}

class _NotificationCenterPopoverState extends State<NotificationCenterPopover> {
  _NotifFilter _filter = _NotifFilter.all;

  bool _isOrderType(String type) {
    final t = type.trim().toLowerCase();
    return t.contains('pedido') ||
        t.contains('order') ||
        t == 'nuevo_pedido' ||
        t == 'order_created' ||
        t == 'order_updated' ||
        t == 'mensaje_pedido' ||
        t == 'chat_pedido';
  }

  bool _isKycUserType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'kyc' ||
        t.contains('usuario') ||
        t.contains('cuenta') ||
        t.contains('taller') ||
        t == 'account' ||
        t == 'registro';
  }

  List<InAppNotificationModel> _visible(List<InAppNotificationModel> items) {
    return switch (_filter) {
      _NotifFilter.all => items,
      _NotifFilter.unread => items.where((n) => !n.isRead).toList(),
      _NotifFilter.orders => items.where((n) => _isOrderType(n.type)).toList(),
      _NotifFilter.kycUsers =>
        items.where((n) => _isKycUserType(n.type)).toList(),
    };
  }

  String _whenText(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    return '$day/$mon/${dt.year}';
  }

  Color _avatarBg(String type) {
    final t = type.trim().toLowerCase();
    if (t == 'kyc') return const Color(0xFFDC2626);
    if (_isOrderType(t)) return const Color(0xFF1E3A8A);
    if (t == 'tasa_bcv') return const Color(0xFF0F766E);
    return AppColors.brand;
  }

  LucideGlyph _avatarGlyph(String type) {
    final t = type.trim().toLowerCase();
    if (t == 'kyc') return LucideGlyph.shieldCheck;
    if (_isOrderType(t)) return LucideGlyph.shoppingBag;
    if (t == 'tasa_bcv') return LucideGlyph.badgeDollarSign;
    return LucideGlyph.bell;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) {
        final items = widget.provider.items;
        final visible = _visible(items);
        final unread = widget.provider.unreadCount;

        return Container(
          width: 400,
          height: 520,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Notificaciones',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandLink.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$unread',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandLink,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: () => widget.provider.markAllAsRead(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandLink,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Marcar todo como leído',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in _NotifFilter.values)
                      _FilterChip(
                        label: switch (f) {
                          _NotifFilter.all => 'Todas',
                          _NotifFilter.unread => 'No leídas',
                          _NotifFilter.orders => 'Pedidos',
                          _NotifFilter.kycUsers => 'KYC / Usuarios',
                        },
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: widget.provider.isLoading && items.isEmpty
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : visible.isEmpty
                        ? Center(
                            child: Text(
                              'No hay notificaciones.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: AppColors.divider,
                            ),
                            itemBuilder: (context, index) {
                              final n = visible[index];
                              return _NotifRow(
                                notification: n,
                                when: _whenText(n.createdAt),
                                avatarBg: _avatarBg(n.type),
                                glyph: _avatarGlyph(n.type),
                                onTap: () async {
                                  await widget.provider.handleTap(n);
                                  if (!context.mounted) return;
                                  widget.onClose();
                                },
                                onDismiss: () =>
                                    widget.provider.deleteNotification(n.id),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brandLink.withOpacity(0.12)
          : AppColors.zebra,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brandLink : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.brandLink : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifRow extends StatefulWidget {
  const _NotifRow({
    required this.notification,
    required this.when,
    required this.avatarBg,
    required this.glyph,
    required this.onTap,
    required this.onDismiss,
  });

  final InAppNotificationModel notification;
  final String when;
  final Color avatarBg;
  final LucideGlyph glyph;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: LucideIcon(
                  widget.glyph,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            n.isRead ? FontWeight.w600 : FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.when,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    if (!n.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, bottom: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brandLink,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 14),
                    if (_hovered)
                      IconButton(
                        tooltip: 'Descartar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: widget.onDismiss,
                        icon: LucideIcon(
                          LucideGlyph.close,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

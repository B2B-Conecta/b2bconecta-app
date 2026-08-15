import 'package:flutter/material.dart';

import 'in_app_notification_model.dart';
import 'notification_provider.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

enum _ReadFilter {
  all,
  unread,
  read,
}

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({
    super.key,
    required this.provider,
  });

  final NotificationProvider provider;

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  _ReadFilter _filter = _ReadFilter.all;
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: widget.provider,
        builder: (context, _) {
          final items = widget.provider.items;
          final visible = switch (_filter) {
            _ReadFilter.unread => items.where((n) => !n.isRead).toList(),
            _ReadFilter.read => items.where((n) => n.isRead).toList(),
            _ReadFilter.all => items,
          };
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 14, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectionMode
                              ? '${_selectedIds.length} seleccionadas'
                              : 'Centro de notificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_selectionMode)
                        IconButton(
                          tooltip: 'Cancelar selección',
                          onPressed: () {
                            setState(() {
                              _selectionMode = false;
                              _selectedIds.clear();
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      if (_selectionMode && _selectedIds.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _confirmAndDeleteSelected(context),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                          label: Text(
                            'Eliminar',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (!_selectionMode && widget.provider.unreadCount > 0)
                        TextButton(
                          onPressed: () => widget.provider.markAllAsRead(),
                          child: const Text('Marcar todo leído'),
                        ),
                      if (!_selectionMode)
                        PopupMenuButton<int>(
                        tooltip: 'Más opciones',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 1) {
                            setState(() => _selectionMode = true);
                          } else if (value == 0) {
                            await _confirmAndDeleteAll(context);
                          } else if (value == 30) {
                            await _confirmAndDeleteOld(context, 30);
                          } else if (value == 60) {
                            await _confirmAndDeleteOld(context, 60);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<int>(
                            value: 1,
                            child: Text('Seleccionar notificaciones'),
                          ),
                          if (items.isNotEmpty)
                            PopupMenuItem<int>(
                              value: 0,
                              child: Text(
                                'Eliminar todas',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (items.isNotEmpty) const PopupMenuDivider(),
                          const PopupMenuItem<int>(
                            value: 30,
                            child: Text('Eliminar viejas (30+ días)'),
                          ),
                          const PopupMenuItem<int>(
                            value: 60,
                            child: Text('Eliminar viejas (60+ días)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filter == _ReadFilter.all,
                        onSelected: (_) => setState(() => _filter = _ReadFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('No leídos'),
                        selected: _filter == _ReadFilter.unread,
                        onSelected: (_) => setState(() => _filter = _ReadFilter.unread),
                      ),
                      ChoiceChip(
                        label: const Text('Leídos'),
                        selected: _filter == _ReadFilter.read,
                        onSelected: (_) => setState(() => _filter = _ReadFilter.read),
                      ),
                    ],
                  ),
                ),
                if (widget.provider.isLoading && items.isEmpty)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    ),
                  )
                else if (visible.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No tienes notificaciones todavía.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final n = visible[index];
                        return ListTile(
                          onLongPress: () {
                            setState(() {
                              _selectionMode = true;
                              _selectedIds.add(n.id);
                            });
                          },
                          onTap: () async {
                            if (_selectionMode) {
                              setState(() {
                                if (_selectedIds.contains(n.id)) {
                                  _selectedIds.remove(n.id);
                                } else {
                                  _selectedIds.add(n.id);
                                }
                                if (_selectedIds.isEmpty) _selectionMode = false;
                              });
                              return;
                            }
                            await widget.provider.handleTap(n);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          leading: _selectionMode
                              ? Checkbox(
                                  value: _selectedIds.contains(n.id),
                                  onChanged: (_) {
                                    setState(() {
                                      if (_selectedIds.contains(n.id)) {
                                        _selectedIds.remove(n.id);
                                      } else {
                                        _selectedIds.add(n.id);
                                      }
                                      if (_selectedIds.isEmpty) {
                                        _selectionMode = false;
                                      }
                                    });
                                  },
                                )
                              : _typeAvatar(n),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              if ((n.productName != null &&
                                      n.productName!.trim().isNotEmpty) ||
                                  (n.aliadoBusinessName != null &&
                                      n.aliadoBusinessName!.trim().isNotEmpty)) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _orderContextLine(n),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _whenText(n.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          trailing: _selectionMode
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!n.isRead)
                                      Container(
                                        width: 9,
                                        height: 9,
                                        margin: const EdgeInsets.only(right: 10),
                                        decoration: const BoxDecoration(
                                          color: AppColors.brand,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 21,
                                        color: Colors.red.shade700,
                                      ),
                                      onPressed: () => _confirmAndDeleteOne(context, n.id),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _typeAvatar(InAppNotificationModel n) {
    final t = n.type.trim();
    IconData icon;
    Color bg;
    switch (t) {
      case 'kyc':
        icon = Icons.verified_user_outlined;
        bg = Colors.red.shade600;
        break;
      case 'credito':
        icon = Icons.account_balance_outlined;
        bg = Colors.teal.shade700;
        break;
      case 'morosidad':
        icon = Icons.warning_amber_rounded;
        bg = Colors.deepOrange.shade700;
        break;
      case 'tasa_bcv':
        icon = Icons.currency_exchange;
        bg = AppColors.brandBlue;
        break;
      case 'pago':
        icon = Icons.payments_outlined;
        bg = Colors.red.shade700;
        break;
      case 'supervision':
        icon = Icons.admin_panel_settings_outlined;
        bg = Colors.indigo.shade700;
        break;
      case 'mensaje':
        icon = Icons.chat_bubble_outline;
        bg = AppColors.brandBlue;
        break;
      case 'pedido':
        icon = Icons.local_shipping_outlined;
        bg = AppColors.brand;
        break;
      case 'envio':
      case 'logistica':
        icon = Icons.local_shipping_outlined;
        bg = Colors.green.shade600;
        break;
      case 'validacion':
        icon = Icons.fact_check_outlined;
        bg = AppColors.brandBlue;
        break;
      case 'promocion':
        icon = Icons.campaign_outlined;
        bg = AppColors.brand;
        break;
      case 'soporte':
        icon = Icons.support_agent_outlined;
        bg = Colors.blue.shade700;
        break;
      default:
        icon = Icons.notifications_none_outlined;
        bg = AppColors.brandAccent;
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  String _whenText(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    final day = dt.day.toString().padLeft(2, '0');
    final mon = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$mon/$year';
  }

  String _orderContextLine(InAppNotificationModel n) {
    final p = n.productName?.trim();
    final a = n.aliadoBusinessName?.trim();
    if (p != null && p.isNotEmpty && a != null && a.isNotEmpty) {
      return 'Producto: $p · Aliado: $a';
    }
    if (p != null && p.isNotEmpty) return 'Producto: $p';
    if (a != null && a.isNotEmpty) return 'Aliado: $a';
    return '';
  }

  Future<void> _confirmAndDeleteAll(BuildContext context) async {
    final ok = await _showDeleteDialog(
      context: context,
      title: 'Eliminar todas las notificaciones',
      message:
          'Se borrarán todas las notificaciones de tu cuenta. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar todas',
    );
    if (ok != true) return;
    await widget.provider.deleteAllNotifications();
  }

  Future<void> _confirmAndDeleteOld(BuildContext context, int days) async {
    final ok = await _showDeleteDialog(
      context: context,
      title: 'Eliminar notificaciones viejas',
      message:
          'Se eliminarán notificaciones leídas con más de $days días. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar viejas',
    );
    if (ok != true) return;
    await widget.provider.deleteOldReadNotifications(olderThanDays: days);
  }

  Future<void> _confirmAndDeleteOne(BuildContext context, String id) async {
    final ok = await _showDeleteDialog(
      context: context,
      title: 'Eliminar notificación',
      message: 'Esta notificación se eliminará de forma permanente.',
      confirmLabel: 'Eliminar',
    );
    if (ok != true) return;
    await widget.provider.deleteNotification(id);
  }

  Future<void> _confirmAndDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final ok = await _showDeleteDialog(
      context: context,
      title: 'Eliminar seleccionadas',
      message: 'Se eliminarán $count notificaciones de forma permanente.',
      confirmLabel: 'Eliminar seleccionadas',
    );
    if (ok != true) return;
    await widget.provider.deleteNotifications(_selectedIds.toList());
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<bool?> _showDeleteDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceTinted,
        surfaceTintColor: AppColors.brandBlue.withOpacity(0.08),
        icon: const Icon(
          Icons.delete_forever_rounded,
          size: 36,
          color: AppColors.brand,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(color: AppColors.brandBlue, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text(
                    confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

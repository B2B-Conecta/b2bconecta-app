import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/features/commissions/commissions_service.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';

/// Estado reactivo de badges del sidebar admin (ChangeNotifier del proyecto).
///
/// El badge de Pedidos cuenta **pedidos/carritos** activos (1 por
/// `checkout_group_id`), no líneas de `transaction_requests`.
class AdminShellBadges extends ChangeNotifier {
  AdminShellBadges({NotificationProvider? notifications})
      : _notifications = notifications {
    _notifications?.addListener(_onNotifications);
  }

  NotificationProvider? _notifications;
  Timer? _poll;
  bool _started = false;
  bool _refreshing = false;

  int _activeOrders = 0;
  bool _unreadChat = false;
  bool _configAttention = false;

  int get activeOrders => _activeOrders;
  bool get hasUnreadChat => _unreadChat;
  bool get configNeedsAttention => _configAttention;

  ShellNavBadge? badgeFor(Object? key) {
    if (key is! AdminShellBadgeKey) return null;
    return switch (key) {
      AdminShellBadgeKey.pedidos =>
        _activeOrders > 0 ? ShellNavBadge.count(_activeOrders) : null,
      AdminShellBadgeKey.mensajes =>
        _unreadChat ? const ShellNavBadge.dot() : null,
      AdminShellBadgeKey.configuracion =>
        _configAttention ? const ShellNavBadge.warning() : null,
    };
  }

  void attachNotifications(NotificationProvider provider) {
    if (identical(_notifications, provider)) return;
    _notifications?.removeListener(_onNotifications);
    _notifications = provider;
    _notifications!.addListener(_onNotifications);
    _onNotifications();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refresh());
    });
  }

  void _onNotifications() {
    final next = (_notifications?.unreadChatCount ?? 0) > 0;
    if (next == _unreadChat) return;
    _unreadChat = next;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait<Object?>([
        OrdersService.countActiveTransactionRequestsForAdmin(),
        _resolveConfigAttention(),
      ]);
      final orders = results[0] as int;
      final config = results[1] as bool;
      final chat = (_notifications?.unreadChatCount ?? 0) > 0;
      if (orders == _activeOrders &&
          config == _configAttention &&
          chat == _unreadChat) {
        return;
      }
      _activeOrders = orders;
      _configAttention = config;
      _unreadChat = chat;
      notifyListeners();
    } catch (_) {
      // Conserva el último valor conocido.
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> _resolveConfigAttention() async {
    try {
      final rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      if (rec != null && rec.tasa > 0) {
        await BcvBasePrice.refresh(force: false);
      }
      if (CommissionsService.globalTasaBcvNeedsDailySync(rec?.updatedAt)) {
        return true;
      }
      // KYC / cuentas pendientes de revisión (señal ligera vía notificaciones).
      final items = _notifications?.items ?? const [];
      return items.any((n) {
        if (n.isRead) return false;
        final t = n.type.trim();
        return t == 'kyc' ||
            t == 'kyc_pendiente' ||
            t == 'cuenta_revision' ||
            t.contains('kyc');
      });
    } catch (_) {
      return _configAttention;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _notifications?.removeListener(_onNotifications);
    super.dispose();
  }
}

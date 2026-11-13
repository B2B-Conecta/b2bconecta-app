import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/features/commissions/commissions_service.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/support/support_service.dart';

/// Estado reactivo de badges del sidebar admin (ChangeNotifier del proyecto).
///
/// - Pedidos: carritos activos (`checkout_group_id`).
/// - Soporte: reclamos abiertos / en revisión.
/// - Comisiones (configuración): tasa BCV pendiente de sync diario.
/// - Usuarios: cuentas en `pending_review` (KYC).
class AdminShellBadges extends ChangeNotifier {
  AdminShellBadges({NotificationProvider? notifications})
      : _notifications = notifications {
    _notifications?.addListener(_onNotifications);
  }

  NotificationProvider? _notifications;
  Timer? _poll;
  Timer? _debounce;
  RealtimeChannel? _realtimeChannel;
  bool _started = false;
  bool _refreshing = false;

  int _activeOrders = 0;
  int _openSupport = 0;
  int _pendingKyc = 0;
  bool _unreadChat = false;
  bool _configAttention = false;

  int get activeOrders => _activeOrders;
  int get openSupport => _openSupport;
  int get pendingKyc => _pendingKyc;
  bool get hasUnreadChat => _unreadChat;
  bool get configNeedsAttention => _configAttention;

  ShellNavBadge? badgeFor(Object? key) {
    if (key is! AdminShellBadgeKey) return null;
    return switch (key) {
      AdminShellBadgeKey.pedidos =>
        _activeOrders > 0 ? ShellNavBadge.count(_activeOrders) : null,
      AdminShellBadgeKey.mensajes => _supportBadge(),
      AdminShellBadgeKey.configuracion =>
        _configAttention ? const ShellNavBadge.warning() : null,
      AdminShellBadgeKey.usuarios =>
        _pendingKyc > 0 ? ShellNavBadge.count(_pendingKyc) : null,
    };
  }

  ShellNavBadge? _supportBadge() {
    if (_openSupport > 0) return ShellNavBadge.count(_openSupport);
    final unread = _notifications?.unreadSupportCount ?? 0;
    if (unread > 0) return const ShellNavBadge.dot();
    return null;
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
    _subscribeRealtime();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refresh());
    });
  }

  void _subscribeRealtime() {
    if (_realtimeChannel != null) return;
    final channel = SupabaseAccess.client.channel('admin-shell-badges');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transaction_requests',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_tickets',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_ticket_messages',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_global_config',
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            // Ignora heartbeats de presencia; solo KYC / acceso.
            final prev =
                payload.oldRecord['account_access_status']?.toString();
            final next =
                payload.newRecord['account_access_status']?.toString();
            if (prev != next) _scheduleRefresh();
          },
        );
    channel.subscribe();
    _realtimeChannel = channel;
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(refresh());
    });
  }

  void _onNotifications() {
    final nextChat = (_notifications?.unreadChatCount ?? 0) > 0;
    if (nextChat != _unreadChat) {
      _unreadChat = nextChat;
    }
    // Soporte (punto) y señales KYC reaccionan al stream de notificaciones
    // sin esperar el refresh de conteos en DB.
    notifyListeners();
    _scheduleRefresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait<Object?>([
        OrdersService.countActiveTransactionRequestsForAdmin(),
        SupportService.countOpenSupportTicketsForAdmin(),
        _countPendingKycAccounts(),
        _resolveConfigAttention(),
      ]);
      final orders = results[0] as int;
      final support = results[1] as int;
      final kyc = results[2] as int;
      final config = results[3] as bool;
      final chat = (_notifications?.unreadChatCount ?? 0) > 0;
      if (orders == _activeOrders &&
          support == _openSupport &&
          kyc == _pendingKyc &&
          config == _configAttention &&
          chat == _unreadChat) {
        return;
      }
      _activeOrders = orders;
      _openSupport = support;
      _pendingKyc = kyc;
      _configAttention = config;
      _unreadChat = chat;
      notifyListeners();
    } catch (_) {
      // Conserva el último valor conocido.
    } finally {
      _refreshing = false;
    }
  }

  Future<int> _countPendingKycAccounts() async {
    try {
      final response = await SupabaseAccess.client
          .from('profiles')
          .select('id')
          .eq('account_access_status', AccountAccessStatus.pendingReview)
          .inFilter('role', const ['aliado', 'importador']);
      return (response as List<dynamic>).length;
    } catch (_) {
      // Fallback: señal ligera por notificaciones KYC.
      return _notifications?.unreadKycCount ?? _pendingKyc;
    }
  }

  Future<bool> _resolveConfigAttention() async {
    try {
      final rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      if (rec != null && rec.tasa > 0) {
        await BcvBasePrice.refresh(force: false);
      }
      return CommissionsService.globalTasaBcvNeedsDailySync(rec?.updatedAt);
    } catch (_) {
      return _configAttention;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseAccess.unsubscribeChannel(channel));
    }
    _notifications?.removeListener(_onNotifications);
    super.dispose();
  }
}

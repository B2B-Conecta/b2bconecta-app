import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';

/// Badge del rail importador: pedidos en `pendiente`.
enum ImporterShellBadgeKey { pedidos }

/// Contador en vivo de pedidos por confirmar (Realtime + sondeo).
class ImporterShellBadges extends ChangeNotifier {
  Timer? _poll;
  Timer? _debounce;
  RealtimeChannel? _channel;
  bool _started = false;

  int _pendingOrders = 0;

  int get pendingOrders => _pendingOrders;

  ShellNavBadge? badgeFor(Object? key) {
    if (key != ImporterShellBadgeKey.pedidos) return null;
    if (_pendingOrders <= 0) return null;
    return ShellNavBadge.count(_pendingOrders);
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await refresh();
    _subscribe();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refresh());
    });
  }

  void _subscribe() {
    if (_channel != null) return;
    final uid = SupabaseAccess.currentUserId;
    final channel = SupabaseAccess.client.channel('importer-shell-pedidos');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'transaction_requests',
      filter: uid == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'importador_id',
              value: uid,
            ),
      callback: (_) => _scheduleRefresh(),
    );
    channel.subscribe();
    _channel = channel;
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final count = await SupabaseService.countMyNewOrders();
    if (count == null || count == _pendingOrders) return;
    _pendingOrders = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(SupabaseAccess.unsubscribeChannel(channel));
    }
    super.dispose();
  }
}


import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/notifications/in_app_notification_model.dart';

class NotificationsService {
  NotificationsService._();

  static const _notificationsSelect =
      'id, user_id, title, body, type, is_read, related_id, created_at';

  /// Notificaciones in-app del usuario actual (más recientes primero).
  static Future<List<InAppNotificationModel>> fetchMyNotifications({
    int limit = 100,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return const [];

    final response = await SupabaseAccess.client
        .from('notifications')
        .select(_notificationsSelect)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = response as List<dynamic>;
    return list
        .map((row) => InAppNotificationModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  /// Marca una notificación como leída.
  static Future<void> markNotificationAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    await SupabaseAccess.client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true}).eq('id', notificationId);
  }

  /// Marca todas las notificaciones del usuario actual como leídas.
  static Future<void> markAllNotificationsAsRead() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return;
    await SupabaseAccess.client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  /// Marca como leídas las notificaciones de chat/pedido con [related_id] = id de pedido.
  static Future<void> markNotificationsReadForRelatedOrder(
      String transactionRequestId) async {
    final uid = SupabaseAccess.currentUserId;
    final rid = transactionRequestId.trim();
    if (uid == null || rid.isEmpty) return;
    await SupabaseAccess.client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', uid)
        .eq('related_id', rid)
        .eq('is_read', false);
  }

  /// Elimina notificaciones antiguas del usuario actual.
  /// Por defecto borra solo leídas con más de [olderThanDays] días.
  static Future<void> deleteOldNotifications({
    int olderThanDays = 30,
    bool onlyRead = true,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return;
    final days = olderThanDays < 1 ? 1 : olderThanDays;
    final cutoff =
        DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

    dynamic q = SupabaseAccess.client
        .from('notifications')
        .delete()
        .eq('user_id', uid)
        .lt('created_at', cutoff);

    if (onlyRead) {
      q = q.eq('is_read', true);
    }
    await q;
  }

  /// Elimina notificaciones puntuales del usuario actual.
  static Future<void> deleteNotificationsByIds(
      List<String> notificationIds) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return;
    final ids = notificationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    await SupabaseAccess.client
        .from('notifications')
        .delete()
        .eq('user_id', uid)
        .inFilter('id', ids);
  }

  /// Elimina todas las notificaciones del usuario actual.
  static Future<void> deleteAllMyNotifications() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return;
    await SupabaseAccess.client
        .from('notifications')
        .delete()
        .eq('user_id', uid);
  }

  /// Ficha de pedido por ID (respeta RLS del usuario actual).
  static Future<Map<String, NotificationOrderSummary>>
      fetchNotificationOrderSummariesByRequestIds(
    List<String> requestIds,
  ) async {
    final ids = requestIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    const selectCols =
        'id, aliado:profiles!transaction_requests_aliado_id_fkey(business_name), importador:profiles!transaction_requests_importador_id_fkey(business_name)';
    final rows = await SupabaseAccess.client
        .from('transaction_requests')
        .select(selectCols)
        .inFilter('id', ids);
    final list = rows as List<dynamic>;
    final out = <String, NotificationOrderSummary>{};
    for (final row in list) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final prod = m['products'];
      final ali = m['aliado'];
      String? productName;
      String? aliadoBusinessName;
      if (prod is Map) {
        productName = prod['name']?.toString().trim();
      }
      if (productName == null || productName.isEmpty) {
        final imp = m['importador'];
        if (imp is Map) {
          final ibn = imp['business_name']?.toString().trim();
          productName =
              (ibn != null && ibn.isNotEmpty) ? 'Pedido · $ibn' : 'Pedido';
        }
      }
      if (ali is Map) {
        aliadoBusinessName = ali['business_name']?.toString().trim();
      }
      out[id] = NotificationOrderSummary(
        productName: (productName != null && productName.isNotEmpty)
            ? productName
            : null,
        aliadoBusinessName:
            (aliadoBusinessName != null && aliadoBusinessName.isNotEmpty)
                ? aliadoBusinessName
                : null,
      );
    }
    return out;
  }

  /// Realtime: escucha nuevas notificaciones para el usuario autenticado.
  static RealtimeChannel subscribeToMyNotifications({
    required void Function(InAppNotificationModel notification) onInsert,
  }) {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) {
      throw StateError('No hay sesión activa para escuchar notificaciones.');
    }
    final channel = SupabaseAccess.client.channel('notifications:user:$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      callback: (payload) {
        final m = Map<String, dynamic>.from(payload.newRecord);
        onInsert(InAppNotificationModel.fromJson(m));
      },
    );
    channel.subscribe();
    return channel;
  }

  static String get _pushPlatform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }

  /// Registra token FCM del dispositivo actual.
  static Future<void> upsertDevicePushToken({required String token}) async {
    await SupabaseAccess.client.rpc(
      'upsert_device_push_token',
      params: <String, dynamic>{
        'p_token': token.trim(),
        'p_platform': _pushPlatform,
      },
    );
  }

  static Future<void> removeDevicePushToken({required String token}) async {
    await SupabaseAccess.client.rpc(
      'remove_device_push_token',
      params: <String, dynamic>{'p_token': token.trim()},
    );
  }
}

class NotificationOrderSummary {
  const NotificationOrderSummary({
    this.productName,
    this.aliadoBusinessName,
  });

  final String? productName;
  final String? aliadoBusinessName;
}

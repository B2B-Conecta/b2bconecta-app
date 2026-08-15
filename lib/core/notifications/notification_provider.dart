import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'in_app_notification_model.dart';
import 'notification_deep_link.dart';
import 'push_notification_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'kyc_notification_match.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required this.homeRole,
  });

  final AppHomeRole homeRole;

  final List<InAppNotificationModel> _items = <InAppNotificationModel>[];
  RealtimeChannel? _channel;
  bool _loading = false;
  bool _ready = false;

  List<InAppNotificationModel> get items => List<InAppNotificationModel>.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get isReady => _ready;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> start() async {
    if (_ready) return;
    _loading = true;
    notifyListeners();
    try {
      final list = await SupabaseService.fetchMyNotifications(limit: 120);
      _items
        ..clear()
        ..addAll(list);
      await _enrichOrderContext();
      _channel = SupabaseService.subscribeToMyNotifications(
        onInsert: _onRealtimeInsert,
      );
      _ready = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    final list = await SupabaseService.fetchMyNotifications(limit: 120);
    _items
      ..clear()
      ..addAll(list);
    await _enrichOrderContext();
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    final idx = _items.indexWhere((n) => n.id == notificationId);
    if (idx < 0 || _items[idx].isRead) return;
    _items[idx] = _items[idx].copyWith(isRead: true);
    notifyListeners();
    try {
      await SupabaseService.markNotificationAsRead(notificationId);
    } catch (_) {
      _items[idx] = _items[idx].copyWith(isRead: false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final anyUnread = _items.any((n) => !n.isRead);
    if (!anyUnread) return;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
    try {
      await SupabaseService.markAllNotificationsAsRead();
    } catch (_) {
      await reload();
      rethrow;
    }
  }

  Future<void> deleteOldReadNotifications({int olderThanDays = 30}) async {
    await SupabaseService.deleteOldNotifications(
      olderThanDays: olderThanDays,
      onlyRead: true,
    );
    await reload();
  }

  Future<void> deleteNotification(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;
    await SupabaseService.deleteNotificationsByIds([id]);
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  Future<void> deleteNotifications(List<String> notificationIds) async {
    final ids = notificationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    await SupabaseService.deleteNotificationsByIds(ids);
    _items.removeWhere((n) => ids.contains(n.id));
    notifyListeners();
  }

  Future<void> deleteAllNotifications() async {
    await SupabaseService.deleteAllMyNotifications();
    _items.clear();
    notifyListeners();
  }

  Future<void> handleTap(InAppNotificationModel n) async {
    await markAsRead(n.id);
    navigateFromNotificationPayload(
      homeRole: homeRole,
      type: n.type,
      relatedId: n.relatedId,
      title: n.title,
    );
  }

  void _onRealtimeInsert(InAppNotificationModel n) {
    _items.insert(0, n);
    _enrichOrderContext();
    notifyListeners();
    final title = n.title.trim().isNotEmpty ? n.title : 'B2B Conecta';
    final body = n.body.trim().isNotEmpty ? n.body : title;
    final accessApproved = isAliadoAccessApprovedNotification(
      type: n.type,
      title: n.title,
    );
    PushNotificationService.instance.showLocalBanner(
      title: accessApproved ? 'Acceso validado' : title,
      body: body,
      type: n.type,
      relatedId: n.relatedId,
      notificationId: n.id,
    );
  }

  Future<void> _enrichOrderContext() async {
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    final ids = _items
        .map((n) => n.relatedId?.trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty && uuidRe.hasMatch(e))
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final map = await SupabaseService.fetchNotificationOrderSummariesByRequestIds(ids);
    for (var i = 0; i < _items.length; i++) {
      final rid = _items[i].relatedId?.trim();
      if (rid == null || rid.isEmpty) continue;
      final s = map[rid];
      if (s == null) continue;
      _items[i] = _items[i].copyWith(
        productName: s.productName,
        aliadoBusinessName: s.aliadoBusinessName,
      );
    }
  }

  @override
  void dispose() {
    SupabaseService.unsubscribeChannel(_channel);
    _channel = null;
    super.dispose();
  }
}

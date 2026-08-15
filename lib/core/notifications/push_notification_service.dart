import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:motolink_pro_app/app/firebase_options.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'kyc_notification_match.dart';
import 'notification_deep_link.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

typedef PushNotificationTapHandler = void Function({
  required String type,
  String? relatedId,
  String? notificationId,
  String? title,
});

/// Registro FCM, notificaciones del sistema y deep links al tocar.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentToken;
  PushNotificationTapHandler? _onTap;

  static const _androidChannel = AndroidNotificationChannel(
    'motolink_alerts',
    'B2B Conecta',
    description: 'Pedidos, pagos y mensajes de B2B Conecta',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    if (!(Platform.isAndroid || Platform.isIOS)) return;

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        _handleLocalTapPayload(details.payload);
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onRemoteTap);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onRemoteTap(initial);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _currentToken = token;
      SupabaseService.upsertDevicePushToken(token: token);
    });

    _initialized = true;
  }

  void registerTapHandler(PushNotificationTapHandler handler) {
    _onTap = handler;
  }

  void unregisterTapHandler() {
    _onTap = null;
  }

  Future<void> registerForCurrentUser() async {
    if (!_initialized || kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      _currentToken = token;
      await SupabaseService.upsertDevicePushToken(token: token);
    } catch (e, st) {
      debugPrint('Push token registration failed: $e\n$st');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_initialized || kIsWeb) return;
    final token = _currentToken;
    if (token != null && token.isNotEmpty) {
      try {
        await SupabaseService.removeDevicePushToken(token: token);
      } catch (_) {}
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _currentToken = null;
  }

  Future<void> showLocalBanner({
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? notificationId,
  }) async {
    if (!_initialized || kIsWeb) return;
    final payload = _encodePayload(
      type: type ?? 'mensaje',
      relatedId: relatedId,
      notificationId: notificationId,
      title: title,
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    final data = message.data;
    final rawTitle =
        n?.title ?? data['title']?.toString() ?? 'B2B Conecta';
    final type = data['type']?.toString() ?? 'mensaje';
    final accessApproved = isAliadoAccessApprovedNotification(
      type: type,
      title: rawTitle,
    );
    showLocalBanner(
      title: accessApproved ? 'Acceso validado' : rawTitle,
      body: n?.body ?? data['body']?.toString() ?? '',
      type: type,
      relatedId: data['related_id']?.toString(),
      notificationId: data['notification_id']?.toString(),
    );
  }

  void _onRemoteTap(RemoteMessage message) {
    final data = message.data;
    _dispatchTap(
      type: data['type']?.toString() ?? 'mensaje',
      relatedId: data['related_id']?.toString(),
      notificationId: data['notification_id']?.toString(),
      title: message.notification?.title,
    );
  }

  void _handleLocalTapPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    final parts = payload.split('|');
    if (parts.length < 2) return;
    _dispatchTap(
      type: parts[0],
      relatedId: parts[1].isEmpty ? null : parts[1],
      notificationId: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      title: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }

  String _encodePayload({
    required String type,
    String? relatedId,
    String? notificationId,
    String? title,
  }) {
    return [
      type,
      relatedId ?? '',
      notificationId ?? '',
      title ?? '',
    ].join('|');
  }

  void _dispatchTap({
    required String type,
    String? relatedId,
    String? notificationId,
    String? title,
  }) {
    final handler = _onTap;
    if (handler != null) {
      handler(
        type: type,
        relatedId: relatedId,
        notificationId: notificationId,
        title: title,
      );
      return;
    }
    debugPrint('Push tap without handler: type=$type related=$relatedId');
  }

  /// Deep link desde push cuando [MainShell] ya está montado.
  static void navigateTap({
    required AppHomeRole homeRole,
    required String type,
    String? relatedId,
    String? title,
  }) {
    navigateFromNotificationPayload(
      homeRole: homeRole,
      type: type,
      relatedId: relatedId,
      title: title,
    );
  }
}

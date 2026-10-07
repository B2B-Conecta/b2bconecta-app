import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motolink_pro_app/app/config/brand_copy.dart';
import 'package:motolink_pro_app/app/firebase_options.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'kyc_notification_match.dart';
import 'notification_deep_link.dart';
import 'package:motolink_pro_app/core/notifications/web_push_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';

const _kAndroidChannelId = 'motolink_alerts';
const _kAndroidChannelName = 'B2B Conecta';
const _kAndroidChannelDescription = 'Pedidos, pagos y mensajes de B2B Conecta';
const _kNotificationIcon = '@drawable/ic_stat_notification';
const _kPushPermissionRequested = 'b2b_push_permission_requested';

const _androidChannel = AndroidNotificationChannel(
  _kAndroidChannelId,
  _kAndroidChannelName,
  description: _kAndroidChannelDescription,
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // El bloque `notification` lo muestra el sistema. Solo los data-only
  // necesitan un aviso local, para no duplicar el de la bandeja.
  if (message.notification != null) return;
  final title = message.data['title']?.toString().trim() ?? '';
  final body = message.data['body']?.toString().trim() ?? '';
  if (title.isEmpty && body.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings(_kNotificationIcon);
  await plugin.initialize(
    const InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    ),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
  await plugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title.isNotEmpty ? title : 'B2B Conecta',
    body.isNotEmpty ? body : title,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: _kNotificationIcon,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: [
      message.data['type']?.toString() ?? 'mensaje',
      message.data['related_id']?.toString() ?? '',
      message.data['notification_id']?.toString() ?? '',
      title,
    ].join('|'),
  );
}

typedef PushNotificationTapHandler = void Function({
  required String type,
  String? relatedId,
  String? notificationId,
  String? title,
});

/// Registro FCM, notificaciones del sistema y deep links al tocar.
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initFuture;
  final Completer<void> _uiReady = Completer<void>();
  bool _initialized = false;
  bool _observingLifecycle = false;
  String? _currentToken;
  PushNotificationTapHandler? _onTap;
  _PendingPushTap? _pendingTap;

  /// La actividad ya pintó un frame: Android puede mostrar el permiso.
  void markUiReady() {
    if (!_uiReady.isCompleted) _uiReady.complete();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture!;
    final run = _initialize();
    _initFuture = run;
    try {
      await run;
    } catch (e) {
      if (identical(_initFuture, run)) _initFuture = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      await WebPushService.instance.initialize(
        onTap: ({
          required String type,
          String? relatedId,
          String? notificationId,
        }) {
          handleExternalTap(
            type: type,
            relatedId: relatedId,
            notificationId: notificationId,
          );
        },
      );
      _initialized = true;
      return;
    }

    if (!(Platform.isAndroid || Platform.isIOS)) return;

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings(_kNotificationIcon);
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

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onRemoteTap);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onRemoteTap(initial);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _currentToken = token;
      unawaited(() async {
        try {
          await _upsertToken(token);
        } catch (e, st) {
          debugPrint('Push token refresh failed: $e\n$st');
        }
      }());
    });

    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }

    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(registerForCurrentUser());
    }
  }

  void registerTapHandler(PushNotificationTapHandler handler) {
    _onTap = handler;
    final pending = _pendingTap;
    if (pending != null) {
      _pendingTap = null;
      handler(
        type: pending.type,
        relatedId: pending.relatedId,
        notificationId: pending.notificationId,
        title: pending.title,
      );
    }
  }

  void unregisterTapHandler() {
    _onTap = null;
  }

  Future<void> registerForCurrentUser() async {
    await initialize();
    if (kIsWeb) {
      await WebPushService.instance.refreshStatus(syncIfGranted: true);
      return;
    }
    if (!_initialized) return;
    await _uiReady.future;
    try {
      await _requestPermissionIfNeeded();
      if (!await _notificationsGranted()) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      _currentToken = token;
      await _upsertToken(token);
    } catch (e, st) {
      debugPrint('Push token registration failed: $e\n$st');
    }
  }

  Future<void> _requestPermissionIfNeeded() async {
    final messaging = FirebaseMessaging.instance;
    final current = await messaging.getNotificationSettings();
    if (_isGranted(current.authorizationStatus)) return;

    if (Platform.isAndroid) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kPushPermissionRequested) == true) return;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await prefs.setBool(_kPushPermissionRequested, true);
      return;
    }

    if (current.authorizationStatus == AuthorizationStatus.notDetermined) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<bool> _notificationsGranted() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _isGranted(settings.authorizationStatus);
  }

  bool _isGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _upsertToken(String token) async {
    if (SupabaseService.currentUserId == null) return;
    if (!await _notificationsGranted()) return;
    await SupabaseService.upsertDevicePushToken(token: token);
  }

  Future<void> unregisterCurrentDevice() async {
    if (kIsWeb) {
      await WebPushService.instance.unregisterCurrentDevice();
      return;
    }
    if (!_initialized) return;
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
    try {
      await _local.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        BrandCopy.display(title),
        BrandCopy.display(body),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: _kNotificationIcon,
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e, st) {
      debugPrint('Local notification failed: $e\n$st');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    final data = message.data;
    final rawTitle = BrandCopy.display(
      n?.title ?? data['title']?.toString() ?? BrandCopy.name,
    );
    final type = data['type']?.toString() ?? 'mensaje';
    final accessApproved = isAliadoAccessApprovedNotification(
      type: type,
      title: rawTitle,
    );
    showLocalBanner(
      title: accessApproved ? 'Acceso validado' : rawTitle,
      body: BrandCopy.display(n?.body ?? data['body']?.toString() ?? ''),
      type: type,
      relatedId: data['related_id']?.toString(),
      notificationId: data['notification_id']?.toString(),
    );
  }

  void handleExternalTap({
    required String type,
    String? relatedId,
    String? notificationId,
    String? title,
  }) {
    _dispatchTap(
      type: type,
      relatedId: relatedId,
      notificationId: notificationId,
      title: title,
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
    _pendingTap = _PendingPushTap(
      type: type,
      relatedId: relatedId,
      notificationId: notificationId,
      title: title,
    );
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

class _PendingPushTap {
  const _PendingPushTap({
    required this.type,
    this.relatedId,
    this.notificationId,
    this.title,
  });

  final String type;
  final String? relatedId;
  final String? notificationId;
  final String? title;
}

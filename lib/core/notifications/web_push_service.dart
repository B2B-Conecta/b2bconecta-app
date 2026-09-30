import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/notifications/web_push_bridge.dart';
import 'package:motolink_pro_app/core/notifications/web_push_environment.dart';
import 'package:motolink_pro_app/core/notifications/web_push_status.dart';
import 'package:motolink_pro_app/core/notifications/web_push_subscription_keys.dart';

/// Web Push para la PWA. No pide permiso al abrir la app.
class WebPushService extends ChangeNotifier {
  WebPushService._();

  static final WebPushService instance = WebPushService._();

  bool _initialized = false;
  WebPushUiStatus _status = WebPushUiStatus.unsupported;
  String? _lastError;
  void Function({
    required String type,
    String? relatedId,
    String? notificationId,
  })? _onTap;

  WebPushUiStatus get status => _status;
  String? get lastError => _lastError;
  bool get isIos => WebPushBridge.isIos;
  bool get isStandalone => WebPushBridge.isStandalone;

  static String? get vapidPublicKey {
    final k = dotenv.env['NEXT_PUBLIC_WEB_PUSH_VAPID_PUBLIC_KEY']?.trim();
    if (k == null || k.isEmpty) return null;
    return k;
  }

  Future<void> initialize({
    void Function({
      required String type,
      String? relatedId,
      String? notificationId,
    })? onTap,
  }) async {
    if (_initialized || !kIsWeb) return;
    _initialized = true;
    _onTap = onTap;
    WebPushBridge.onClick(_dispatchClick);
    final launch = WebPushBridge.consumeLaunchQuery();
    if (launch != null) {
      _dispatchClick(launch);
    }
    await refreshStatus(syncIfGranted: true);
  }

  Future<void> refreshStatus({bool syncIfGranted = false}) async {
    _lastError = null;
    _status = await _computeStatus();
    notifyListeners();
    if (syncIfGranted && _status == WebPushUiStatus.subscribed) {
      await _upsertCurrentSubscription();
    }
  }

  Future<WebPushUiStatus> _computeStatus() async {
    if (!kIsWeb || !WebPushBridge.hasApi || vapidPublicKey == null) {
      return WebPushUiStatus.unsupported;
    }
    if (WebPushBridge.isIos && !WebPushBridge.isStandalone) {
      return WebPushUiStatus.iosNeedsInstall;
    }
    final perm = WebPushBridge.permission();
    if (perm == 'denied') return WebPushUiStatus.permissionDenied;
    if (perm != 'granted') return WebPushUiStatus.permissionDefault;

    final raw = await WebPushBridge.getSubscription();
    if (raw == null) return WebPushUiStatus.expired;
    final keys = WebPushSubscriptionKeys.fromJson(raw);
    if (!keys.isValid) return WebPushUiStatus.expired;
    return WebPushUiStatus.subscribed;
  }

  Future<void> enableFromUserGesture() async {
    if (!kIsWeb) return;
    final vapid = vapidPublicKey;
    if (vapid == null) {
      _lastError = 'Falta NEXT_PUBLIC_WEB_PUSH_VAPID_PUBLIC_KEY en este entorno.';
      _status = WebPushUiStatus.error;
      notifyListeners();
      return;
    }
    if (WebPushBridge.isIos && !WebPushBridge.isStandalone) {
      _status = WebPushUiStatus.iosNeedsInstall;
      notifyListeners();
      return;
    }
    try {
      final result = await WebPushBridge.subscribe(vapid);
      final perm = result['permission']?.toString() ?? 'denied';
      if (perm == 'denied') {
        _status = WebPushUiStatus.permissionDenied;
        notifyListeners();
        return;
      }
      final subRaw = result['subscription'];
      if (subRaw is! Map) {
        _status = WebPushUiStatus.error;
        _lastError = 'El navegador no devolvió una suscripción.';
        notifyListeners();
        return;
      }
      final keys = WebPushSubscriptionKeys.fromJson(
        Map<String, dynamic>.from(subRaw),
      );
      if (!keys.isValid) {
        _status = WebPushUiStatus.error;
        _lastError = 'La suscripción recibida no es válida.';
        notifyListeners();
        return;
      }
      await SupabaseService.upsertWebPushSubscription(
        endpoint: keys.endpoint,
        p256dh: keys.p256dh,
        auth: keys.auth,
        userAgent: _userAgentHint(),
        platform: webPushPlatformFromUserAgent(
          _userAgentHint(),
          isIos: WebPushBridge.isIos,
        ),
        environment: webPushEnvironmentFromSupabaseUrl(
          dotenv.env['NEXT_PUBLIC_SUPABASE_URL'],
        ).wireValue,
      );
      _status = WebPushUiStatus.subscribed;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _status = WebPushUiStatus.error;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> disableFromUserGesture() async {
    try {
      final endpoint = await WebPushBridge.unsubscribe();
      if (endpoint.trim().isNotEmpty) {
        await SupabaseService.deactivateWebPushSubscription(endpoint: endpoint);
      } else {
        await SupabaseService.deactivateMyWebPushSubscriptions();
      }
    } catch (_) {
      try {
        await SupabaseService.deactivateMyWebPushSubscriptions();
      } catch (_) {}
    }
    await refreshStatus();
  }

  Future<void> unregisterCurrentDevice() async {
    if (!kIsWeb || !_initialized) return;
    try {
      final endpoint = await WebPushBridge.unsubscribe();
      if (endpoint.trim().isNotEmpty) {
        await SupabaseService.deactivateWebPushSubscription(endpoint: endpoint);
      } else {
        await SupabaseService.deactivateMyWebPushSubscriptions();
      }
    } catch (_) {
      try {
        await SupabaseService.deactivateMyWebPushSubscriptions();
      } catch (_) {}
    }
    _status = WebPushUiStatus.permissionDefault;
    notifyListeners();
  }

  Future<void> sendTestNotification() async {
    await SupabaseService.requestMyWebPushTest();
  }

  Future<void> _upsertCurrentSubscription() async {
    final raw = await WebPushBridge.getSubscription();
    if (raw == null) return;
    final keys = WebPushSubscriptionKeys.fromJson(raw);
    if (!keys.isValid) return;
    try {
      await SupabaseService.upsertWebPushSubscription(
        endpoint: keys.endpoint,
        p256dh: keys.p256dh,
        auth: keys.auth,
        userAgent: _userAgentHint(),
        platform: webPushPlatformFromUserAgent(
          _userAgentHint(),
          isIos: WebPushBridge.isIos,
        ),
        environment: webPushEnvironmentFromSupabaseUrl(
          dotenv.env['NEXT_PUBLIC_SUPABASE_URL'],
        ).wireValue,
      );
    } catch (e) {
      debugPrint('Web Push re-register failed: $e');
    }
  }

  String _userAgentHint() {
    if (!kIsWeb) return '';
    try {
      return WebPushBridge.isIos ? 'ios-safari' : 'web';
    } catch (_) {
      return 'web';
    }
  }

  void _dispatchClick(WebPushClickPayload payload) {
    _onTap?.call(
      type: payload.type,
      relatedId: payload.relatedId,
      notificationId: payload.notificationId,
    );
  }
}

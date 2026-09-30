import 'web_push_bridge_stub.dart'
    if (dart.library.js_interop) 'web_push_bridge_web.dart';

class WebPushClickPayload {
  const WebPushClickPayload({
    required this.type,
    this.relatedId,
    this.notificationId,
  });

  final String type;
  final String? relatedId;
  final String? notificationId;
}

/// Acceso al Push API / Service Worker. En IO es un stub.
abstract final class WebPushBridge {
  static bool get hasApi => webPushBridgeHasApi();

  static bool get isIos => webPushBridgeIsIos();

  static bool get isStandalone => webPushBridgeIsStandalone();

  static String permission() => webPushBridgePermission();

  static Future<String> requestPermission() => webPushBridgeRequestPermission();

  static Future<Map<String, dynamic>?> getSubscription() =>
      webPushBridgeGetSubscription();

  static Future<Map<String, dynamic>> subscribe(String vapidPublicKey) =>
      webPushBridgeSubscribe(vapidPublicKey);

  static Future<String> unsubscribe() => webPushBridgeUnsubscribe();

  static void onClick(void Function(WebPushClickPayload payload) handler) =>
      webPushBridgeOnClick(handler);

  static WebPushClickPayload? consumeLaunchQuery() =>
      webPushBridgeConsumeLaunchQuery();
}

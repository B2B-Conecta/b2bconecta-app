import 'web_push_bridge.dart';

bool webPushBridgeHasApi() => false;

bool webPushBridgeIsIos() => false;

bool webPushBridgeIsAndroid() => false;

bool webPushBridgeIsDesktopWeb() => false;

bool webPushBridgeIsStandalone() => false;

String webPushBridgePermission() => 'unsupported';

String webPushBridgeUserAgent() => '';

String webPushBridgePlatformHint() => 'unsupported';

Future<String> webPushBridgeRequestPermission() async => 'denied';

Future<Map<String, dynamic>?> webPushBridgeGetSubscription() async => null;

Future<Map<String, dynamic>> webPushBridgeSubscribe(String vapidPublicKey) async {
  return const {'permission': 'denied', 'subscription': null};
}

Future<String> webPushBridgeUnsubscribe() async => '';

void webPushBridgeOnClick(void Function(WebPushClickPayload payload) handler) {}

WebPushClickPayload? webPushBridgeConsumeLaunchQuery() => null;

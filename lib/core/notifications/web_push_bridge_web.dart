import 'dart:convert';
import 'dart:js_interop';

import 'web_push_bridge.dart';

@JS('b2bWebPush')
extension type _B2bWebPush(JSObject _) implements JSObject {
  external bool hasApi();
  external bool isIos();
  external bool isStandalone();
  external String getPermission();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSString> getSubscription();
  external JSPromise<JSString> subscribe(String vapidPublicKey);
  external JSPromise<JSString> unsubscribe();
  external void onClick(JSFunction handler);
  external String consumeLaunchQuery();
}

@JS('b2bWebPush')
external _B2bWebPush? get _apiOrNull;

_B2bWebPush? get _api {
  try {
    return _apiOrNull;
  } catch (_) {
    return null;
  }
}

bool webPushBridgeHasApi() {
  final api = _api;
  if (api == null) return false;
  try {
    return api.hasApi();
  } catch (_) {
    return false;
  }
}

bool webPushBridgeIsIos() {
  try {
    return _api?.isIos() ?? false;
  } catch (_) {
    return false;
  }
}

bool webPushBridgeIsStandalone() {
  try {
    return _api?.isStandalone() ?? false;
  } catch (_) {
    return false;
  }
}

String webPushBridgePermission() {
  try {
    return _api?.getPermission() ?? 'unsupported';
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> webPushBridgeRequestPermission() async {
  final api = _api;
  if (api == null) return 'denied';
  final raw = await api.requestPermission().toDart;
  return raw.toDart;
}

Map<String, dynamic>? _mapFromJson(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final decoded = jsonDecode(t);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return null;
}

Future<Map<String, dynamic>?> webPushBridgeGetSubscription() async {
  final api = _api;
  if (api == null) return null;
  final raw = await api.getSubscription().toDart;
  return _mapFromJson(raw.toDart);
}

Future<Map<String, dynamic>> webPushBridgeSubscribe(String vapidPublicKey) async {
  final api = _api;
  if (api == null) {
    return const {'permission': 'denied', 'subscription': null};
  }
  final raw = await api.subscribe(vapidPublicKey).toDart;
  return _mapFromJson(raw.toDart) ??
      const {'permission': 'denied', 'subscription': null};
}

Future<String> webPushBridgeUnsubscribe() async {
  final api = _api;
  if (api == null) return '';
  final raw = await api.unsubscribe().toDart;
  return raw.toDart;
}

void webPushBridgeOnClick(void Function(WebPushClickPayload payload) handler) {
  final api = _api;
  if (api == null) return;
  api.onClick(((JSString json) {
    final map = _mapFromJson(json.toDart);
    if (map == null) return;
    handler(_clickFromMap(map));
  }).toJS);
}

WebPushClickPayload? webPushBridgeConsumeLaunchQuery() {
  final api = _api;
  if (api == null) return null;
  try {
    final map = _mapFromJson(api.consumeLaunchQuery());
    if (map == null) return null;
    return _clickFromMap(map);
  } catch (_) {
    return null;
  }
}

WebPushClickPayload _clickFromMap(Map<String, dynamic> map) {
  final related = map['related_id']?.toString().trim() ?? '';
  final nid = map['notification_id']?.toString().trim() ?? '';
  return WebPushClickPayload(
    type: map['type']?.toString().trim().isNotEmpty == true
        ? map['type'].toString().trim()
        : 'mensaje',
    relatedId: related.isEmpty ? null : related,
    notificationId: nid.isEmpty ? null : nid,
  );
}

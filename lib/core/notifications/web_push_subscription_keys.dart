/// Claves públicas de una suscripción Push API (nunca la clave VAPID privada).
class WebPushSubscriptionKeys {
  const WebPushSubscriptionKeys({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;

  bool get isValid =>
      isWebPushEndpointValid(endpoint) &&
      isWebPushKeyValid(p256dh) &&
      isWebPushKeyValid(auth);

  factory WebPushSubscriptionKeys.fromJson(Map<String, dynamic> json) {
    return WebPushSubscriptionKeys(
      endpoint: json['endpoint']?.toString().trim() ?? '',
      p256dh: json['p256dh']?.toString().trim() ?? '',
      auth: json['auth']?.toString().trim() ?? '',
    );
  }
}

bool isWebPushEndpointValid(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.length < 32 || v.length > 2048) return false;
  final uri = Uri.tryParse(v);
  if (uri == null || !uri.hasScheme || uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  if (v.contains(' ')) return false;
  return true;
}

bool isWebPushKeyValid(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.length < 8 || v.length > 512) return false;
  return !RegExp(r'\s').hasMatch(v);
}

String webPushPlatformFromUserAgent(String ua, {required bool isIos}) {
  final t = ua.toLowerCase();
  if (isIos) return 'ios';
  if (t.contains('android')) return 'android';
  if (t.contains('iphone') || t.contains('ipad') || t.contains('ipod')) {
    return 'ios';
  }
  return 'desktop';
}

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'marketing_consent.dart';
import 'meta_pixel_config.dart';

MarketingConsent readMarketingConsent() {
  final raw = _readCookie(MetaPixelConfig.consentCookieName);
  return MarketingConsentCodec.parse(raw);
}

void writeMarketingConsent(MarketingConsent consent) {
  if (consent == MarketingConsent.unknown) return;
  final value = MarketingConsentCodec.encode(consent);
  final host = html.window.location.hostname ?? '';
  final domain = MarketingConsentCodec.cookieDomainForHost(host);
  final secure = html.window.location.protocol == 'https:';
  final parts = <String>[
    '${MetaPixelConfig.consentCookieName}=$value',
    'Path=/',
    'Max-Age=${MetaPixelConfig.consentMaxAgeSeconds}',
    'SameSite=Lax',
    if (domain != null) 'Domain=$domain',
    if (secure) 'Secure',
  ];
  html.document.cookie = parts.join('; ');
}

String? _readCookie(String name) {
  final all = html.document.cookie ?? '';
  for (final part in all.split(';')) {
    final kv = part.trim();
    final i = kv.indexOf('=');
    if (i <= 0) continue;
    if (kv.substring(0, i) == name) {
      return Uri.decodeComponent(kv.substring(i + 1));
    }
  }
  return null;
}

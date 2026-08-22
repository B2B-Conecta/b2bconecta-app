import 'meta_pixel_config.dart';

enum MarketingConsent { unknown, accepted, denied }

abstract final class MarketingConsentCodec {
  static const acceptedValue = 'accepted';
  static const deniedValue = 'denied';

  static MarketingConsent parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case acceptedValue:
      case '1':
      case 'true':
      case 'yes':
      case 'si':
        return MarketingConsent.accepted;
      case deniedValue:
      case '0':
      case 'false':
      case 'no':
        return MarketingConsent.denied;
      default:
        return MarketingConsent.unknown;
    }
  }

  static String encode(MarketingConsent consent) {
    return switch (consent) {
      MarketingConsent.accepted => acceptedValue,
      MarketingConsent.denied => deniedValue,
      MarketingConsent.unknown => '',
    };
  }

  /// Cookie host-only en localhost / preview; `.b2bconecta.com.ve` en prod.
  static String? cookieDomainForHost(String host) {
    final h = host.toLowerCase().split(':').first.trim();
    if (h == 'b2bconecta.com.ve' || h.endsWith('.b2bconecta.com.ve')) {
      return MetaPixelConfig.consentCookieDomain;
    }
    return null;
  }
}

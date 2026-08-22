import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/ads/marketing_consent.dart';
import 'package:motolink_pro_app/features/ads/meta_pixel_config.dart';
import 'package:motolink_pro_app/features/ads/meta_pixel_events.dart';

void main() {
  test('parses consent cookie values', () {
    expect(MarketingConsentCodec.parse('accepted'), MarketingConsent.accepted);
    expect(MarketingConsentCodec.parse('1'), MarketingConsent.accepted);
    expect(MarketingConsentCodec.parse('denied'), MarketingConsent.denied);
    expect(MarketingConsentCodec.parse('0'), MarketingConsent.denied);
    expect(MarketingConsentCodec.parse(null), MarketingConsent.unknown);
    expect(MarketingConsentCodec.parse(''), MarketingConsent.unknown);
  });

  test('cookie domain is parent only on b2bconecta hosts', () {
    expect(
      MarketingConsentCodec.cookieDomainForHost('www.b2bconecta.com.ve'),
      MetaPixelConfig.consentCookieDomain,
    );
    expect(
      MarketingConsentCodec.cookieDomainForHost('app.b2bconecta.com.ve'),
      MetaPixelConfig.consentCookieDomain,
    );
    expect(
      MarketingConsentCodec.cookieDomainForHost('b2bconecta.com.ve'),
      MetaPixelConfig.consentCookieDomain,
    );
    expect(MarketingConsentCodec.cookieDomainForHost('localhost'), isNull);
    expect(
      MarketingConsentCodec.cookieDomainForHost(
        'b2bconecta-app-git-dev-b2bconecta.vercel.app',
      ),
      isNull,
    );
  });

  test('pixel event dedupe keys are stable per identity', () {
    expect(
      MetaPixelEvents.dedupeKey(MetaPixelEvents.completeRegistration, 'A@B.com'),
      MetaPixelEvents.dedupeKey(MetaPixelEvents.completeRegistration, 'a@b.com'),
    );
    expect(
      MetaPixelEvents.dedupeKey(MetaPixelEvents.submitApplication, 'uid-1'),
      isNot(
        MetaPixelEvents.dedupeKey(MetaPixelEvents.completeRegistration, 'uid-1'),
      ),
    );
  });
}

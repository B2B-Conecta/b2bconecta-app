import 'package:shared_preferences/shared_preferences.dart';

import 'marketing_consent.dart';
import 'meta_pixel_config.dart';

MarketingConsent _cached = MarketingConsent.unknown;
bool _hydrated = false;

Future<void> hydrateMarketingConsent() async {
  if (_hydrated) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    _cached = MarketingConsentCodec.parse(
      prefs.getString(MetaPixelConfig.consentCookieName),
    );
  } catch (_) {
    _cached = MarketingConsent.unknown;
  }
  _hydrated = true;
}

MarketingConsent readMarketingConsent() => _cached;

void writeMarketingConsent(MarketingConsent consent) {
  if (consent == MarketingConsent.unknown) return;
  _cached = consent;
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString(
      MetaPixelConfig.consentCookieName,
      MarketingConsentCodec.encode(consent),
    );
  });
}

/// Meta Pixel (web) y App Events (Android). El App ID nativo va en `.env`.
abstract final class MetaPixelConfig {
  static const pixelId = '1400120148679047';

  /// Play Store listing for App Ads.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=ve.com.b2bconecta.app';

  static const androidPackageName = 've.com.b2bconecta.app';

  /// Nombre compartido con el sitio institucional (`www` / `app`).
  static const consentCookieName = 'b2b_marketing_consent';

  /// Dominio padre para compartir el consentimiento entre subdominios.
  static const consentCookieDomain = '.b2bconecta.com.ve';

  static const consentMaxAgeSeconds = 180 * 24 * 60 * 60;

  /// App ID de Meta for Developers (Android). Vacío = no se envían App Events.
  static String? resolveFacebookAppId(String? fromEnv) {
    final id = (fromEnv ?? '').trim();
    if (id.isEmpty || id == '0' || id.toUpperCase().contains('YOUR_')) {
      return null;
    }
    return id;
  }
}

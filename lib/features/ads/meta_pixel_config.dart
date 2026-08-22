/// Meta Pixel de B2B Conecta (paso 3: PageView tras cookies de marketing).
abstract final class MetaPixelConfig {
  static const pixelId = '1400120148679047';

  /// Nombre compartido con el sitio institucional (`www` / `app`).
  static const consentCookieName = 'b2b_marketing_consent';

  /// Dominio padre para compartir el consentimiento entre subdominios.
  static const consentCookieDomain = '.b2bconecta.com.ve';

  static const consentMaxAgeSeconds = 180 * 24 * 60 * 60;
}

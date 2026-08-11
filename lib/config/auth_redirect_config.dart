/// URLs de redirect post-auth (recovery, confirmación).
///
/// En web la app usa [Uri.base.origin] en runtime; estas constantes documentan
/// los orígenes que deben permanecer en Supabase Auth → Redirect URLs
/// (`config/supabase-auth-redirects.example`). Móvil sigue usando
/// `.env` → `SUPABASE_AUTH_REDIRECT_URL`.
abstract final class AuthRedirectConfig {
  /// Staging web (Vercel branch `dev`).
  static const stagingWebRedirectUrl =
      'https://b2bconecta-app-git-dev-b2bconecta.vercel.app';

  /// Production web.
  static const productionWebRedirectUrl = 'https://www.b2bconecta.com.ve';

  /// Local Flutter web (`scripts/run_web_local.sh`) — activar con use_env local.
  static const localWebRedirectUrl = 'http://localhost:3000';

  static const mobileScheme = 've.com.b2bconecta.app';
  static const mobileHost = 'auth-callback';
  static const mobileDeepLink = '$mobileScheme://$mobileHost';
}

/// URLs de redirect post-auth (recovery, confirmación). Ver también `.env` →
/// [SUPABASE_AUTH_REDIRECT_URL] y `config/supabase-auth-redirects.example`.
abstract final class AuthRedirectConfig {
  /// Staging web (Vercel branch `dev`). Debe coincidir con:
  /// - `config/env/staging.env`
  /// - Vercel → `SUPABASE_AUTH_REDIRECT_URL`
  /// - Supabase Dashboard (b2bconecta-db-dev) → Auth → Site URL + Redirect URLs
  static const stagingWebRedirectUrl =
      'https://b2bconecta-app-git-dev-b2bconecta.vercel.app';

  /// Production web.
  static const productionWebRedirectUrl = 'https://www.b2bconecta.com.ve';

  /// Local Flutter web (`scripts/run_web_local.sh`).
  static const localWebRedirectUrl = 'http://localhost:3000';

  static const mobileScheme = 'com.carlosf12.motolinkProApp';
  static const mobileHost = 'auth-callback';
  static const mobileDeepLink = '$mobileScheme://$mobileHost';
}

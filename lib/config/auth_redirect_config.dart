/// Deep link para enlaces de correo Supabase Auth (recovery, confirmación) en móvil.
abstract final class AuthRedirectConfig {
  static const mobileScheme = 'com.carlosf12.motolinkProApp';
  static const mobileHost = 'auth-callback';
  static const mobileDeepLink = '$mobileScheme://$mobileHost';
}

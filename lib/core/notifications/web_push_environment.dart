/// Entorno de la app (proyectos Supabase separados = aislamiento real).
enum WebPushEnvironment {
  local,
  dev,
  main,
  unknown,
}

WebPushEnvironment webPushEnvironmentFromSupabaseUrl(String? url) {
  final u = (url ?? '').toLowerCase();
  if (u.contains('127.0.0.1') || u.contains('localhost')) {
    return WebPushEnvironment.local;
  }
  if (u.contains('kdrccmqcrruixuworlmz')) return WebPushEnvironment.dev;
  if (u.contains('fzugzjcwdzcwfxgviltw')) return WebPushEnvironment.main;
  return WebPushEnvironment.unknown;
}

extension WebPushEnvironmentX on WebPushEnvironment {
  String get wireValue => name;
}

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'auth_link_utils.dart';

/// Resuelve la URL de callback Auth al abrir la app (web o deep link nativo).
///
/// En web usa [Uri.base]. En móvil [Uri.base] no refleja el intent de Android/iOS;
/// hay que leer el enlace con `app_links` (mismo mecanismo que Supabase Auth).
Future<Uri?> resolveIncomingAuthCallbackUri() async {
  if (kIsWeb) {
    return hasAuthCallbackInUri(Uri.base) ? Uri.base : null;
  }

  final links = AppLinks();
  try {
    final initial = await links.getInitialLink();
    if (initial != null && hasAuthCallbackInUri(initial)) {
      return initial;
    }
    final latest = await links.getLatestLink();
    if (latest != null && hasAuthCallbackInUri(latest)) {
      return latest;
    }
  } catch (_) {
    // Ignorar: AuthGate continúa con sesión persistida / eventos Auth.
  }
  return null;
}

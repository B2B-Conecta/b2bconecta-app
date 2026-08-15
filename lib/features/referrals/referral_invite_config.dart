import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/app/config/auth_redirect_config.dart';

/// Link y normalización de códigos de referido.
abstract final class ReferralInviteConfig {
  static String normalizeCode(String? raw) {
    final t = raw?.trim().toUpperCase() ?? '';
    if (t.isEmpty) return '';
    return t.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Origen para compartir (web actual o producción).
  static String inviteOrigin() {
    if (kIsWeb) {
      final origin = Uri.base.origin.trim();
      if (origin.isNotEmpty && origin != 'null') return origin;
    }
    return AuthRedirectConfig.productionWebRedirectUrl;
  }

  static String inviteUrlForCode(String code) {
    final c = normalizeCode(code);
    return '${inviteOrigin()}/?ref=$c';
  }

  /// Lee `ref` / `referral` de la URL actual (web).
  static String? codeFromUri(Uri uri) {
    final q = uri.queryParameters;
    final fromQuery = normalizeCode(q['ref'] ?? q['referral']);
    if (fromQuery.isNotEmpty) return fromQuery;
    final frag = uri.fragment;
    if (frag.contains('ref=')) {
      final fake = Uri.tryParse('https://x/?${frag.contains('?') ? frag.split('?').last : frag}');
      final fromFrag = normalizeCode(
        fake?.queryParameters['ref'] ?? fake?.queryParameters['referral'],
      );
      if (fromFrag.isNotEmpty) return fromFrag;
    }
    return null;
  }
}

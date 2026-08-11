import '../config/privacy_policy_config.dart';
import '../config/terms_config.dart';

/// Rutas públicas de documentos legales (sin sesión).
///
/// Web: `https://www.b2bconecta.com.ve/?legal=privacy`
///      `https://www.b2bconecta.com.ve/?legal=terms`
enum PublicLegalKind { privacy, terms }

abstract final class PublicLegalRoute {
  static PublicLegalKind? kindFromUri(Uri uri) {
    final fromQuery = _parseToken(uri.queryParameters['legal']);
    if (fromQuery != null) return fromQuery;

    final page = _parseToken(uri.queryParameters['page']);
    if (page != null) return page;

    // Hash: #/legal/privacy o #legal=privacy
    final frag = uri.fragment.trim();
    if (frag.isEmpty) return null;
    if (frag.contains('legal=')) {
      final fake = Uri.tryParse(
        'https://x/?${frag.contains('?') ? frag.split('?').last : frag}',
      );
      final fromFrag = _parseToken(fake?.queryParameters['legal']);
      if (fromFrag != null) return fromFrag;
    }
    final path = frag.startsWith('/') ? frag.substring(1) : frag;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0] == 'legal') {
      return _parseToken(parts[1]);
    }
    if (parts.length == 1) {
      return _parseToken(parts[0]);
    }
    return null;
  }

  static PublicLegalKind? _parseToken(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'privacy':
      case 'privacidad':
      case 'politica-de-privacidad':
      case 'privacy-policy':
        return PublicLegalKind.privacy;
      case 'terms':
      case 'terminos':
      case 'terms-of-service':
      case 'tyc':
        return PublicLegalKind.terms;
      default:
        return null;
    }
  }

  static String titleFor(PublicLegalKind kind) {
    return switch (kind) {
      PublicLegalKind.privacy => PrivacyPolicyConfig.title,
      PublicLegalKind.terms => TermsConfig.title,
    };
  }

  static String bodyFor(PublicLegalKind kind) {
    return switch (kind) {
      PublicLegalKind.privacy => PrivacyPolicyConfig.body,
      PublicLegalKind.terms => TermsConfig.body,
    };
  }

  /// Query para enlaces internos / Play Console.
  static String queryFor(PublicLegalKind kind) {
    return switch (kind) {
      PublicLegalKind.privacy => 'legal=privacy',
      PublicLegalKind.terms => 'legal=terms',
    };
  }
}

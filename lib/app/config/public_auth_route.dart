/// Rutas públicas de autenticación (sin sesión).
///
/// Web: `https://app.b2bconecta.com.ve/registro`
///      `http://localhost:3000/registro`
///      respaldo: `?registro=1`
abstract final class PublicAuthRoute {
  static const path = '/registro';

  /// Navigator / anuncios: abrir registro si la URI o el nombre de ruta lo dicen.
  static bool shouldOpenRegister({Uri? launchUri, String? routeName}) {
    if (launchUri != null && isRegister(launchUri)) return true;
    if (routeName != null && routeName.isNotEmpty) {
      final path = routeName.startsWith('/') ? routeName : '/$routeName';
      if (isRegister(Uri.parse('https://app.b2bconecta.com.ve$path'))) {
        return true;
      }
    }
    return false;
  }

  static bool isRegister(Uri uri) {
    if (_pathIsRegister(uri.pathSegments)) return true;

    final q = uri.queryParameters['registro']?.trim().toLowerCase();
    if (q == '1' || q == 'true' || q == 'si' || q == 'yes') return true;

    final frag = uri.fragment.trim();
    if (frag.isEmpty) return false;
    if (frag.contains('registro=')) {
      final fake = Uri.tryParse(
        'https://x/?${frag.contains('?') ? frag.split('?').last : frag}',
      );
      final fromFrag = fake?.queryParameters['registro']?.trim().toLowerCase();
      if (fromFrag == '1' ||
          fromFrag == 'true' ||
          fromFrag == 'si' ||
          fromFrag == 'yes') {
        return true;
      }
    }
    final path = frag.startsWith('/') ? frag.substring(1) : frag;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return _pathIsRegister(parts);
  }

  static bool _pathIsRegister(Iterable<String> segments) {
    final parts = segments.where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty && parts.first.toLowerCase() == 'registro';
  }
}

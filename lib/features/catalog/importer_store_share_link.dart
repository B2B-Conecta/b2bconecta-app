import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'product_share_link.dart';

/// Enlace público de la vitrina: `{sitio}/vitrina/{id}`.
///
/// Solo el id del importador. Sin token, sesión ni datos privados.
abstract final class ImporterStoreShareLink {
  static const segment = 'vitrina';

  static const _prefKey = 'pending_store_share_id';

  static final pending = ValueNotifier<String?>(null);

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String urlFor(String importerId) =>
      '${ProductShareLink.origin}/$segment/${importerId.trim()}';

  static String? idFromUri(Uri? uri) {
    if (uri == null) return null;
    final fromPath = _idFromSegments(uri.pathSegments);
    if (fromPath != null) return fromPath;
    final frag = uri.fragment.trim();
    if (frag.isEmpty) return null;
    final path = frag.startsWith('/') ? frag : '/$frag';
    return idFromUri(Uri.parse('${ProductShareLink.origin}$path'));
  }

  static String? idFromRouteName(String? name) {
    final raw = name?.trim() ?? '';
    if (raw.isEmpty) return null;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return idFromUri(Uri.parse('${ProductShareLink.origin}$path'));
  }

  static String? _idFromSegments(Iterable<String> raw) {
    final segments = raw.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    if (segments.first.toLowerCase() != segment) return null;
    final id = segments[1].trim();
    if (!_uuid.hasMatch(id)) return null;
    return id;
  }

  /// El QR solo lleva la ruta pública.
  static bool urlIsPublic(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.queryParameters.isNotEmpty) return false;
    if (uri.fragment.isNotEmpty) return false;
    return idFromUri(uri) != null;
  }

  static Future<void> capture(Uri? uri) async {
    if (uri == null) return;
    final id = idFromUri(uri);
    if (id == null) return;
    pending.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id);
  }

  static Future<void> restore() async {
    if (pending.value != null) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey)?.trim();
    if (stored != null && _uuid.hasMatch(stored)) {
      pending.value = stored;
    }
  }

  static Future<String?> take() async {
    final id = pending.value;
    pending.value = null;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey)?.trim();
    await prefs.remove(_prefKey);
    if (id != null && id.isNotEmpty) return id;
    if (stored != null && _uuid.hasMatch(stored)) return stored;
    return null;
  }
}

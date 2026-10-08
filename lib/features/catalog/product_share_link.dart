import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enlace estable a la ficha: `https://app.b2bconecta.com.ve/producto/{id}`.
///
/// El id queda guardado hasta que el usuario entra a la app. Así el registro
/// o el inicio de sesión no pierden el producto.
abstract final class ProductShareLink {
  static const origin = 'https://app.b2bconecta.com.ve';
  static const _prefKey = 'pending_product_share_id';

  static final pending = ValueNotifier<String?>(null);

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String urlFor(String productId) => '$origin/producto/${productId.trim()}';

  static String? idFromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first.toLowerCase() == 'producto') {
      final id = segments[1].trim();
      if (_uuid.hasMatch(id)) return id;
    }
    final frag = uri.fragment.trim();
    if (frag.isNotEmpty) {
      final path = frag.startsWith('/') ? frag : '/$frag';
      final fromFrag = idFromUri(Uri.parse('https://app.b2bconecta.com.ve$path'));
      if (fromFrag != null) return fromFrag;
    }
    return null;
  }

  static String? idFromRouteName(String? name) {
    final raw = name?.trim() ?? '';
    if (raw.isEmpty) return null;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return idFromUri(Uri.parse('$origin$path'));
  }

  /// Guarda el destino si la URI es una ficha. No borra un destino previo.
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

  /// Lee y limpia el destino pendiente.
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

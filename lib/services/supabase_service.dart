import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/part_model.dart';
import '../models/profile_model.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _currentUserId =>
      _client.auth.currentUser?.id;

  /// Perfil del usuario autenticado (`id` = `auth.uid()`). `null` si no hay fila.
  static Future<ProfileModel?> fetchMyProfile() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;
    return ProfileModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Crea o actualiza el perfil B2B (upsert por `id`).
  static Future<void> upsertMyProfile({
    required String businessName,
    required String rif,
    required String role,
    String? phone,
  }) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw StateError('No hay sesión activa.');
    }

    final payload = <String, dynamic>{
      'id': uid,
      'business_name': businessName.trim(),
      'rif': rif.trim(),
      'role': role.trim(),
    };
    final p = phone?.trim();
    if (p != null && p.isNotEmpty) {
      payload['phone'] = p;
    }

    await _client.from('profiles').upsert(payload);
  }

  /// Número total de filas en `products` (respeta RLS del usuario).
  static Future<int> fetchProductsCount() async {
    final n = await _client.from('products').count(CountOption.exact);
    return n;
  }

  /// Obtiene repuestos desde [products] con paginacion.
  /// Incluye nombre del importador vía FK `owner_id` → `profiles`.
  static Future<List<PartModel>> fetchParts({
    int limit = 6,
    int offset = 0,
  }) async {
    final response = await _client
        .from('products')
        .select('*, profiles(business_name)')
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    final list = response as List<dynamic>;
    return list
        .map((row) => PartModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

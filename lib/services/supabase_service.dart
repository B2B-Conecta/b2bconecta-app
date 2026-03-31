import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_filters.dart';
import '../models/part_model.dart';
import '../models/profile_model.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _currentUserId => _client.auth.currentUser?.id;

  /// Perfil del usuario autenticado (`id` = `auth.uid()`). `null` si no hay fila.
  static Future<ProfileModel?> fetchMyProfile() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final data =
        await _client.from('profiles').select().eq('id', uid).maybeSingle();

    if (data == null) return null;
    return ProfileModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Crea o actualiza el perfil B2B (upsert por `id`).
  ///
  /// El campo [role] solo se persiste si el perfil aún no tiene rol definido
  /// (`importador` / `aliado`). Tras la primera asignación, los updates omiten
  /// `role` para que no pueda cambiarse desde el cliente.
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

    final existing = await fetchMyProfile();
    final existingRole = existing?.role?.trim().toLowerCase();
    final roleAlreadySet =
        existingRole == 'importador' || existingRole == 'aliado';

    final payload = <String, dynamic>{
      'id': uid,
      'business_name': businessName.trim(),
      'rif': rif.trim(),
    };
    if (!roleAlreadySet) {
      payload['role'] = role.trim();
    }

    final p = phone?.trim();
    if (p != null && p.isNotEmpty) {
      payload['phone'] = p;
    }

    await _client.from('profiles').upsert(payload);
  }

  /// Importadores (`role = importador`) para el filtro del catálogo.
  /// Requiere lectura en `profiles` según RLS del proyecto.
  static Future<List<ImporterOption>> fetchImporterOptions() async {
    final response = await _client
        .from('profiles')
        .select('id, business_name')
        .eq('role', 'importador')
        .order('business_name', ascending: true);
    final list = response as List<dynamic>;
    return list
        .map((row) {
          final m = Map<String, dynamic>.from(row as Map);
          final id = m['id']?.toString() ?? '';
          final name = m['business_name']?.toString().trim() ?? '';
          return ImporterOption(id: id, businessName: name);
        })
        .where((o) => o.id.isNotEmpty && o.businessName.isNotEmpty)
        .toList();
  }

  /// Número total de filas que cumplen [filters] (respeta RLS).
  static Future<int> fetchProductsCount({CatalogFilters? filters}) async {
    final f = filters ?? CatalogFilters.empty;
    if (!f.hasAnyFilter) {
      final n = await _client.from('products').count(CountOption.exact);
      return n;
    }
    dynamic q = _client.from('products').select('id');
    q = _applyCatalogFilters(q, f);
    final res = await q.count(CountOption.exact);
    return (res as PostgrestResponse<dynamic>).count;
  }

  /// Obtiene repuestos desde [products] con paginacion.
  /// Incluye nombre del importador vía FK `owner_id` → `profiles`.
  static Future<List<PartModel>> fetchParts({
    int limit = 6,
    int offset = 0,
    CatalogFilters? filters,
  }) async {
    final f = filters ?? CatalogFilters.empty;
    dynamic query =
        _client.from('products').select('*, profiles(business_name)');
    query = _applyCatalogFilters(query, f);
    final response = await query
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    final list = response as List<dynamic>;
    return list
        .map((row) => PartModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Evita que `%` y `_` del usuario actúen como comodines en `ilike`.
  static String _sanitizeIlike(String input) {
    return input.replaceAll('%', ' ').replaceAll('_', ' ');
  }

  static dynamic _applyCatalogFilters(
    dynamic query,
    CatalogFilters filters,
  ) {
    var q = query;
    final search = filters.searchQuery?.trim();
    if (search != null && search.isNotEmpty) {
      final safe = _sanitizeIlike(search);
      q = q.ilike('name', '%$safe%');
    }
    if (filters.ownerId != null && filters.ownerId!.trim().isNotEmpty) {
      q = q.eq('owner_id', filters.ownerId!.trim());
    }
    if (filters.minPrice != null) {
      q = q.gte('price_usd', filters.minPrice!);
    }
    if (filters.maxPrice != null) {
      q = q.lte('price_usd', filters.maxPrice!);
    }
    return q;
  }
}

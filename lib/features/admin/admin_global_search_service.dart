import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Resultado unificado de la paleta ⌘K (usuarios / pedidos / productos).
class AdminGlobalSearchResult {
  const AdminGlobalSearchResult({
    this.users = const [],
    this.orders = const [],
    this.products = const [],
  });

  final List<ProfileModel> users;
  final List<TransactionRequestModel> orders;
  final List<PartModel> products;

  bool get isEmpty =>
      users.isEmpty && orders.isEmpty && products.isEmpty;
}

/// Consultas paralelas / RPC `admin_global_search` para el Command Palette admin.
abstract final class AdminGlobalSearchService {
  static const int defaultLimit = 5;

  /// Cache ligera de perfiles para el fallback client-side.
  static List<ProfileModel>? _profilesCache;
  static DateTime? _profilesCacheAt;

  static Future<AdminGlobalSearchResult> search(
    String raw, {
    int limit = defaultLimit,
  }) async {
    final q = raw.trim();
    if (q.length < 2) return const AdminGlobalSearchResult();

    try {
      final res = await SupabaseAccess.client.rpc(
        'admin_global_search',
        params: <String, dynamic>{
          'p_search_term': q,
          'p_limit': limit,
        },
      );
      if (res is Map) {
        return _fromRpc(Map<String, dynamic>.from(res), limit: limit);
      }
    } catch (_) {
      // Migración aún no aplicada → fallback local.
    }
    return _searchFallback(q, limit: limit);
  }

  static AdminGlobalSearchResult _fromRpc(
    Map<String, dynamic> json, {
    required int limit,
  }) {
    final usersRaw = json['users'];
    final ordersRaw = json['orders'];
    final productsRaw = json['products'];

    final users = <ProfileModel>[];
    if (usersRaw is List) {
      for (final e in usersRaw.take(limit)) {
        if (e is! Map) continue;
        users.add(ProfileModel.fromJson(Map<String, dynamic>.from(e)));
      }
    }

    final orders = <TransactionRequestModel>[];
    if (ordersRaw is List) {
      for (final e in ordersRaw.take(limit)) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        // RPC aplana nombres; adapta al shape de fromJson.
        if (map['aliado'] == null && map['aliado_business_name'] != null) {
          map['aliado'] = {
            'business_name': map['aliado_business_name'],
          };
        }
        if (map['importador'] == null && map['owner_business_name'] != null) {
          map['importador'] = {
            'business_name': map['owner_business_name'],
          };
        }
        if (map['products'] == null &&
            (map['product_name'] != null || map['product_sku'] != null)) {
          map['products'] = {
            'name': map['product_name'],
            'sku': map['product_sku'],
          };
        }
        if (map['precio_total_usd'] != null && map['precio_total'] == null) {
          // fromJson lee precio_total_usd
        }
        try {
          orders.add(TransactionRequestModel.fromJson(map));
        } catch (_) {
          // Fila incompleta: omitir.
        }
      }
    }

    final products = <PartModel>[];
    if (productsRaw is List) {
      for (final e in productsRaw.take(limit)) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        // PartModel.fromJson espera name/price_usd + profiles join.
        map.putIfAbsent('name', () => map['nombre']);
        map.putIfAbsent('price_usd', () => map['precio']);
        if (map['profiles'] == null && map['owner_business_name'] != null) {
          map['profiles'] = {
            'business_name': map['owner_business_name'],
          };
        }
        try {
          products.add(PartModel.fromJson(map));
        } catch (_) {}
      }
    }

    return AdminGlobalSearchResult(
      users: users,
      orders: orders,
      products: products,
    );
  }

  static Future<AdminGlobalSearchResult> _searchFallback(
    String q, {
    required int limit,
  }) async {
    final results = await Future.wait<Object>([
      _searchUsersFallback(q, limit: limit),
      _searchOrdersFallback(q, limit: limit),
      SupabaseService.fetchParts(
        limit: limit,
        filters: CatalogFilters(searchQuery: q),
      ),
    ]);
    return AdminGlobalSearchResult(
      users: results[0] as List<ProfileModel>,
      orders: results[1] as List<TransactionRequestModel>,
      products: (results[2] as List<PartModel>).take(limit).toList(),
    );
  }

  static Future<List<ProfileModel>> _searchUsersFallback(
    String q, {
    required int limit,
  }) async {
    final now = DateTime.now();
    final cacheAge = _profilesCacheAt == null
        ? null
        : now.difference(_profilesCacheAt!);
    if (_profilesCache == null ||
        cacheAge == null ||
        cacheAge > const Duration(minutes: 2)) {
      _profilesCache = await SupabaseService.ownerListProfiles();
      _profilesCacheAt = now;
    }
    final out = <ProfileModel>[];
    for (final p in _profilesCache!) {
      if (!_profileMatches(p, q)) continue;
      out.add(p);
      if (out.length >= limit) break;
    }
    return out;
  }

  static bool _profileMatches(ProfileModel p, String q) {
    if (ownerAccountMatchesQuery(p, q)) return true;
    final lower = q.toLowerCase();
    final cedula = (p.cedula ?? '').toLowerCase();
    if (cedula.isNotEmpty && cedula.contains(lower)) return true;
    final id = p.id.toLowerCase();
    if (id.contains(lower)) return true;
    return false;
  }

  static Future<List<TransactionRequestModel>> _searchOrdersFallback(
    String q, {
    required int limit,
  }) async {
    // Ventana reciente + filtro en cliente (evita traer toda la bandeja).
    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select(
          '''
          id,
          status,
          checkout_group_id,
          precio_total_usd,
          product_id,
          updated_at,
          products ( name, sku ),
          aliado:profiles!transaction_requests_aliado_id_fkey ( business_name, rif ),
          importador:profiles!transaction_requests_importador_id_fkey ( business_name, rif )
          ''',
        )
        .inFilter(
          'status',
          TransactionRequestStatus.adminBandejaUnifiedStatuses,
        )
        .order('updated_at', ascending: false)
        .limit(120);

    final out = <TransactionRequestModel>[];
    for (final row in (response as List<dynamic>)) {
      final r = TransactionRequestModel.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      if (!TransactionRequestFilterUtils.matchesSearch(r, q)) continue;
      out.add(r);
      if (out.length >= limit) break;
    }
    return out;
  }
}

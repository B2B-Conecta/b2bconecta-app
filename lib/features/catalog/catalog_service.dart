import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/jwt_clock_skew.dart';
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/promo_campaign_model.dart';
import 'package:motolink_pro_app/features/catalog/catalog_ranking.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';
import 'package:motolink_pro_app/features/inventory/importer_sales_snapshot.dart';
import 'package:motolink_pro_app/core/utils/haversine.dart';

class CatalogService {
  CatalogService._();

  static Future<List<ImporterOption>> fetchImporterOptions() async {
    return retryOnJwtIssuedAtFuture(() async {
    final response = await SupabaseAccess.client
        .from('profiles')
        .select('id, business_name, estado, ciudad, catalog_featured_until')
        .eq('role', 'importador')
        .order('business_name', ascending: true);
    final list = response as List<dynamic>;
    return list
        .map((row) {
          final m = Map<String, dynamic>.from(row as Map);
          final id = m['id']?.toString() ?? '';
          final name = m['business_name']?.toString().trim() ?? '';
          return ImporterOption(
            id: id,
            businessName: name,
            estado: m['estado']?.toString(),
            ciudad: m['ciudad']?.toString(),
            catalogFeaturedUntil: m['catalog_featured_until'] != null
                ? DateTime.tryParse(m['catalog_featured_until'].toString())
                : null,
          );
        })
        .where((o) => o.id.isNotEmpty && o.businessName.isNotEmpty)
        .toList();
    });
  }

  /// Catálogo publicado de un mayorista para el panel admin.
  ///
  /// Publicado = `products.is_active` (visible; no está en pausa).
  /// No filtra `stock_covers_min_order`: eso es si se puede comprar, no si está publicado.
  /// La RLS de `products` solo deja leer ajenos cuando `is_active` es verdadero.
  static Future<List<PartModel>> fetchAdminPublishedCatalog({
    required String importerId,
    int limit = 40,
    int offset = 0,
  }) {
    final id = importerId.trim();
    if (id.isEmpty) return Future<List<PartModel>>.value(const []);
    final page = limit < 1 ? 1 : limit;
    final start = offset < 0 ? 0 : offset;
    return retryOnJwtIssuedAtFuture(() async {
      final response = await SupabaseAccess.client
          .from('products')
          .select(
            'id, owner_id, name, sku, category, price_usd, sale_price_usd, '
            'image_url, image_urls, is_active, stock',
          )
          .eq('owner_id', id)
          .eq('is_active', true)
          .order('name', ascending: true)
          .range(start, start + page - 1);
      final list = response as List<dynamic>;
      return list
          .map(
            (row) => PartModel.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .where(
            (part) => catalogPartBelongsToImporterStore(
              importerId: id,
              ownerId: part.ownerId,
              isActive: part.isActive,
            ),
          )
          .toList();
    });
  }

  /// Dueños con al menos un producto publicado (`is_active`).
  static Future<Set<String>> fetchPublishedCatalogOwnerIds() {
    return retryOnJwtIssuedAtFuture(() async {
      final ids = <String>{};
      var start = 0;
      const page = 1000;
      while (start < 20000) {
        final response = await SupabaseAccess.client
            .from('products')
            .select('owner_id')
            .eq('is_active', true)
            .range(start, start + page - 1);
        final list = response as List<dynamic>;
        for (final row in list) {
          final id = (row as Map)['owner_id']?.toString().trim() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
        if (list.length < page) break;
        start += page;
      }
      return ids;
    });
  }

  /// Número total de filas que cumplen [filters] (respeta RLS).
  static Future<int> fetchProductsCount({CatalogFilters? filters}) {
    return retryOnJwtIssuedAtFuture(() => _fetchProductsCount(filters: filters));
  }

  static Future<int> _fetchProductsCount({CatalogFilters? filters}) async {
    final f = filters ?? CatalogFilters.empty;
    final searchPlan = await _resolveCatalogSearch(f);
    if (searchPlan.isEmptyResult) return 0;
    final embed = _catalogProfileSelect(f);
    final ids = searchPlan.productIds;
    if (ids != null && ids.length > _maxInFilterIds) {
      var total = 0;
      for (var i = 0; i < ids.length; i += _maxInFilterIds) {
        final end = (i + _maxInFilterIds).clamp(0, ids.length);
        dynamic q = SupabaseAccess.client.from('products').select('id, $embed');
        q = _applyCatalogFilters(
          q,
          f,
          searchLocationImporterIds: searchPlan.locationImporterIds,
          searchProductIds: ids.sublist(i, end),
          legacySearchVariants: searchPlan.legacySearchVariants,
        );
        final res = await q.count(CountOption.exact);
        total += (res as PostgrestResponse<dynamic>).count;
      }
      return total;
    }
    dynamic q = SupabaseAccess.client.from('products').select('id, $embed');
    q = _applyCatalogFilters(
      q,
      f,
      searchLocationImporterIds: searchPlan.locationImporterIds,
      searchProductIds: ids,
      legacySearchVariants: searchPlan.legacySearchVariants,
    );
    final res = await q.count(CountOption.exact);
    return (res as PostgrestResponse<dynamic>).count;
  }

  static bool _catalogNeedsProfileInner(CatalogFilters filters) {
    final sq = filters.searchQuery?.trim();
    final oe = filters.ownerEstado?.trim();
    final oc = filters.ownerCiudad?.trim();
    return (sq != null && sq.isNotEmpty) ||
        (oe != null && oe.isNotEmpty) ||
        (oc != null && oc.isNotEmpty) ||
        filters.hasReputationThreshold;
  }

  static String _catalogProfileSelect(CatalogFilters filters) {
    const rep =
        'rating_avg_received_rolling100, rating_count_received_rolling100, catalog_paid_orders_30d, min_order_amount_ref, min_order_currency, catalog_featured_until, catalog_verified_at';
    return _catalogNeedsProfileInner(filters)
        ? 'profiles!inner(business_name, logo_storage_path, estado, ciudad, latitude, longitude, pago_solo_divisas, $rep)'
        : 'profiles(business_name, logo_storage_path, estado, ciudad, latitude, longitude, pago_solo_divisas, $rep)';
  }

  static Future<List<PromoCampaignModel>>
      fetchActivePromoCampaignsForAliado() async {
    final res = await SupabaseAccess.client
        .rpc('get_active_promo_campaigns_for_aliado');
    final list = SupabaseAccess.decodeRpcJsonArray(res);
    return list
        .map((e) => PromoCampaignModel.fromAliadoRpcJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .where((c) => c.id.isNotEmpty && c.imagePublicUrl.trim().isNotEmpty)
        .toList();
  }

  /// Mapa product_id → {campaign_id, discount_percent} de vallas vigentes.
  static Future<Map<String, ({String campaignId, double percent})>>
      fetchActivePromoProductDiscounts() async {
    try {
      final res = await SupabaseAccess.client
          .rpc('get_active_promo_product_discounts');
      if (res is! Map) return const {};
      final out = <String, ({String campaignId, double percent})>{};
      res.forEach((key, value) {
        if (value is! Map) return;
        final id = key.toString().trim();
        if (id.isEmpty) return;
        final pct = PromoCampaignModel.parseDiscountPercent(
          value['discount_percent'],
        );
        final camp = value['campaign_id']?.toString().trim() ?? '';
        if (pct == null || camp.isEmpty) return;
        out[id] = (campaignId: camp, percent: pct);
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  static List<PartModel> applyPromoDiscountsToParts(
    List<PartModel> parts,
    Map<String, ({String campaignId, double percent})> discounts,
  ) {
    if (discounts.isEmpty || parts.isEmpty) return parts;
    return parts
        .map((p) {
          final hit = discounts[p.id];
          if (hit == null) return p;
          return p.copyWith(
            activeCampaignDiscountPercent: hit.percent,
            activePromoCampaignId: hit.campaignId,
          );
        })
        .toList();
  }

  static Future<List<PromoCampaignModel>>
      fetchActivePromoCampaignsForImportador() async {
    final res = await SupabaseAccess.client
        .rpc('get_active_promo_campaigns_for_importador');
    final list = SupabaseAccess.decodeRpcJsonArray(res);
    return list
        .map((e) => PromoCampaignModel.fromImportadorRpcJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  static Future<List<ImporterSalesSnapshot>>
      adminListImporterSalesSnapshots({int days = 30}) async {
    final res = await SupabaseAccess.client.rpc(
      'admin_list_importer_sales_snapshots',
      params: <String, dynamic>{'p_days': days},
    );
    final list = SupabaseAccess.decodeRpcJsonArray(res);
    return list
        .whereType<Map>()
        .map((e) => ImporterSalesSnapshot.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  /// Admin: sello Destacado 7/15/30 días, o 0 para quitar.
  static Future<DateTime?> adminSetImporterCatalogFeatured({
    required String importadorId,
    required int days,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'admin_set_importer_catalog_featured',
      params: <String, dynamic>{
        'p_importador_id': importadorId,
        'p_days': days,
      },
    );
    if (res == null) return null;
    return DateTime.tryParse(res.toString());
  }

  /// Admin: sello Verificado (registro oficial) on/off.
  static Future<DateTime?> adminSetImporterCatalogVerified({
    required String importadorId,
    required bool verified,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'admin_set_importer_catalog_verified',
      params: <String, dynamic>{
        'p_importador_id': importadorId,
        'p_verified': verified,
      },
    );
    if (res == null) return null;
    return DateTime.tryParse(res.toString());
  }

  /// Vallas publicitarias de terceros visibles para importadores.
  static Future<List<PromoCampaignModel>>
      fetchActivePromoCampaignsForImportadorAds() async {
    final res = await SupabaseAccess.client
        .rpc('get_active_promo_campaigns_for_importador_ads');
    final list = SupabaseAccess.decodeRpcJsonArray(res);
    return list
        .map((e) => PromoCampaignModel.fromAliadoRpcJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .where((c) => c.id.isNotEmpty && c.imagePublicUrl.trim().isNotEmpty)
        .toList();
  }

  /// E1.2: listado admin de campañas.
  static Future<List<PromoCampaignModel>> fetchPromoCampaignsAdmin() async {
    final res = await SupabaseAccess.client
        .from('promo_campaigns')
        .select()
        .order('priority', ascending: false)
        .order('created_at', ascending: false);
    final list = res as List<dynamic>;
    return list
        .map((row) =>
            PromoCampaignModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  static Future<PromoCampaignModel> insertPromoCampaign({
    required PromoCampaignModel draft,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final payload = draft.toInsertJson(createdBy: uid);
    final row = await SupabaseAccess.client
        .from('promo_campaigns')
        .insert(payload)
        .select()
        .single();
    return PromoCampaignModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<PromoCampaignModel> updatePromoCampaign({
    required String id,
    required PromoCampaignModel draft,
  }) async {
    final row = await SupabaseAccess.client
        .from('promo_campaigns')
        .update(draft.toUpdateJson())
        .eq('id', id)
        .select()
        .single();
    return PromoCampaignModel.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<void> deletePromoCampaign({
    required String id,
    String? imageStoragePath,
  }) async {
    final path = imageStoragePath?.trim();
    if (path != null && path.isNotEmpty) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.promoCampaignsBucket)
            .remove([path]);
      } catch (_) {}
    }
    await SupabaseAccess.client.from('promo_campaigns').delete().eq('id', id);
  }

  /// Sube creativo al bucket [promo-campaigns] (solo admin vía RLS).
  static Future<({String path, String publicUrl})> uploadPromoCampaignImage({
    required Uint8List bytes,
    required String fileExtension,
    String? campaignId,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    if (bytes.isEmpty) {
      throw ArgumentError('La imagen está vacía. Pruebe otro archivo.');
    }

    var ext = fileExtension.replaceAll('.', '').toLowerCase();
    if (ext == 'jpg') ext = 'jpeg';
    const allowed = {'jpeg', 'png', 'webp'};
    if (!allowed.contains(ext)) {
      throw ArgumentError('Usa JPG, PNG o WEBP.');
    }

    final idPart =
        (campaignId != null && campaignId.isNotEmpty) ? campaignId : 'nueva';
    final path = '$uid/$idPart/${DateTime.now().microsecondsSinceEpoch}.$ext';

    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    try {
      await SupabaseAccess.client.storage
          .from(SupabaseAccess.promoCampaignsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
    } on StorageException catch (e) {
      final hint =
          e.statusCode == '404' || e.message.contains('Bucket not found')
              ? ' Aplique las migraciones Supabase (bucket promo-campaigns).'
              : '';
      throw StateError(
        'No se pudo subir la imagen (${e.statusCode ?? '?'}): '
        '${e.message}.$hint',
      );
    }

    final publicUrl = SupabaseAccess.client.storage
        .from(SupabaseAccess.promoCampaignsBucket)
        .getPublicUrl(path);
    return (path: path, publicUrl: publicUrl);
  }

  static Future<List<PartModel>> fetchParts({
    int limit = 6,
    int offset = 0,
    CatalogFilters? filters,
  }) {
    return retryOnJwtIssuedAtFuture(
      () => _fetchParts(limit: limit, offset: offset, filters: filters),
    );
  }

  static Future<List<PartModel>> _fetchParts({
    int limit = 6,
    int offset = 0,
    CatalogFilters? filters,
  }) async {
    final f = filters ?? CatalogFilters.empty;
    final searchPlan = await _resolveCatalogSearch(f);
    if (searchPlan.isEmptyResult) return [];
    final embed = _catalogProfileSelect(f);
    const cap = 800;
    final list = await _fetchCatalogProductRows(
      embed: embed,
      filters: f,
      searchPlan: searchPlan,
      rowCap: cap,
    );
    final promoDiscounts = await fetchActivePromoProductDiscounts();

    if (f.sortByDistanceFromReference) {
      final refLat = f.sortReferenceLat!;
      final refLng = f.sortReferenceLng!;
      final distanceCompare = comparePartsByDistanceThenCatalogBoost;
      final withDist = constrainCatalogPartsToFilters(
        list.map((row) {
          final p = PartModel.fromJson(row as Map<String, dynamic>);
          final km = Haversine.distanceKm(
            refLat,
            refLng,
            p.ownerLatitude,
            p.ownerLongitude,
          );
          return p.copyWith(distanceKmFromReference: km);
        }),
        f,
      )..sort(distanceCompare);
      if (offset >= withDist.length) return [];
      final end = (offset + limit).clamp(0, withDist.length);
      return applyPromoDiscountsToParts(
        withDist.sublist(offset, end),
        promoDiscounts,
      );
    }

    final parts = constrainCatalogPartsToFilters(
      list.map((row) => PartModel.fromJson(row as Map<String, dynamic>)),
      f,
    );
    if (searchPlan.productScores.isNotEmpty) {
      // Con búsqueda textual: priorizar relevancia RPC, el modo de orden como desempate.
      parts.sort((a, b) {
        final sa = searchPlan.productScores[a.id] ?? 0;
        final sb = searchPlan.productScores[b.id] ?? 0;
        final byScore = sb.compareTo(sa);
        if (byScore != 0) return byScore;
        return comparePartsForSortMode(a, b, f.sortMode);
      });
    } else {
      parts.sort((a, b) => comparePartsForSortMode(a, b, f.sortMode));
    }
    if (offset >= parts.length) return [];
    final end = (offset + limit).clamp(0, parts.length);
    return applyPromoDiscountsToParts(
      parts.sublist(offset, end),
      promoDiscounts,
    );
  }

  /// Carga filas del catálogo; parte `id.in` en lotes para no saturar la URL.
  static Future<List<dynamic>> _fetchCatalogProductRows({
    required String embed,
    required CatalogFilters filters,
    required _CatalogSearchPlan searchPlan,
    required int rowCap,
  }) async {
    final ids = searchPlan.productIds;
    if (ids == null || ids.length <= _maxInFilterIds) {
      dynamic query =
          SupabaseAccess.client.from('products').select('*, $embed');
      query = _applyCatalogFilters(
        query,
        filters,
        searchLocationImporterIds: searchPlan.locationImporterIds,
        searchProductIds: ids,
        legacySearchVariants: searchPlan.legacySearchVariants,
      );
      final response = await query.limit(rowCap);
      return response as List<dynamic>;
    }

    final out = <dynamic>[];
    final seen = <String>{};
    for (var i = 0;
        i < ids.length && out.length < rowCap;
        i += _maxInFilterIds) {
      final end = (i + _maxInFilterIds).clamp(0, ids.length);
      dynamic query =
          SupabaseAccess.client.from('products').select('*, $embed');
      query = _applyCatalogFilters(
        query,
        filters,
        searchLocationImporterIds: searchPlan.locationImporterIds,
        searchProductIds: ids.sublist(i, end),
        legacySearchVariants: searchPlan.legacySearchVariants,
      );
      final response = await query.limit(rowCap - out.length);
      for (final row in response as List<dynamic>) {
        if (row is! Map) continue;
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty && !seen.add(id)) continue;
        out.add(row);
        if (out.length >= rowCap) break;
      }
    }
    return out;
  }

  /// Evita que `%` y `_` del usuario actúen como comodines en `ilike`.

  /// Variantes ligeras ES (plural/singular) para búsqueda cuando la RPC no está
  /// disponible o como refuerzo del fallback `ilike`.
  static List<String> _catalogSearchTextVariants(String raw) {
    final folded = raw
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    if (folded.isEmpty) return const [];
    final out = <String>{folded};
    if (folded.length > 4 && folded.endsWith('es')) {
      final stem = folded.substring(0, folded.length - 2);
      if (stem.length >= 3) out.add(stem);
    } else if (folded.length > 4 &&
        folded.endsWith('s') &&
        !folded.endsWith('us') &&
        !folded.endsWith('is')) {
      final stem = folded.substring(0, folded.length - 1);
      if (stem.length >= 3) out.add(stem);
    } else if (folded.length >= 4 && !folded.endsWith('s')) {
      out.add('${folded}s');
      if (RegExp(r'[aeiou]$').hasMatch(folded)) {
        out.add('${folded}es');
      }
    }
    return out.toList();
  }

  /// PostgREST no puede parsear `profiles.estado` / `profiles.ciudad` dentro de
  /// un `or` en `products` (PGRST100). Buscamos importadores cuyo estado o
  /// ciudad coincidan y unimos con `owner_id.in.(…)`.
  static const _maxSearchLocationImporterIds = 120;
  static const _maxFuzzySearchProductIds = 800;

  /// Tope por request `id=in.(…)` para no exceder límites de URL de PostgREST.
  static const _maxInFilterIds = 100;

  /// Plan de búsqueda del catálogo: IDs fuzzy (RPC) o fallback legacy `ilike`.
  static Future<_CatalogSearchPlan> _resolveCatalogSearch(
    CatalogFilters filters,
  ) async {
    final search = filters.searchQuery?.trim();
    if (search == null || search.isEmpty) {
      return const _CatalogSearchPlan();
    }
    final safe = SupabaseAccess.sanitizeIlike(search);
    if (safe.isEmpty) {
      return const _CatalogSearchPlan();
    }

    try {
      final res = await SupabaseAccess.client.rpc(
        'search_catalog_product_ids',
        params: {
          'p_query': safe,
          'p_limit': _maxFuzzySearchProductIds,
          'p_similarity_threshold': 0.45,
        },
      );
      final list = res as List<dynamic>? ?? const [];
      final ids = <String>[];
      final scores = <String, double>{};
      final seen = <String>{};
      for (final row in list) {
        if (row is! Map) continue;
        final id = row['product_id']?.toString().trim() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        ids.add(id);
        final rawScore = row['score'];
        final score = rawScore is num
            ? rawScore.toDouble()
            : double.tryParse(rawScore?.toString() ?? '') ?? 0;
        scores[id] = score;
      }
      // RPC respondió: lista vacía = sin resultados (no caer a ilike literal).
      return _CatalogSearchPlan(productIds: ids, productScores: scores);
    } catch (_) {
      // Migración no aplicada en el proyecto al que apunta `.env` (p.ej. staging).
      final locIds = await _importerProfileIdsForSearchLocation(filters);
      return _CatalogSearchPlan(
        locationImporterIds: locIds,
        legacySearchVariants: _catalogSearchTextVariants(safe),
      );
    }
  }

  static Future<List<String>> _importerProfileIdsForSearchLocation(
    CatalogFilters filters,
  ) async {
    final search = filters.searchQuery?.trim();
    if (search == null || search.isEmpty) return const [];
    final safe = SupabaseAccess.sanitizeIlike(search);
    if (safe.isEmpty) return const [];
    final variants = _catalogSearchTextVariants(safe);
    if (variants.isEmpty) return const [];
    try {
      final orParts = <String>[];
      for (final v in variants) {
        orParts.add('estado.ilike.*$v*');
        orParts.add('ciudad.ilike.*$v*');
      }
      final res = await SupabaseAccess.client
          .from('profiles')
          .select('id')
          .eq('role', 'importador')
          .or(orParts.join(','));
      final list = res as List<dynamic>;
      final ids = list
          .map((e) => (e as Map)['id']?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (ids.length > _maxSearchLocationImporterIds) {
        return ids.sublist(0, _maxSearchLocationImporterIds);
      }
      return ids;
    } catch (_) {
      return const [];
    }
  }

  static dynamic _applyCatalogFilters(
    dynamic query,
    CatalogFilters filters, {
    List<String> searchLocationImporterIds = const [],
    List<String>? searchProductIds,
    List<String> legacySearchVariants = const [],
  }) {
    var q = query;
    if (searchProductIds != null) {
      if (searchProductIds.isEmpty) {
        // Sin matches fuzzy: forzar resultado vacío sin escanear catálogo.
        q = q.eq('id', '00000000-0000-0000-0000-000000000000');
      } else {
        q = q.inFilter('id', searchProductIds);
      }
    } else {
      final search = filters.searchQuery?.trim();
      if (search != null && search.isNotEmpty) {
        final safe = SupabaseAccess.sanitizeIlike(search);
        final variants = legacySearchVariants.isNotEmpty
            ? legacySearchVariants
            : _catalogSearchTextVariants(safe);
        if (variants.isNotEmpty) {
          final nameParts = variants.map((v) => 'name.ilike.*$v*').toList();
          if (searchLocationImporterIds.isNotEmpty) {
            final inList = searchLocationImporterIds.join(',');
            nameParts.add('owner_id.in.($inList)');
          }
          if (nameParts.length == 1) {
            q = q.ilike('name', '%${variants.first}%');
          } else {
            q = q.or(nameParts.join(','));
          }
        }
      }
    }
    final est = filters.ownerEstado?.trim();
    if (est != null && est.isNotEmpty) {
      final s = SupabaseAccess.sanitizeIlike(est);
      if (s.isNotEmpty) {
        q = q.filter('profiles.estado', 'ilike', '%$s%');
      }
    }
    final ciu = filters.ownerCiudad?.trim();
    if (ciu != null && ciu.isNotEmpty) {
      final s = SupabaseAccess.sanitizeIlike(ciu);
      if (s.isNotEmpty) {
        q = q.filter('profiles.ciudad', 'ilike', '%$s%');
      }
    }
    final ownerIds = filters.effectiveOwnerIds;
    if (ownerIds.length == 1) {
      q = q.eq('owner_id', ownerIds.first);
    } else if (ownerIds.length > 1) {
      q = q.inFilter('owner_id', ownerIds);
    }
    if (filters.minPrice != null) {
      q = q.gte('price_usd', filters.minPrice!);
    }
    if (filters.maxPrice != null) {
      q = q.lte('price_usd', filters.maxPrice!);
    }
    if (filters.onlyActiveProducts) {
      q = q.eq('is_active', true);
    }
    final cat = filters.category?.trim();
    if (cat != null && cat.isNotEmpty) {
      q = q.eq('category', cat);
    }
    final minAvg = filters.minOwnerRatingAvg;
    if (minAvg != null && minAvg > 0) {
      q = q.filter(
        'profiles.rating_avg_received_rolling100',
        'gte',
        minAvg,
      );
    }
    final minCnt = filters.minOwnerRatingCount;
    if (minCnt != null && minCnt > 0) {
      q = q.filter(
        'profiles.rating_count_received_rolling100',
        'gte',
        minCnt,
      );
    }
    if (filters.onlyWithCommercialDiscount) {
      q = q.or(
        'sale_price_usd.not.is.null,discount_rules->volume_tiers.neq.[],discount_rules->usd_payment_discount_pct.gt.0',
      );
    }
    // Catálogo B2B (aliados): ocultar sin inventario o por debajo del mínimo de pedido.
    q = q.eq('stock_covers_min_order', true);
    return q;
  }

  /// Perfil público de un mayorista activo. `null` = no existe o no es visible.
  static Future<ImporterStoreProfile?> fetchImporterStoreProfile(
    String importerId,
  ) {
    final id = importerId.trim();
    if (id.isEmpty) return Future<ImporterStoreProfile?>.value(null);
    return retryOnJwtIssuedAtFuture(() async {
      final res = await SupabaseAccess.client.rpc(
        'aliado_importer_store_profile',
        params: <String, dynamic>{'p_importador_id': id},
      );
      final list = SupabaseAccess.decodeRpcJsonArray(res);
      if (list.isEmpty) return null;
      final row = list.first;
      if (row is! Map) return null;
      final profile = ImporterStoreProfile.fromJson(
        Map<String, dynamic>.from(row),
      );
      if (profile.id.isEmpty) return null;
      return profile;
    });
  }

  /// Categorías de `products.category` de ese mayorista (catálogo activo).
  static Future<List<String>> fetchImporterStoreCategories(String importerId) {
    final id = importerId.trim();
    if (id.isEmpty) return Future<List<String>>.value(const []);
    return retryOnJwtIssuedAtFuture(() async {
      final res = await SupabaseAccess.client.rpc(
        'aliado_importer_store_categories',
        params: <String, dynamic>{'p_importador_id': id},
      );
      final list = SupabaseAccess.decodeRpcJsonArray(res);
      final out = <String>[];
      for (final row in list) {
        if (row is! Map) continue;
        final c = row['category']?.toString().trim();
        if (c != null && c.isNotEmpty) out.add(c);
      }
      return out;
    });
  }

  /// Producto de vitrina de un mayorista. `null` si el ID no es suyo o no es visible.
  static Future<PartModel?> fetchVisibleImporterStoreProduct({
    required String importerId,
    required String productId,
  }) {
    final owner = importerId.trim();
    final pid = productId.trim();
    if (owner.isEmpty || pid.isEmpty) {
      return Future<PartModel?>.value(null);
    }
    return retryOnJwtIssuedAtFuture(() async {
      final store = await fetchImporterStoreProfile(owner);
      if (store == null) return null;
      final embed = _catalogProfileSelect(CatalogFilters.empty);
      final row = await SupabaseAccess.client
          .from('products')
          .select('*, $embed')
          .eq('id', pid)
          .eq('owner_id', owner)
          .eq('is_active', true)
          .eq('stock_covers_min_order', true)
          .maybeSingle();
      if (row == null) return null;
      final part = PartModel.fromJson(Map<String, dynamic>.from(row));
      if (!catalogPartBelongsToImporterStore(
        importerId: owner,
        ownerId: part.ownerId,
        isActive: part.isActive,
      )) {
        return null;
      }
      final discounts = await fetchActivePromoProductDiscounts();
      final enriched = applyPromoDiscountsToParts([part], discounts);
      return enriched.isEmpty ? part : enriched.first;
    });
  }
}

class _CatalogSearchPlan {
  const _CatalogSearchPlan({
    this.productIds,
    this.locationImporterIds = const [],
    this.legacySearchVariants = const [],
    this.productScores = const {},
  });

  final List<String>? productIds;
  final List<String> locationImporterIds;
  final List<String> legacySearchVariants;
  final Map<String, double> productScores;

  bool get isEmptyResult => productIds != null && productIds!.isEmpty;
}

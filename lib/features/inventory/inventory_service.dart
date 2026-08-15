
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import_validator.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_mapping.dart';
import 'package:motolink_pro_app/features/inventory/catalog_import/catalog_import_result.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/product_image_bulk_result.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';

class InventoryService {
  InventoryService._();

  static Future<int> importadorBulkSetUsdPaymentDiscount({
    required double pct,
    required String scope,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'importador_bulk_set_usd_payment_discount',
      params: <String, dynamic>{
        'p_pct': pct,
        'p_scope': scope,
      },
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return int.tryParse(res?.toString() ?? '') ?? 0;
  }

  /// Importador: upsert masivo de productos vía RPC (lotes de ~500 filas).
  static Future<CatalogImportResult> importadorBulkUpsertProducts({
    required List<CatalogImportNormalizedRow> rows,
    CatalogImportOptions options = const CatalogImportOptions(),
  }) async {
    if (rows.isEmpty) {
      return const CatalogImportResult();
    }

    final payload = rows.map((r) => r.toRpcJson()).toList();
    final res = await SupabaseAccess.client.rpc(
      'importador_bulk_upsert_products',
      params: <String, dynamic>{
        'p_rows': payload,
        'p_options': options.toJson(),
      },
    );

    if (res is Map) {
      return CatalogImportResult.fromRpcJson(Map<String, dynamic>.from(res));
    }
    return const CatalogImportResult();
  }

  /// Ejecuta importación flexible completa: parsea en lotes y persiste cada uno.
  static Future<CatalogImportResult> runFlexibleCatalogImport({
    required List<CatalogImportParseBatch> batches,
    CatalogImportOptions options = const CatalogImportOptions(),
  }) async {
    if (options.dryRun) {
      var validationErrors = <CatalogImportRowError>[];
      var validCount = 0;
      for (final batch in batches) {
        validationErrors = [...validationErrors, ...batch.errors];
        validCount += batch.validRows.length;
      }
      return CatalogImportResult(
        skipped: validCount,
        validationErrors: validationErrors,
        dryRun: true,
      );
    }

    var aggregate = const CatalogImportResult();
    for (final batch in batches) {
      aggregate = aggregate.merge(
        CatalogImportResult(
          validationErrors: batch.errors,
        ),
      );
      if (batch.validRows.isEmpty) continue;

      final rpcResult = await importadorBulkUpsertProducts(
        rows: batch.validRows,
        options: options,
      );
      aggregate = aggregate.merge(rpcResult);
    }
    return aggregate;
  }

  /// Importador: datos de cuenta / instrucciones por método de pago.
  static Future<InventoryMetrics> fetchMyInventoryMetrics() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return InventoryMetrics.zero;

    final rows = await SupabaseAccess.client
        .from('products')
        .select('stock, is_active')
        .eq('owner_id', uid);

    final list = rows as List<dynamic>;
    var total = 0;
    var outOfStock = 0;
    var paused = 0;
    for (final row in list) {
      final m = Map<String, dynamic>.from(row as Map);
      total++;
      final s = m['stock'];
      final stock = s is int ? s : int.tryParse(s?.toString() ?? '') ?? 0;
      if (stock <= 0) outOfStock++;
      final ia = m['is_active'];
      final active = ia is bool ? ia : ia?.toString() == 'true';
      if (!active) paused++;
    }
    return InventoryMetrics(
      totalProducts: total,
      outOfStock: outOfStock,
      paused: paused,
    );
  }

  /// Inventario del importador autenticado (`owner_id = auth.uid()`).
  static Future<List<PartModel>> fetchMyInventory({
    int limit = 200,
    int offset = 0,
    String? searchQuery,
    String? category,
    bool onlyLowStock = false,
    bool onlyInactive = false,
    bool onlyActive = false,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    dynamic query = SupabaseAccess.client
        .from('products')
        .select('*, profiles(business_name)')
        .eq('owner_id', uid);

    final q = searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      final safe = SupabaseAccess.sanitizeIlike(q);
      query = query.ilike('name', '%$safe%');
    }

    final cat = category?.trim();
    if (cat != null && cat.isNotEmpty && cat != 'Todas') {
      query = query.eq('category', cat);
    }

    if (onlyLowStock) {
      query = query.lt('stock', 5);
    }

    if (onlyInactive) {
      query = query.eq('is_active', false);
    }

    if (onlyActive) {
      query = query.eq('is_active', true);
    }

    final response = await query
        .order('name', ascending: true)
        .range(offset, offset + limit - 1);
    final list = response as List<dynamic>;
    return list
        .map((row) => PartModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// ID del producto con ese [sku] para el dueño actual, o `null`.
  static Future<Map<String, dynamic>?> fetchProductDiscountRulesById(
    String productId,
  ) async {
    final row = await SupabaseAccess.client
        .from('products')
        .select('discount_rules')
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    final raw = row['discount_rules'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static Future<String?> findProductIdByOwnerSku(String sku) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return null;
    final s = sku.trim();
    if (s.isEmpty) return null;

    final row = await SupabaseAccess.client
        .from('products')
        .select('id')
        .eq('owner_id', uid)
        .eq('sku', s)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row)['id']?.toString();
  }

  static Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    await SupabaseAccess.client.from('products').update({
      'is_active': isActive,
    }).eq('id', productId);
  }

  /// Activa o pausa visibilidad de varios productos del inventario actual (RLS).
  static Future<void> setProductsActiveBulk({
    required List<String> productIds,
    required bool isActive,
  }) async {
    final ids = productIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;

    await SupabaseAccess.client.from('products').update({
      'is_active': isActive,
    }).inFilter('id', ids);
  }

  /// Elimina un producto del inventario del importador (RLS: owner).
  static Future<void> deleteProduct({required String productId}) async {
    if (productId.trim().isEmpty) return;
    await SupabaseAccess.client
        .from('products')
        .delete()
        .eq('id', productId.trim());
  }

  /// Elimina varios productos del inventario actual (RLS).
  static Future<int> deleteProductsBulk({
    required List<String> productIds,
  }) async {
    final ids =
        productIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return 0;
    await SupabaseAccess.client.from('products').delete().inFilter('id', ids);
    return ids.length;
  }

  /// Sube una imagen al bucket [product-images] y devuelve la URL pública.
  /// El primer segmento del path debe ser [auth.uid()] (políticas RLS).
  static Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileExtension,
    String? productId,
    int? slot,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    var ext = fileExtension.replaceAll('.', '').toLowerCase();
    if (ext == 'jpg') ext = 'jpeg';
    const allowed = {'jpeg', 'png', 'webp'};
    if (!allowed.contains(ext)) {
      throw ArgumentError('Usa JPG, PNG o WEBP.');
    }

    final idPart =
        (productId != null && productId.isNotEmpty) ? productId : 'nuevo';
    final slotPart = slot != null && slot >= 1 && slot <= kMaxProductImages
        ? 's${slot}_'
        : '';
    final path =
        '$uid/$idPart/$slotPart${DateTime.now().microsecondsSinceEpoch}.$ext';

    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await SupabaseAccess.client.storage
        .from(SupabaseAccess.productImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return SupabaseAccess.client.storage
        .from(SupabaseAccess.productImagesBucket)
        .getPublicUrl(path);
  }

  static Future<String> insertProduct({
    required String sku,
    required String name,
    String? description,
    required double priceUsd,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
    required int stock,
    String? category,
    String? compatibility,
    String? imageUrl,
    List<String>? imageUrls,
    bool isActive = true,
    bool hasWarranty = false,
    Map<String, dynamic>? customFields,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final payload = <String, dynamic>{
      'owner_id': uid,
      'sku': sku.trim(),
      'name': name.trim(),
      'price_usd': priceUsd,
      'stock': stock,
      'is_active': isActive,
      'has_warranty': hasWarranty,
    };
    final d = description?.trim();
    if (d != null && d.isNotEmpty) payload['description'] = d;
    final c = category?.trim();
    if (c != null && c.isNotEmpty) payload['category'] = c;
    final comp = compatibility?.trim();
    if (comp != null && comp.isNotEmpty) payload['compatibility'] = comp;
    final urls = normalizeProductImageUrls(
      imageUrls ??
          (imageUrl != null && imageUrl.trim().isNotEmpty
              ? [imageUrl.trim()]
              : const []),
    );
    if (urls.isNotEmpty) {
      payload['image_urls'] = urls;
      payload['image_url'] = urls.first;
    }
    if (salePriceUsd != null && salePriceUsd > 0) {
      payload['sale_price_usd'] = salePriceUsd;
    }
    if (discountRules != null && discountRules.isNotEmpty) {
      payload['discount_rules'] = discountRules;
    }
    if (customFields != null && customFields.isNotEmpty) {
      payload['custom_fields'] = customFields;
    }

    final inserted = await SupabaseAccess.client
        .from('products')
        .insert(payload)
        .select('id')
        .single();
    return Map<String, dynamic>.from(inserted)['id']?.toString() ?? '';
  }

  static Future<void> updateProduct({
    required String productId,
    required String sku,
    required String name,
    String? description,
    required double priceUsd,
    double? salePriceUsd,
    bool clearSalePrice = false,
    Map<String, dynamic>? discountRules,
    bool clearDiscountRules = false,
    required int stock,
    String? category,
    String? compatibility,
    String? imageUrl,
    List<String>? imageUrls,
    required bool isActive,
    bool hasWarranty = false,
    Map<String, dynamic>? customFields,
    bool clearCustomFields = false,
  }) async {
    final upd = <String, dynamic>{
      'sku': sku.trim(),
      'name': name.trim(),
      'price_usd': priceUsd,
      'stock': stock,
      'is_active': isActive,
      'has_warranty': hasWarranty,
    };
    final d = description?.trim();
    upd['description'] = d;
    final c = category?.trim();
    upd['category'] = c;
    final comp = compatibility?.trim();
    upd['compatibility'] = comp;
    final urls = imageUrls != null
        ? normalizeProductImageUrls(imageUrls)
        : normalizeProductImageUrls(
            imageUrl != null && imageUrl.trim().isNotEmpty
                ? [imageUrl.trim()]
                : const [],
          );
    upd['image_urls'] = urls;
    upd['image_url'] = urls.isEmpty ? null : urls.first;
    if (clearSalePrice) {
      upd['sale_price_usd'] = null;
    } else if (salePriceUsd != null && salePriceUsd > 0) {
      upd['sale_price_usd'] = salePriceUsd;
    }
    if (clearDiscountRules) {
      upd['discount_rules'] = null;
    } else if (discountRules != null) {
      upd['discount_rules'] = discountRules.isEmpty ? null : discountRules;
    }
    if (clearCustomFields) {
      upd['custom_fields'] = <String, dynamic>{};
    } else if (customFields != null) {
      upd['custom_fields'] = customFields;
    }

    await SupabaseAccess.client
        .from('products')
        .update(upd)
        .eq('id', productId);
  }

  static Future<void> setProductImageUrls({
    required String productId,
    required List<String> imageUrls,
  }) async {
    final urls = normalizeProductImageUrls(imageUrls);
    await SupabaseAccess.client.from('products').update({
      'image_urls': urls,
      'image_url': urls.isEmpty ? null : urls.first,
    }).eq('id', productId);
  }

  /// Mapa sku (lower) → { id, imageUrls } para carga masiva de fotos.
  static Future<Map<String, ProductSkuImageIndexEntry>>
      fetchMyInventorySkuImageIndex({
    int limit = 5000,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return {};

    final response = await SupabaseAccess.client
        .from('products')
        .select('id, sku, image_urls, image_url')
        .eq('owner_id', uid)
        .limit(limit);

    final map = <String, ProductSkuImageIndexEntry>{};
    for (final row in response as List<dynamic>) {
      final m = Map<String, dynamic>.from(row as Map);
      final sku = m['sku']?.toString().trim() ?? '';
      if (sku.isEmpty) continue;
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final urls = parseProductImageUrlsJson(
        m['image_urls'],
        legacyImageUrl: m['image_url']?.toString(),
      );
      map[sku.toLowerCase()] = ProductSkuImageIndexEntry(
        productId: id,
        sku: sku,
        imageUrls: urls,
      );
    }
    return map;
  }

  static Future<ProductImageBulkResult> importadorBulkSetProductImages({
    required List<Map<String, dynamic>> rows,
  }) async {
    if (rows.isEmpty) return const ProductImageBulkResult();

    final res = await SupabaseAccess.client.rpc(
      'importador_bulk_set_product_images',
      params: {'p_rows': rows},
    );

    if (res is! Map) return const ProductImageBulkResult();

    final errorsRaw = res['errors'];
    final errors = <ProductImageBulkError>[];
    if (errorsRaw is List) {
      for (final e in errorsRaw) {
        if (e is Map) {
          errors.add(
            ProductImageBulkError(
              message: e['message']?.toString() ?? 'Error',
            ),
          );
        }
      }
    }

    return ProductImageBulkResult(
      updated: res['updated'] is int
          ? res['updated'] as int
          : int.tryParse(res['updated']?.toString() ?? '') ?? 0,
      skipped: res['skipped'] is int
          ? res['skipped'] as int
          : int.tryParse(res['skipped']?.toString() ?? '') ?? 0,
      errors: errors,
    );
  }

  static Future<void> updateProductPriceAndStock({
    required String productId,
    required double priceUsd,
    required int stock,
    double? salePriceUsd,
    bool clearSalePrice = false,
    Map<String, dynamic>? discountRules,
    bool clearDiscountRules = false,
    bool? hasWarranty,
  }) async {
    final upd = <String, dynamic>{
      'price_usd': priceUsd,
      'stock': stock,
    };
    if (clearSalePrice) {
      upd['sale_price_usd'] = null;
    } else if (salePriceUsd != null && salePriceUsd > 0) {
      upd['sale_price_usd'] = salePriceUsd;
    }
    if (clearDiscountRules) {
      upd['discount_rules'] = null;
    } else if (discountRules != null) {
      upd['discount_rules'] = discountRules.isEmpty ? null : discountRules;
    }
    if (hasWarranty != null) {
      upd['has_warranty'] = hasWarranty;
    }
    await SupabaseAccess.client
        .from('products')
        .update(upd)
        .eq('id', productId);
  }

  /// MotoConecta: pedido directo (sin `sub_orders`, `payment_schedule`, ni FK anidada legacy).
}

class InventoryMetrics {
  const InventoryMetrics({
    required this.totalProducts,
    required this.outOfStock,
    required this.paused,
  });

  static const InventoryMetrics zero = InventoryMetrics(
    totalProducts: 0,
    outOfStock: 0,
    paused: 0,
  );

  final int totalProducts;
  final int outOfStock;
  final int paused;
}

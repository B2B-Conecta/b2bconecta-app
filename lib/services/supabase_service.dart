import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_phase_exception.dart';
import '../models/cash_phase_policy.dart';
import '../models/catalog_filters.dart';
import '../models/commission_settlement_model.dart';
import '../models/document_review_status.dart';
import '../models/document_type_preference.dart';
import '../models/in_app_notification_model.dart';
import '../models/kyc_status.dart';
import '../models/kyc_verification_exception.dart';
import '../models/profile_location_exception.dart';
import '../models/stock_insufficient_exception.dart';
import '../models/part_model.dart';
import '../models/pedidos_suspendidos_morosidad_exception.dart';
import '../models/profile_document_model.dart';
import '../models/profile_model.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_message_model.dart';
import '../models/sub_order_status.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../utils/app_date_format.dart';
import '../utils/broker_pricing.dart';
import '../utils/haversine.dart';
import '../config/motolink_ally_invoice_constants.dart';
import 'motolink_ally_invoice_pdf_service.dart';
import 'motolink_commission_invoice_pdf_service.dart';

class SupabaseService {
  SupabaseService._();

  static const _productImagesBucket = 'product-images';
  static const _profileDocumentsBucket = 'profile-documents';
  static const _orderInvoicesBucket = 'order-invoices';
  static const _orderAllyInvoicesBucket = 'order-ally-invoices';
  static const _orderPaymentProofsBucket = 'order-payment-proofs';
  static const _commissionSettlementInvoicesBucket =
      'commission-settlement-invoices';
  static const _profileLogosBucket = 'profile-logos';

  static String? get currentUserId => _currentUserId;

  /// Comisión MotoLink sobre precio mayorista (misma base que [BrokerPricing.feeRate]).
  static double get logisticFeeRate => BrokerPricing.feeRate;

  static double calculateAliadoUnitPrice(
    double precioUnitarioProveedor, {
    bool faseContado = false,
  }) {
    return BrokerPricing.unitPriceForAliado(
      precioUnitarioProveedor,
      faseContado: faseContado,
    );
  }

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _currentUserId => _client.auth.currentUser?.id;

  static const _notificationsSelect =
      'id, user_id, title, body, type, is_read, related_id, created_at';

  /// Notificaciones in-app del usuario actual (más recientes primero).
  static Future<List<InAppNotificationModel>> fetchMyNotifications({
    int limit = 100,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return const [];

    final response = await _client
        .from('notifications')
        .select(_notificationsSelect)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = response as List<dynamic>;
    return list
        .map((row) => InAppNotificationModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  /// Marca una notificación como leída.
  static Future<void> markNotificationAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('id', notificationId);
  }

  /// Marca todas las notificaciones del usuario actual como leídas.
  static Future<void> markAllNotificationsAsRead() async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  /// Marca como leídas las notificaciones de chat/pedido con [related_id] = id de pedido.
  static Future<void> markNotificationsReadForRelatedOrder(String transactionRequestId) async {
    final uid = _currentUserId;
    final rid = transactionRequestId.trim();
    if (uid == null || rid.isEmpty) return;
    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', uid)
        .eq('related_id', rid)
        .eq('is_read', false);
  }

  /// Elimina notificaciones antiguas del usuario actual.
  /// Por defecto borra solo leídas con más de [olderThanDays] días.
  static Future<void> deleteOldNotifications({
    int olderThanDays = 30,
    bool onlyRead = true,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return;
    final days = olderThanDays < 1 ? 1 : olderThanDays;
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();

    dynamic q = _client
        .from('notifications')
        .delete()
        .eq('user_id', uid)
        .lt('created_at', cutoff);

    if (onlyRead) {
      q = q.eq('is_read', true);
    }
    await q;
  }

  /// Elimina notificaciones puntuales del usuario actual.
  static Future<void> deleteNotificationsByIds(List<String> notificationIds) async {
    final uid = _currentUserId;
    if (uid == null) return;
    final ids = notificationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    await _client
        .from('notifications')
        .delete()
        .eq('user_id', uid)
        .inFilter('id', ids);
  }

  /// Elimina todas las notificaciones del usuario actual.
  static Future<void> deleteAllMyNotifications() async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _client.from('notifications').delete().eq('user_id', uid);
  }

  /// Ficha de pedido por ID (respeta RLS del usuario actual).
  static Future<TransactionRequestModel?> fetchTransactionRequestById(
    String requestId,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return null;
    final row = await _client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return TransactionRequestModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Filas del mismo carrito (`checkout_group_id`) que [requestId], orden cronológico. Sin grupo → una sola fila.
  static Future<List<TransactionRequestModel>>
      fetchCheckoutGroupLinesForTransactionRequest(String requestId) async {
    final primary = await fetchTransactionRequestById(requestId);
    if (primary == null) return const [];
    final cg = primary.checkoutGroupId?.trim();
    if (cg == null || cg.isEmpty) return [primary];
    final response = await _client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .eq('checkout_group_id', cg)
        .order('created_at', ascending: true);
    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  /// Resumen para notificaciones (producto + aliado) por IDs de pedidos.
  static Future<Map<String, NotificationOrderSummary>>
      fetchNotificationOrderSummariesByRequestIds(
    List<String> requestIds,
  ) async {
    final ids = requestIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    const selectCols =
        'id, aliado:profiles!transaction_requests_aliado_id_fkey(business_name), importador:profiles!transaction_requests_importador_id_fkey(business_name)';
    final rows = await _client
        .from('transaction_requests')
        .select(selectCols)
        .inFilter('id', ids);
    final list = rows as List<dynamic>;
    final out = <String, NotificationOrderSummary>{};
    for (final row in list) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final prod = m['products'];
      final ali = m['aliado'];
      String? productName;
      String? aliadoBusinessName;
      if (prod is Map) {
        productName = prod['name']?.toString().trim();
      }
      if (productName == null || productName.isEmpty) {
        final imp = m['importador'];
        if (imp is Map) {
          final ibn = imp['business_name']?.toString().trim();
          productName =
              (ibn != null && ibn.isNotEmpty) ? 'Pedido · $ibn' : 'Pedido';
        }
      }
      if (ali is Map) {
        aliadoBusinessName = ali['business_name']?.toString().trim();
      }
      out[id] = NotificationOrderSummary(
        productName: (productName != null && productName.isNotEmpty)
            ? productName
            : null,
        aliadoBusinessName:
            (aliadoBusinessName != null && aliadoBusinessName.isNotEmpty)
                ? aliadoBusinessName
                : null,
      );
    }
    return out;
  }

  /// Realtime: escucha nuevas notificaciones para el usuario autenticado.
  static RealtimeChannel subscribeToMyNotifications({
    required void Function(InAppNotificationModel notification) onInsert,
  }) {
    final uid = _currentUserId;
    if (uid == null) {
      throw StateError('No hay sesión activa para escuchar notificaciones.');
    }
    final channel = _client.channel('notifications:user:$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      callback: (payload) {
        final m = Map<String, dynamic>.from(payload.newRecord);
        onInsert(InAppNotificationModel.fromJson(m));
      },
    );
    channel.subscribe();
    return channel;
  }

  /// Realtime: nuevos mensajes en el hilo de un pedido (misma tabla que inserta el chat).
  static RealtimeChannel subscribeToTransactionRequestMessages({
    required String transactionRequestId,
    required void Function() onInsert,
  }) {
    final id = transactionRequestId.trim();
    if (id.isEmpty) {
      throw ArgumentError('transactionRequestId vacío');
    }
    final channel = _client.channel('trm:req:$id');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'transaction_request_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'transaction_request_id',
        value: id,
      ),
      callback: (_) => onInsert(),
    );
    channel.subscribe();
    return channel;
  }

  static Future<void> unsubscribeChannel(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _client.removeChannel(channel);
  }

  /// Perfil del usuario autenticado (`id` = `auth.uid()`). `null` si no hay fila.
  static Future<ProfileModel?> fetchMyProfile() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final data =
        await _client.from('profiles').select().eq('id', uid).maybeSingle();

    if (data == null) return null;
    return ProfileModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Nombre de negocio para mostrar en etiquetas de pedido.
  static Future<String?> fetchProfileBusinessName(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    final row = await _client
        .from('profiles')
        .select('business_name')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final n = row['business_name']?.toString().trim();
    if (n == null || n.isEmpty) return null;
    return n;
  }

  /// Perfil B2B por id (rutas automáticas, etiquetas).
  static Future<ProfileModel?> fetchProfileById(String profileId) async {
    final id = profileId.trim();
    if (id.isEmpty) return null;
    final row =
        await _client.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return ProfileModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Persiste GPS o geocodificación del domicilio fiscal (`profiles.latitude/longitude`).
  static Future<void> updateMyGeolocation({
    required double latitude,
    required double longitude,
  }) async {
    await _client.rpc(
      'update_my_geolocation',
      params: <String, dynamic>{
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
  }

  /// Crea o actualiza el perfil B2B (upsert por `id`).
  ///
  /// El campo [role] solo se persiste si el perfil aún no tiene rol definido
  /// (`importador` / `aliado` / `administrador`). Tras la primera asignación,
  /// los updates omiten `role` para que no pueda cambiarse desde el cliente.
  static Future<void> upsertMyProfile({
    required String businessName,
    required String rif,
    required String role,
    String? phone,
    String? estado,
    String? ciudad,
    String? direccion,
    String? fiscalMapsUrl,
  }) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw StateError('No hay sesión activa.');
    }

    final existing = await fetchMyProfile();
    final existingRole = existing?.role?.trim().toLowerCase();
    final roleAlreadySet = existingRole == 'importador' ||
        existingRole == 'aliado' ||
        existingRole == 'administrador';

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

    final es = estado?.trim();
    payload['estado'] = (es == null || es.isEmpty) ? null : es;
    final ci = ciudad?.trim();
    payload['ciudad'] = (ci == null || ci.isEmpty) ? null : ci;
    final dir = direccion?.trim();
    payload['direccion'] = (dir == null || dir.isEmpty) ? null : dir;

    final fmu = fiscalMapsUrl?.trim();
    if (fmu != null && fmu.isNotEmpty) {
      final u = Uri.tryParse(fmu);
      if (u == null ||
          !u.hasScheme ||
          (u.scheme != 'http' && u.scheme != 'https')) {
        throw ArgumentError('El enlace de mapa debe ser una URL http o https.');
      }
      payload['fiscal_maps_url'] = fmu;
    } else {
      payload['fiscal_maps_url'] = null;
    }

    await _client.from('profiles').upsert(payload);
  }

  /// URL firmada (1 h) para el logo en `profile-logos`.
  static Future<String> createSignedUrlForProfileLogo(String storagePath) async {
    final p = storagePath.trim();
    if (p.isEmpty) {
      throw ArgumentError('Ruta de logo vacía.');
    }
    return _client.storage
        .from(_profileLogosBucket)
        .createSignedUrl(p, 3600);
  }

  /// Sube o reemplaza el logo del perfil y actualiza `profiles.logo_storage_path`.
  static Future<void> uploadMyProfileLogo({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final ext = fileExtension.trim().toLowerCase().replaceAll('.', '');
    if (ext != 'png' && ext != 'jpg' && ext != 'jpeg' && ext != 'webp') {
      throw ArgumentError('Use PNG, JPG o WEBP.');
    }

    final prof = await fetchMyProfile();
    final oldPath = prof?.logoStoragePath?.trim();

    final path = '$uid/logo_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final ct = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    await _client.storage.from(_profileLogosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: ct, upsert: true),
        );

    await _client.from('profiles').update({
      'logo_storage_path': path,
    }).eq('id', uid);

    if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
      try {
        await _client.storage.from(_profileLogosBucket).remove([oldPath]);
      } catch (_) {}
    }
  }

  /// Quita el logo personalizado (vuelve al marcador por defecto en la app).
  static Future<void> clearMyProfileLogo() async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final prof = await fetchMyProfile();
    final oldPath = prof?.logoStoragePath?.trim();
    await _client.from('profiles').update({
      'logo_storage_path': null,
    }).eq('id', uid);
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await _client.storage.from(_profileLogosBucket).remove([oldPath]);
      } catch (_) {}
    }
  }

  /// Importadores (`role = importador`) para el filtro del catálogo.
  /// Requiere lectura en `profiles` según RLS del proyecto.
  static Future<List<ImporterOption>> fetchImporterOptions() async {
    final response = await _client
        .from('profiles')
        .select('id, business_name, estado, ciudad')
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
          );
        })
        .where((o) => o.id.isNotEmpty && o.businessName.isNotEmpty)
        .toList();
  }

  /// Número total de filas que cumplen [filters] (respeta RLS).
  static Future<int> fetchProductsCount({CatalogFilters? filters}) async {
    final f = filters ?? CatalogFilters.empty;
    final locIds = await _importerProfileIdsForSearchLocation(f);
    final embed = _catalogProfileSelect(f);
    dynamic q = _client.from('products').select('id, $embed');
    q = _applyCatalogFilters(q, f, searchLocationImporterIds: locIds);
    final res = await q.count(CountOption.exact);
    return (res as PostgrestResponse<dynamic>).count;
  }

  static bool _catalogNeedsProfileInner(CatalogFilters filters) {
    final sq = filters.searchQuery?.trim();
    final oe = filters.ownerEstado?.trim();
    final oc = filters.ownerCiudad?.trim();
    return (sq != null && sq.isNotEmpty) ||
        (oe != null && oe.isNotEmpty) ||
        (oc != null && oc.isNotEmpty);
  }

  static String _catalogProfileSelect(CatalogFilters filters) {
    return _catalogNeedsProfileInner(filters)
        ? 'profiles!inner(business_name, estado, ciudad, latitude, longitude)'
        : 'profiles(business_name, estado, ciudad, latitude, longitude)';
  }

  /// Métricas del inventario del usuario actual (importador).
  static Future<InventoryMetrics> fetchMyInventoryMetrics() async {
    final uid = _currentUserId;
    if (uid == null) return InventoryMetrics.zero;

    final rows = await _client
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
    final uid = _currentUserId;
    if (uid == null) return [];

    dynamic query = _client
        .from('products')
        .select('*, profiles(business_name)')
        .eq('owner_id', uid);

    final q = searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      final safe = _sanitizeIlike(q);
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

    final response =
        await query.order('name', ascending: true).range(offset, offset + limit - 1);
    final list = response as List<dynamic>;
    return list
        .map((row) => PartModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// ID del producto con ese [sku] para el dueño actual, o `null`.
  static Future<String?> findProductIdByOwnerSku(String sku) async {
    final uid = _currentUserId;
    if (uid == null) return null;
    final s = sku.trim();
    if (s.isEmpty) return null;

    final row = await _client
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
    await _client.from('products').update({
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

    await _client.from('products').update({
      'is_active': isActive,
    }).inFilter('id', ids);
  }

  /// Sube una imagen al bucket [product-images] y devuelve la URL pública.
  /// El primer segmento del path debe ser [auth.uid()] (políticas RLS).
  static Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileExtension,
    String? productId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    var ext = fileExtension.replaceAll('.', '').toLowerCase();
    if (ext == 'jpg') ext = 'jpeg';
    const allowed = {'jpeg', 'png', 'webp'};
    if (!allowed.contains(ext)) {
      throw ArgumentError('Usa JPG, PNG o WEBP.');
    }

    final idPart =
        (productId != null && productId.isNotEmpty) ? productId : 'nuevo';
    final path =
        '$uid/$idPart/${DateTime.now().microsecondsSinceEpoch}.$ext';

    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await _client.storage.from(_productImagesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return _client.storage.from(_productImagesBucket).getPublicUrl(path);
  }

  static Future<String> insertProduct({
    required String sku,
    required String name,
    String? description,
    required double priceUsd,
    required int stock,
    String? category,
    String? compatibility,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final payload = <String, dynamic>{
      'owner_id': uid,
      'sku': sku.trim(),
      'name': name.trim(),
      'price_usd': priceUsd,
      'stock': stock,
      'is_active': isActive,
    };
    final d = description?.trim();
    if (d != null && d.isNotEmpty) payload['description'] = d;
    final c = category?.trim();
    if (c != null && c.isNotEmpty) payload['category'] = c;
    final comp = compatibility?.trim();
    if (comp != null && comp.isNotEmpty) payload['compatibility'] = comp;
    final img = imageUrl?.trim();
    if (img != null && img.isNotEmpty) payload['image_url'] = img;

    final inserted =
        await _client.from('products').insert(payload).select('id').single();
    return Map<String, dynamic>.from(inserted)['id']?.toString() ?? '';
  }

  static Future<void> updateProduct({
    required String productId,
    required String sku,
    required String name,
    String? description,
    required double priceUsd,
    required int stock,
    String? category,
    String? compatibility,
    String? imageUrl,
    required bool isActive,
  }) async {
    final upd = <String, dynamic>{
      'sku': sku.trim(),
      'name': name.trim(),
      'price_usd': priceUsd,
      'stock': stock,
      'is_active': isActive,
    };
    final d = description?.trim();
    upd['description'] = d;
    final c = category?.trim();
    upd['category'] = c;
    final comp = compatibility?.trim();
    upd['compatibility'] = comp;
    final img = imageUrl?.trim();
    upd['image_url'] = (img == null || img.isEmpty) ? null : img;

    await _client.from('products').update(upd).eq('id', productId);
  }

  static Future<void> updateProductPriceAndStock({
    required String productId,
    required double priceUsd,
    required int stock,
  }) async {
    await _client.from('products').update({
      'price_usd': priceUsd,
      'stock': stock,
    }).eq('id', productId);
  }

  /// MotoConecta: pedido directo (sin `sub_orders`, `payment_schedule`, ni FK anidada legacy).
  static const _trSelectMotoconecta = '''
    id,
    aliado_id,
    importador_id,
    product_id,
    products ( name, sku ),
    status,
    cantidad,
    precio_total_usd,
    commission_rate_snapshot,
    comision_devengada_usd,
    comision_devengada_at,
    commission_settlement_id,
    factura_url,
    proveedor_factura_storage_path,
    proveedor_factura_file_name,
    proveedor_factura_submitted_at,
    tiempo_estimado_envio,
    pago_metodo,
    comprobante_pago_storage_path,
    comprobante_pago_file_name,
    comprobante_pago_submitted_at,
    pago_estado_revision,
    pago_comprobante_rechazo_nota,
    pago_aprobado_at,
    destino_entrega_usa_perfil,
    destino_entrega_texto,
    destino_entrega_maps_url,
    checkout_group_id,
    discount_rules,
    confirmado_por,
    aliado_experience_stars,
    aliado_experience_comment,
    aliado_experience_submitted_at,
    credit_plan_type,
    credit_plan_confirmed_at,
    credit_monto_bloqueado,
    transit_eta_days,
    transit_eta_hours,
    transit_eta_set_at,
    at_aprobado_admin,
    at_rechazado,
    at_en_preparacion,
    at_pedido_listo,
    at_en_transito,
    at_entregado,
    factura_aliado_storage_path,
    factura_aliado_file_name,
    factura_aliado_submitted_at,
    created_at,
    updated_at,
    payment_schedule (
      id,
      transaction_request_id,
      installment_index,
      amount_usd,
      due_on,
      pago_metodo,
      pago_comprobante_storage_path,
      pago_comprobante_file_name,
      pago_submitted_at,
      pago_estado_revision,
      pago_comprobante_rechazo_nota,
      pago_aprobado_at
    ),
    aliado:profiles!transaction_requests_aliado_id_fkey ( business_name, rif, phone, estado, ciudad, direccion, fiscal_maps_url, latitude, longitude, logo_storage_path, kyc_status, credit_limit ),
    importador:profiles!transaction_requests_importador_id_fkey ( business_name, rif, phone, estado, ciudad, direccion, fiscal_maps_url, latitude, longitude, logo_storage_path, kyc_status )
  ''';

  static String get _trSelectForListWithSubs => _trSelectMotoconecta;

  static String get _trSelectForListFlat => _trSelectMotoconecta;

  /// Solicitudes del aliado autenticado (todas).
  static Future<List<TransactionRequestModel>> fetchMyTransactionRequests() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .eq('aliado_id', uid)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Aliado: pedidos en curso y cerrados (pestaña Pedidos).
  static Future<List<TransactionRequestModel>>
      fetchMyPedidosActivosYCerradosForAliado() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .eq('aliado_id', uid)
        .inFilter(
          'status',
          TransactionRequestStatus.motoconectaAliadoPedidosActivosYCerrados,
        )
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// No aplica en MotoConecta (no hay pestaña «Validados» broker).
  static Future<List<TransactionRequestModel>>
      fetchValidatedTransactionRequestsForImporter() async {
    return [];
  }

  /// Pedidos del importador en fases activas (sin uso directo en UI MotoConecta; ver unificado).
  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForImporter() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelectMotoconecta)
        .eq('importador_id', uid)
        .inFilter(
          'status',
          TransactionRequestStatus.motoconectaAdminOperationalActive,
        )
        .order('updated_at', ascending: false);
    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Importador: sin `sub_orders` en MotoConecta.
  static Future<List<TransactionRequestModel>>
      fetchSubOrderSlicesForImporterUnified() async {
    return [];
  }

  /// Importador: pedidos simples (vista unificada con histórico).
  static Future<List<TransactionRequestModel>>
      fetchUnifiedTransactionRequestsForImporter() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelectMotoconecta)
        .eq('importador_id', uid)
        .inFilter(
          'status',
          TransactionRequestStatus.motoconectaImporterOrdersUnifiedStatuses,
        )
        .order('updated_at', ascending: false);
    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// No aplica en MotoConecta (sin estado «validado broker» por producto).
  static Future<List<TransactionRequestModel>>
      fetchValidatedTransactionRequestsForProduct(String productId) async {
    return [];
  }

  /// Bandeja admin: todas las solicitudes.
  static Future<List<TransactionRequestModel>>
      fetchTransactionRequestsForAdmin() async {
    final response = await _client
        .from('transaction_requests')
        .select(_trSelectForListFlat)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Pedidos en curso (pestaña Pedidos activos — admin).
  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForAdmin() async {
    final response = await _client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .inFilter(
          'status',
          TransactionRequestStatus.motoconectaAdminOperationalActive,
        )
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Pedidos cerrados: entregados o rechazados (admin).
  static Future<List<TransactionRequestModel>>
      fetchClosedTransactionRequestsForAdmin() async {
    final response = await _client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .inFilter('status', TransactionRequestStatus.adminClosedOrders)
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Reportes admin: encomiendas en un rango de fechas (`created_at`), con filtros opcionales en servidor.
  static Future<List<TransactionRequestModel>>
      fetchTransactionRequestsForAdminReport({
    required DateTime createdFromLocal,
    required DateTime createdToLocal,
    List<String>? statuses,
    String? ownerId,
    int limit = 2500,
  }) async {
    final fromUtc = DateTime(
      createdFromLocal.year,
      createdFromLocal.month,
      createdFromLocal.day,
    ).toUtc();
    final toUtc = DateTime(
      createdToLocal.year,
      createdToLocal.month,
      createdToLocal.day,
      23,
      59,
      59,
      999,
    ).toUtc();

    dynamic query = _client
        .from('transaction_requests')
        .select(_trSelectForListFlat)
        .gte('created_at', fromUtc.toIso8601String())
        .lte('created_at', toUtc.toIso8601String());

    if (statuses != null && statuses.isNotEmpty) {
      query = query.inFilter('status', statuses);
    }
    final owner = ownerId?.trim();
    if (owner != null && owner.isNotEmpty) {
      query = query.eq('importador_id', owner);
    }

    final response =
        await query.order('created_at', ascending: false).limit(limit);
    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Perfiles B2B (aliado e importador) para cola KYC admin.
  static Future<List<ProfileModel>> fetchB2BProfilesForAdminKycReview() async {
    final response = await _client
        .from('profiles')
        .select()
        .inFilter('role', ['aliado', 'importador'])
        .order('business_name', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            ProfileModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Broker: actualiza estado KYC global del perfil (aliado o importador).
  static Future<void> adminSetProfileKycStatus({
    required String profileId,
    required String status,
  }) async {
    await _client.rpc(
      'admin_set_profile_kyc_status',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_status': status,
      },
    );
  }

  /// Admin: aliados con pedido moroso (entregado, factura MotoLink, pago sin aprobar).
  static Future<Map<String, bool>> adminAliadosPedidosMorososFlags() async {
    final res = await _client.rpc('admin_aliados_pedidos_morosos_flags');
    final list = res as List<dynamic>;
    final map = <String, bool>{};
    for (final row in list) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['aliado_id']?.toString();
      final mor = m['tiene_morosos'];
      if (id != null && id.isNotEmpty) {
        map[id] = mor is bool ? mor : mor?.toString().toLowerCase() == 'true';
      }
    }
    return map;
  }

  /// Admin: suspende o reactiva la creación de nuevos pedidos por morosidad.
  static Future<void> adminSetAliadoPedidosSuspendidosMorosidad({
    required String aliadoId,
    required bool suspend,
  }) async {
    await _client.rpc(
      'admin_set_aliado_pedidos_suspendidos_morosidad',
      params: <String, dynamic>{
        'p_aliado_id': aliadoId,
        'p_suspend': suspend,
      },
    );
  }

  /// Broker: revisión por documento (`profile_documents` vigente).
  static Future<void> adminSetProfileDocumentReviewStatus({
    required String profileId,
    required String docType,
    required String status,
    String? note,
  }) async {
    await _client.rpc(
      'admin_set_profile_document_review_status',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_doc_type': docType,
        'p_status': status,
        'p_note': note,
      },
    );
  }

  /// Aliado o importador: envía expediente a revisión MotoLink.
  static Future<void> profileSubmitKycForReview() async {
    await _client.rpc('profile_submit_kyc_for_review');
  }

  static const _profileDocumentsSelect = 'id, profile_id, doc_type, '
      'storage_path, file_name, created_at, is_current, review_status, review_note, '
      'reviewed_at, reviewed_by, '
      'reviewer:profiles!reviewed_by(business_name)';

  /// Documentos subidos por el aliado autenticado.
  static Future<List<ProfileDocumentModel>> fetchMyProfileDocuments() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('profile_documents')
        .select(_profileDocumentsSelect)
        .eq('profile_id', uid)
        .eq('is_current', true)
        .order('doc_type', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            ProfileDocumentModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Admin: documentos de un perfil B2B (vigente + histórico).
  static Future<List<ProfileDocumentModel>> fetchProfileDocumentsForProfile(
    String profileId,
  ) async {
    if (profileId.isEmpty) return [];

    final response = await _client
        .from('profile_documents')
        .select(_profileDocumentsSelect)
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            ProfileDocumentModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// URL firmada (1 h) para abrir un archivo del bucket privado.
  static Future<String> createSignedUrlForProfileDocument(
    String storagePath,
  ) async {
    return _client.storage
        .from(_profileDocumentsBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Sube una **nueva versión** de documento KYC (PDF / imagen).
  /// Las versiones anteriores permanecen en Storage y en BD; el trigger marca `is_current`.
  static Future<void> uploadMyProfileDocument({
    required String docType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    final path =
        '$uid/${docType}_${DateTime.now().microsecondsSinceEpoch}.$ext';

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_profileDocumentsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
    await _client.from('profile_documents').insert({
      'profile_id': uid,
      'doc_type': docType,
      'storage_path': path,
      'file_name': fileName,
        'review_status': DocumentReviewStatus.pendiente,
        'is_current': true,
      });
    } catch (e) {
      try {
        await _client.storage.from(_profileDocumentsBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static String _profileDocExtension(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i < 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1).toLowerCase();
  }

  static bool _isAllowedProfileDocExtension(String ext) {
    const ok = {'pdf', 'jpg', 'jpeg', 'png', 'webp'};
    final e = ext == 'jpg' ? 'jpeg' : ext;
    return ok.contains(e);
  }

  static String _mimeForProfileDocExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
      default:
        return 'application/pdf';
    }
  }

  /// Cantidad de pedidos abiertos (no entregados ni rechazados).
  static Future<int> fetchOpenTransactionRequestCountForCurrentAliado() async {
    final uid = _currentUserId;
    if (uid == null) return 0;

    const exposure =
        TransactionRequestStatus.motoconectaAliadoCreditExposureStatuses;

    final response = await _client
        .from('transaction_requests')
        .select('id')
        .eq('aliado_id', uid)
        .inFilter('status', exposure);

    return (response as List<dynamic>).length;
  }

  static Future<void> insertTransactionRequest({
    required String productId,
    required String ownerId,
    required int cantidad,
    required double precioUnitarioProveedor,
    bool destinoEntregaUsaPerfil = true,
    String? destinoEntregaTexto,
    String? destinoEntregaMapsUrl,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    if (!destinoEntregaUsaPerfil) {
      final m = destinoEntregaMapsUrl?.trim() ?? '';
      final u = Uri.tryParse(m);
      if (m.isEmpty ||
          u == null ||
          !u.hasScheme ||
          (u.scheme != 'http' && u.scheme != 'https')) {
        throw ProfileLocationException(
          'Cuando el destino no es el de su perfil, indique un enlace válido de Google Maps '
          '(http o https) además de la dirección.',
        );
      }
    }

    final profile = await fetchMyProfile();
    final role = profile?.role?.trim().toLowerCase();
    if (role != 'aliado') {
      throw StateError('Solo los aliados pueden crear solicitudes de pedido.');
    }
    if (profile == null) {
      throw StateError('No se encontró el perfil del aliado.');
    }
    if (profile.pedidosSuspendidosMorosidad) {
      throw PedidosSuspendidosMorosidadException(
        'MotoLink suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad. '
        'Complete o regularice los pagos pendientes de pedidos ya entregados; cuando MotoLink confirme '
        'y reactive su cuenta, podrá volver a solicitar repuestos.',
      );
    }
    if (!profile.hasRegisteredLocation) {
      throw ProfileLocationException(
        'Registre estado, ciudad y dirección fiscal en Mi perfil para poder solicitar pedidos.',
      );
    }
    if (!profile.hasFiscalMapsShareLink) {
      throw ProfileLocationException(
        'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal '
        '(URL http o https) para solicitar pedidos con precisión de ruta.',
      );
    }

    final pce = profile.primerosPedidosContadoEntregados ?? 0;
    final enFaseContado = pce < CashPhasePolicy.entregasRequeridas;

    // Misma regla en toda la vida del aliado: RIF + domicilio (ya validado arriba); solo
    // documentación explícitamente rechazada bloquea pedidos al contado. KYC completo no es
    // requisito para generar pedidos.
    final rif = profile.rif?.trim();
    if (rif == null || rif.isEmpty) {
        throw KycVerificationException(
        'Registre su RIF comercial en Mi perfil para solicitar pedidos.',
        );
      }
    final ks = profile.kycStatus?.trim();
      if (ks == KycStatus.rechazado) {
        throw KycVerificationException(
        'Su documentación fue rechazada. Actualice los datos en su perfil antes de solicitar pedidos.',
      );
    }

    final unitAliado = calculateAliadoUnitPrice(
      precioUnitarioProveedor,
      faseContado: enFaseContado,
    );
    final total = unitAliado * cantidad;

    final prodRes = await _client
        .from('products')
        .select('stock')
        .eq('id', productId)
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (prodRes == null) {
      throw StateError('No se encontró el producto para este importador.');
    }
    final stockRaw = Map<String, dynamic>.from(prodRes)['stock'];
    final stock = stockRaw is int
        ? stockRaw
        : int.tryParse(stockRaw.toString()) ?? 0;
    if (cantidad > stock) {
      throw StockInsufficientException(
        'Stock insuficiente: hay $stock unidad(es) disponible(s). '
        'Reduzca la cantidad o intente más tarde cuando el importador reponga inventario.',
      );
    }

    final otroDestinoTexto = destinoEntregaTexto?.trim();
    if (!destinoEntregaUsaPerfil &&
        (otroDestinoTexto == null || otroDestinoTexto.isEmpty)) {
      throw ArgumentError(
        'Indique la dirección de entrega cuando el destino no es el del perfil.',
      );
    }

    if (enFaseContado) {
      final openCnt = await fetchOpenTransactionRequestCountForCurrentAliado();
      if (openCnt >= 1) {
        throw CashPhaseException(
          'En los primeros ${CashPhasePolicy.entregasRequeridas} pedidos en contado solo puede '
          'tener un pedido activo a la vez. Cuando el actual se entregue o lo cancele con MotoLink, '
          'podrá solicitar otro.',
        );
      }
    }

    try {
      await _client.from('transaction_requests').insert({
        'aliado_id': uid,
        'importador_id': ownerId,
        'product_id': productId,
        'status': TransactionRequestStatus.pendiente,
        'cantidad': cantidad,
        'precio_total_usd': total,
      });
      await _client.from('products').update({
        'stock': stock - cantidad,
      }).eq('id', productId).eq('owner_id', ownerId);
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('stock insuficiente')) {
        throw StockInsufficientException(e.message);
      }
      rethrow;
    }
  }

  /// Confirma carrito multi-importador (crea maestro + sub_orders + order_items + snapshot BCV).
  static Future<String> checkoutMultiImportadorCart({
    required List<Map<String, dynamic>> lines,
    bool destinoEntregaUsaPerfil = true,
    String? destinoEntregaTexto,
    String? destinoEntregaMapsUrl,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final profile = await fetchMyProfile();
    if (profile == null || profile.role?.trim().toLowerCase() != 'aliado') {
      throw StateError('Solo los aliados pueden confirmar el carrito.');
    }
    if (destinoEntregaUsaPerfil) {
      if (!profile.hasFiscalMapsShareLink) {
        throw ProfileLocationException(
          'Registre en Mi perfil el enlace «Compartir» de Google Maps de su domicilio fiscal.',
        );
      }
    } else {
      final m = destinoEntregaMapsUrl?.trim() ?? '';
      final u = Uri.tryParse(m);
      if (m.isEmpty ||
          u == null ||
          !u.hasScheme ||
          (u.scheme != 'http' && u.scheme != 'https')) {
        throw ProfileLocationException(
          'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.',
        );
      }
    }

    final res = await _client.rpc(
      'aliado_checkout_multi_importador',
      params: <String, dynamic>{
        'p_lines': lines,
        'p_destino_entrega_usa_perfil': destinoEntregaUsaPerfil,
        'p_destino_entrega_texto': destinoEntregaTexto,
        'p_destino_entrega_maps_url': destinoEntregaMapsUrl,
      },
    );
    return res?.toString() ?? '';
  }

  /// Tasa BCV configurada (solo lectura; usar [TransactionRequestModel.tasaBcvSnapshot] por pedido).
  static Future<double?> fetchGlobalTasaBcv() async {
    try {
      final row = await _client
          .from('app_global_config')
          .select('value_numeric')
          .eq('key', 'tasa_bcv')
          .maybeSingle();
      if (row == null) return null;
      final m = Map<String, dynamic>.from(row);
      final v = m['value_numeric'];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  static Future<void> adminSetTasaBcv(double tasa) async {
    await _client.rpc('admin_set_tasa_bcv', params: {'p_tasa': tasa});
  }

  static Future<void> importerAdvanceSubOrder({
    required String subOrderId,
    required String newSubStatus,
  }) async {
    await _client.rpc(
      'importer_advance_sub_order',
      params: <String, dynamic>{
        'p_sub_order_id': subOrderId,
        'p_new_status': newSubStatus,
      },
    );
  }

  static Future<void> adminMarcaSubOrderEnTransito({
    required String subOrderId,
    required int transitEtaDays,
    required int transitEtaHours,
  }) async {
    await _client.rpc(
      'admin_marca_sub_order_en_transito',
      params: <String, dynamic>{
        'p_sub_order_id': subOrderId,
        'p_transit_eta_days': transitEtaDays,
        'p_transit_eta_hours': transitEtaHours,
      },
    );
  }

  static Future<void> aliadoMarcaSubOrderEntregado(String subOrderId) async {
    await _client.rpc(
      'aliado_marca_sub_order_entregado',
      params: {'p_sub_order_id': subOrderId},
    );
  }

  /// Sin `sub_orders` en MotoConecta.
  static Future<List<TransactionRequestModel>>
      fetchActiveSubOrderSlicesForImporter() async {
    return [];
  }

  static String? _subStatusFromImporterAdvance(String trNextStatus) {
    switch (trNextStatus) {
      case TransactionRequestStatus.enPreparacion:
        return SubOrderStatus.preparando;
      case TransactionRequestStatus.pedidoListo:
        return SubOrderStatus.listo;
      default:
        return null;
    }
  }

  static Future<List<TransactionRequestModel>>
      fetchValidatedSubOrderSlicesForImporter() async {
    return [];
  }

  static Future<void> adminUpdateTransactionRequest({
    required String id,
    required String status,
    String? notasAdmin,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final n = notasAdmin?.trim();
    if (n != null && n.isNotEmpty) {
      payload['notas_admin'] = n;
    }
    await _client.from('transaction_requests').update(payload).eq('id', id);
  }

  /// URL firmada (1 h) para abrir una factura de pedido (`order-invoices`).
  static Future<String> createSignedUrlForOrderInvoice(String storagePath) async {
    return _client.storage
        .from(_orderInvoicesBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Factura oficial MotoLink al aliado (`order-ally-invoices`).
  static Future<String> createSignedUrlForFacturaAliado(String storagePath) async {
    return _client.storage
        .from(_orderAllyInvoicesBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Comprobante de pago del aliado (`order-payment-proofs`).
  static Future<String> createSignedUrlForComprobantePago(String storagePath) async {
    return _client.storage
        .from(_orderPaymentProofsBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Respaldo fotográfico de cobro en efectivo (mismo bucket; prefijo `efectivo_respaldo_`).
  static Future<String> createSignedUrlForEfectivoRespaldo(String storagePath) async {
    return _client.storage
        .from(_orderPaymentProofsBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// MotoLink: sube o reemplaza la factura oficial al aliado (pedido en preparación).
  static Future<void> adminSubmitFacturaAliadoOrder({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final profile = await fetchMyProfile();
    if (profile?.role?.trim().toLowerCase() != 'administrador') {
      throw StateError('Solo MotoLink puede adjuntar la factura oficial al aliado.');
    }

    final row = await _client
        .from('transaction_requests')
        .select(
          'status, is_master_order, proveedor_factura_storage_path, pago_estado_revision',
        )
        .eq('id', transactionRequestId)
        .maybeSingle();

    if (row == null) throw StateError('Pedido no encontrado.');
    final m = Map<String, dynamic>.from(row);
    final st = m['status']?.toString();
    final isMaster = m['is_master_order'] == true;
    final stAllowed = st == TransactionRequestStatus.enPreparacion ||
        st == TransactionRequestStatus.pedidoListo ||
        (isMaster && st == TransactionRequestStatus.aprobadoAdmin);
    if (!stAllowed) {
      throw StateError(
        'Solo aplica con el pedido en preparación o listo para recolección.',
      );
    }
    if (isMaster) {
      final rows = await _client
          .from('sub_orders')
          .select('id, proveedor_factura_storage_path')
          .eq('parent_order_id', transactionRequestId);
      final list = rows as List<dynamic>;
      if (list.isEmpty) {
        throw StateError(
          'Pedido maestro sin sub-pedidos: no se puede emitir factura al aliado.',
        );
      }
      final missing = list.where((e) {
        if (e is! Map) return true;
        final p = e['proveedor_factura_storage_path']?.toString().trim();
        return p == null || p.isEmpty;
      }).length;
      if (missing > 0) {
        throw StateError(
          'Falta factura del proveedor en $missing sub-pedido(s).',
        );
      }
    } else {
      final prov = m['proveedor_factura_storage_path']?.toString().trim();
      if (prov == null || prov.isEmpty) {
        throw StateError(
          'El importador debe haber adjuntado antes la factura del proveedor.',
        );
      }
    }
    final pe = m['pago_estado_revision']?.toString().trim();
    if (pe == PagoRevisionEstado.enRevision) {
      throw StateError(
        'Hay un comprobante en revisión. Resuélvalo antes de cambiar la factura.',
      );
    }
    if (pe == PagoRevisionEstado.aprobado) {
      throw StateError('El pago ya fue aprobado; no puede reemplazar la factura.');
    }

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'factura_aliado.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final existing = await _client
        .from('transaction_requests')
        .select('factura_aliado_storage_path')
        .eq('id', transactionRequestId)
        .maybeSingle();
    if (existing != null) {
      final oldPath = Map<String, dynamic>.from(existing)['factura_aliado_storage_path']
          ?.toString()
          .trim();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await _client.storage.from(_orderAllyInvoicesBucket).remove([oldPath]);
        } catch (_) {}
      }
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderAllyInvoicesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    await _client.from('transaction_requests').update({
      'factura_aliado_storage_path': path,
      'factura_aliado_file_name': fileName.trim(),
      'factura_aliado_submitted_at': DateTime.now().toUtc().toIso8601String(),
      'pago_estado_revision': PagoRevisionEstado.pendiente,
      'pago_metodo': null,
      'comprobante_pago_storage_path': null,
      'comprobante_pago_file_name': null,
      'comprobante_pago_submitted_at': null,
      'pago_comprobante_rechazo_nota': null,
      'pago_aprobado_at': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', transactionRequestId);
  }

  /// MotoLink: reserva correlativo y valida gate; luego genere PDF en cliente y llame a [adminFinalizeMotolinkAllyDocumentEmission].
  static Future<Map<String, dynamic>> adminPrepareMotolinkAllyDocumentEmission({
    required String transactionRequestId,
    required String documentType,
    String? reissueMotivo,
    int fragmentIndex = 1,
    int fragmentTotal = 1,
  }) async {
    final raw = await _client.rpc(
      'admin_prepare_motolink_ally_document_emission',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_document_type': documentType,
        'p_reissue_motivo': reissueMotivo?.trim(),
        'p_fragment_index': fragmentIndex,
        'p_fragment_total': fragmentTotal,
      },
    );
    if (raw is! Map) {
      throw StateError('Respuesta inválida al preparar emisión.');
    }
    return Map<String, dynamic>.from(raw);
  }

  static Future<void> adminFinalizeMotolinkAllyDocumentEmission({
    required String emissionId,
    required String storagePath,
    required String fileName,
    bool isLastFragment = true,
  }) async {
    await _client.rpc(
      'admin_finalize_motolink_ally_document_emission',
      params: <String, dynamic>{
        'p_emission_id': emissionId,
        'p_storage_path': storagePath,
        'p_file_name': fileName,
        'p_is_last_fragment': isLastFragment,
      },
    );
  }

  /// Genera uno o varios PDF oficiales (fragmentación por [MotolinkAllyInvoiceConstants.maxItemsPerDocument]).
  static Future<void> adminGenerateMotolinkAllyDocumentPdf({
    required String transactionRequestId,
    String? reissueMotivo,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final profile = await fetchMyProfile();
    if (profile?.role?.trim().toLowerCase() != 'administrador') {
      throw StateError('Solo MotoLink puede generar este documento.');
    }

    final r0 = await fetchTransactionRequestById(transactionRequestId);
    if (r0 == null) throw StateError('Pedido no encontrado.');
    final pref = r0.documentTypePreference?.trim();
    if (pref == null ||
        !DocumentTypePreference.values.contains(pref)) {
      throw StateError(
        'El aliado no indicó tipo de documento (nota o factura) en el pedido.',
      );
    }

    final lines = MotolinkAllyInvoicePdfService.linesFromRequest(r0);
    const maxItems = MotolinkAllyInvoiceConstants.maxItemsPerDocument;
    final chunks = <List<MotolinkAllyInvoicePdfLine>>[];
    for (var i = 0; i < lines.length; i += maxItems) {
      final end = (i + maxItems > lines.length) ? lines.length : i + maxItems;
      chunks.add(lines.sublist(i, end));
    }
    if (chunks.isEmpty) {
      chunks.add(lines);
    }

    final trimmedReissue = reissueMotivo?.trim();
    final isReissue = trimmedReissue != null && trimmedReissue.isNotEmpty;
    if (isReissue && chunks.length > 1) {
      throw StateError(
        'La reemisión con varias hojas no está soportada. Contacte soporte.',
      );
    }

    final existingDone = r0.motolinkAllyDocumentEmissions
        .where((e) => e.documentType == pref && e.isFinalized)
        .length;

    if (!isReissue) {
      if (existingDone >= chunks.length) return;
    }

    var startIndex = isReissue ? 0 : existingDone;
    if (startIndex > 0 && startIndex >= chunks.length) {
      throw StateError(
        'Estado de emisiones inconsistente con las líneas del pedido.',
      );
    }

    if (startIndex == 0) {
      final existing = await _client
          .from('transaction_requests')
          .select('factura_aliado_storage_path')
          .eq('id', transactionRequestId)
          .maybeSingle();
      if (existing != null) {
        final oldPath = Map<String, dynamic>.from(existing)['factura_aliado_storage_path']
            ?.toString()
            .trim();
        if (oldPath != null && oldPath.isNotEmpty) {
          try {
            await _client.storage.from(_orderAllyInvoicesBucket).remove([oldPath]);
          } catch (_) {}
        }
      }
    }

    final label = pref == DocumentTypePreference.notaEntrega ? 'NE' : 'FF';
    final totalFrags = chunks.length;

    for (var fi = startIndex; fi < chunks.length; fi++) {
      final fragmentIndex = fi + 1;
      final prep = await adminPrepareMotolinkAllyDocumentEmission(
        transactionRequestId: transactionRequestId,
        documentType: pref,
        reissueMotivo: fragmentIndex == 1 ? trimmedReissue : null,
        fragmentIndex: fragmentIndex,
        fragmentTotal: totalFrags,
      );

      final emissionId = prep['emission_id']?.toString() ?? '';
      if (emissionId.isEmpty) {
        throw StateError('Emisión sin id.');
      }
      final correlativo = (prep['correlativo'] as num?)?.toInt() ?? 0;
      final tasa = (prep['tasa_bcv_emision'] as num?)?.toDouble() ?? 0;
      final iva = (prep['iva_pct_emision'] as num?)?.toDouble() ?? 16;
      final igtf = (prep['igtf_pct_emision'] as num?)?.toDouble() ?? 3;

      final bytes = await MotolinkAllyInvoicePdfService.build(
        request: r0,
        documentType: pref,
        correlativo: correlativo,
        tasaBcvEmision: tasa,
        ivaPct: iva,
        igtfPct: igtf,
        emissionId: emissionId,
        lines: chunks[fi],
        fragmentIndex: fragmentIndex,
        fragmentTotal: totalFrags,
      );

      final safeName =
          'MotoLink_${label}_${correlativo.toString().padLeft(6, '0')}.pdf';
      final path = '$transactionRequestId/motolink_$emissionId.pdf';

      await _client.storage.from(_orderAllyInvoicesBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      await adminFinalizeMotolinkAllyDocumentEmission(
        emissionId: emissionId,
        storagePath: path,
        fileName: safeName,
        isLastFragment: fi == chunks.length - 1,
      );
    }
  }

  /// Aliado: sube foto del comprobante y envía a revisión MotoLink.
  static Future<void> aliadoSubmitComprobantePago({
    required String transactionRequestId,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final row = await _client
        .from('transaction_requests')
        .select('comprobante_pago_storage_path, pago_estado_revision')
        .eq('id', transactionRequestId)
        .eq('aliado_id', uid)
        .maybeSingle();
    if (row != null) {
      final m = Map<String, dynamic>.from(row);
      final pe = m['pago_estado_revision']?.toString().trim();
      if (pe == PagoRevisionEstado.aprobado) {
        throw StateError(
          'El pago ya fue confirmado; no puede modificar el comprobante.',
        );
      }
      final oldPath =
          m['comprobante_pago_storage_path']?.toString().trim();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await _client.storage.from(_orderPaymentProofsBucket).remove([oldPath]);
        } catch (_) {}
      }
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderPaymentProofsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await _client.rpc(
        'aliado_registra_comprobante_pago',
        params: <String, dynamic>{
          'p_request_id': transactionRequestId,
          'p_metodo': metodo,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await _client.storage.from(_orderPaymentProofsBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Aliado: un solo archivo de comprobante aplicado a todas las líneas del mismo carrito
  /// e importador (MotoConecta pago directo, sin plan de cuotas por línea).
  static Future<void> aliadoSubmitComprobantePagoBundle({
    required List<TransactionRequestModel> lines,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (lines.length < 2) {
      throw ArgumentError('Se requieren al menos 2 líneas para el comprobante unificado.');
    }
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ids = lines.map((e) => e.id).toList();
    final cg0 = lines.first.checkoutGroupId?.trim() ?? '';
    if (cg0.isEmpty) {
      throw StateError(
        'Las líneas deben compartir el mismo carrito (checkout) para un comprobante único.',
      );
    }
    if (!lines.every((r) => (r.checkoutGroupId?.trim() ?? '') == cg0)) {
      throw StateError('Todas las líneas deben pertenecer al mismo carrito.');
    }
    final imp0 = lines.first.ownerId.trim();
    if (!lines.every((r) => r.ownerId.trim() == imp0)) {
      throw StateError('Todas las líneas deben ser del mismo importador.');
    }
    if (!lines.every((r) => r.aliadoId == uid)) {
      throw StateError('No autorizado para alguna de las líneas.');
    }
    if (lines.any((r) => r.hasAgreedCreditPlan)) {
      throw StateError(
        'Este bloque tiene plan de cuotas: gestione el comprobante por línea o por cuota.',
      );
    }

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final rows = await _client
        .from('transaction_requests')
        .select(
            'id, pago_estado_revision, comprobante_pago_storage_path, status')
        .eq('aliado_id', uid)
        .inFilter('id', ids);

    if (rows.length != ids.length) {
      throw StateError('No se encontraron todas las líneas del pedido.');
    }
    for (final m in rows) {
      final map = Map<String, dynamic>.from(m as Map<dynamic, dynamic>);
      if (map['status']?.toString() == TransactionRequestStatus.rechazado) {
        throw StateError('Una de las líneas está rechazada.');
      }
      final pe = map['pago_estado_revision']?.toString().trim();
      if (pe == PagoRevisionEstado.aprobado) {
        throw StateError(
          'El pago ya fue confirmado en una línea; no puede modificar el comprobante.',
        );
      }
    }

    for (final old in rows) {
      final map = Map<String, dynamic>.from(old as Map<dynamic, dynamic>);
      final op = map['comprobante_pago_storage_path']?.toString().trim();
      if (op != null && op.isNotEmpty) {
        try {
          await _client.storage.from(_orderPaymentProofsBucket).remove([op]);
        } catch (_) {}
      }
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final primaryId = lines.first.id;
    final path = '$primaryId/${stamp}_bundle_$safeBase';

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderPaymentProofsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      final fname = fileName.trim();
      for (final id in ids) {
        await _client.rpc(
          'aliado_registra_comprobante_pago',
          params: <String, dynamic>{
            'p_request_id': id,
            'p_metodo': metodo,
            'p_storage_path': path,
            'p_file_name': fname,
          },
        );
      }
    } catch (e) {
      try {
        await _client.storage.from(_orderPaymentProofsBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Importador: mismo estado de revisión del comprobante en todas las líneas del carrito (mismo comprobante).
  static Future<void> importadorSetPagoRevisionEstadoBundle({
    required List<String> transactionRequestIds,
    required String nuevoEstado,
    String? rechazoNota,
  }) async {
    if (transactionRequestIds.isEmpty) return;
    for (final id in transactionRequestIds) {
      await importadorSetPagoRevisionEstado(
        transactionRequestId: id,
        nuevoEstado: nuevoEstado,
        rechazoNota: rechazoNota,
      );
    }
  }

  /// Importador: aprueba o rechaza el comprobante registrado por el aliado (`importador_set_pago_revision_estado`).
  static Future<void> importadorSetPagoRevisionEstado({
    required String transactionRequestId,
    required String nuevoEstado,
    String? rechazoNota,
  }) async {
    if (_currentUserId == null) throw StateError('No hay sesión activa.');
    await _client.rpc(
      'importador_set_pago_revision_estado',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_nuevo_estado': nuevoEstado,
        'p_rechazo_nota': rechazoNota,
      },
    );
  }

  /// MotoLink: sube foto respaldo del cobro en efectivo y registra vía RPC.
  static Future<void> registrarRespaldoCobroEfectivo({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }
    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'respaldo.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path =
        '$transactionRequestId/efectivo_respaldo_${stamp}_$safeBase';

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderPaymentProofsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await _client.rpc(
        'registrar_respaldo_cobro_efectivo',
        params: <String, dynamic>{
          'p_request_id': transactionRequestId,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await _client.storage.from(_orderPaymentProofsBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> adminAprobarPagoAliado(String requestId) async {
    await _client.rpc(
      'admin_aprobar_pago_aliado',
      params: <String, dynamic>{'p_request_id': requestId},
    );
  }

  static Future<void> adminRechazarComprobantePago({
    required String requestId,
    required String nota,
  }) async {
    await _client.rpc(
      'admin_rechazar_comprobante_pago',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_nota': nota.trim(),
      },
    );
  }

  /// MotoConecta: importador sube factura del proveedor (Storage `order-invoices`).
  static Future<void> importerSubmitMotoconectaProveedorFactura({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final row = await _client
        .from('transaction_requests')
        .select('importador_id, status, proveedor_factura_storage_path')
        .eq('id', transactionRequestId)
        .maybeSingle();

    if (row == null) {
      throw StateError('Pedido no encontrado.');
    }
    final m = Map<String, dynamic>.from(row);
    if (m['importador_id']?.toString() != uid) {
      throw StateError('No autorizado a adjuntar factura en este pedido.');
    }
    final st = m['status']?.toString();
    if (st != TransactionRequestStatus.pendiente &&
        st != TransactionRequestStatus.enPreparacion &&
        st != TransactionRequestStatus.pedidoListo) {
      throw StateError(
        'Solo puede adjuntar o actualizar la factura mientras el pedido está pendiente, '
        'en preparación o listo para despacho (antes de marcar en tránsito).',
      );
    }

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) {
      safeBase = 'factura.$ext';
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final oldPath = m['proveedor_factura_storage_path']?.toString().trim();
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await _client.storage.from(_orderInvoicesBucket).remove([oldPath]);
      } catch (_) {}
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderInvoicesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    await _client.from('transaction_requests').update({
      'proveedor_factura_storage_path': path,
      'proveedor_factura_file_name': fileName.trim(),
      'proveedor_factura_submitted_at':
          DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', transactionRequestId);
  }

  /// Mismo archivo de factura del proveedor para todas las líneas del carrito (mismo importador).
  static Future<void> importerSubmitMotoconectaProveedorFacturaBundle({
    required List<String> transactionRequestIds,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ids = transactionRequestIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      throw ArgumentError('Debe indicar al menos un pedido.');
    }
    if (ids.length == 1) {
      await importerSubmitMotoconectaProveedorFactura(
        transactionRequestId: ids.single,
        bytes: bytes,
        fileName: fileName,
      );
      return;
    }

    final rows = await _client
        .from('transaction_requests')
        .select(
          'id, importador_id, status, proveedor_factura_storage_path, checkout_group_id',
        )
        .inFilter('id', ids);

    final list = rows as List<dynamic>;
    if (list.length != ids.length) {
      throw StateError(
        'No se encontraron todas las líneas del carrito; actualice la lista.',
      );
    }

    final parsed = list
        .map((e) {
          if (e is! Map) return null;
          return Map<String, dynamic>.from(e);
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    String? checkoutGroupId;
    for (final m in parsed) {
      if (m['importador_id']?.toString() != uid) {
        throw StateError('No autorizado: las líneas deben ser de su almacén.');
      }
      final st = m['status']?.toString();
      if (st != TransactionRequestStatus.pendiente &&
          st != TransactionRequestStatus.enPreparacion &&
          st != TransactionRequestStatus.pedidoListo) {
        throw StateError(
          'Solo puede adjuntar la factura mientras todas las líneas están pendientes, '
          'en preparación o listas para despacho.',
        );
      }
      final cg =
          m['checkout_group_id']?.toString().trim();
      if (cg == null || cg.isEmpty) {
        throw StateError(
          'Las líneas del carrito no comparten checkout; use adjuntar por pedido.',
        );
      }
      checkoutGroupId ??= cg;
      if (checkoutGroupId != cg) {
        throw StateError('Las líneas no pertenecen al mismo carrito (checkout).');
      }
    }

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) {
      safeBase = 'factura.$ext';
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path =
        'bundle_${checkoutGroupId!}/${stamp}_$safeBase';

    final oldPaths = <String>{};
    for (final m in parsed) {
      final op =
          m['proveedor_factura_storage_path']?.toString().trim();
      if (op != null && op.isNotEmpty) {
        oldPaths.add(op);
      }
    }
    for (final op in oldPaths) {
      try {
        await _client.storage.from(_orderInvoicesBucket).remove([op]);
      } catch (_) {}
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderInvoicesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('transaction_requests').update({
      'proveedor_factura_storage_path': path,
      'proveedor_factura_file_name': fileName.trim(),
      'proveedor_factura_submitted_at': now,
      'updated_at': now,
    }).inFilter('id', ids);
  }

  /// Importador: sube o reemplaza la factura digital mientras el pedido está en preparación
  /// y antes de que MotoLink confirme la factura oficial al aliado.
  /// Con [subOrderId], actualiza el sub-pedido (pedido maestro).
  static Future<void> importerSubmitOrderInvoice({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
    String? subOrderId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    var sid = subOrderId?.trim();
    if (sid == null || sid.isEmpty) {
      // Fallback útil en detalle por ID maestro (sin _importer_sub_order_id en memoria).
      final srow = await _client
          .from('sub_orders')
          .select('id')
          .eq('parent_order_id', transactionRequestId)
          .eq('importador_id', uid)
          .eq('status', SubOrderStatus.preparando)
          .maybeSingle();
      if (srow != null) {
        sid = srow['id']?.toString().trim();
      }
    }
    if (sid != null && sid.isNotEmpty) {
      final srow = await _client
          .from('sub_orders')
          .select(
            'id, importador_id, status, proveedor_factura_storage_path, parent_order_id, transaction_requests!inner ( factura_aliado_storage_path )',
          )
          .eq('id', sid)
          .maybeSingle();

      if (srow == null) {
        throw StateError('Sub-pedido no encontrado.');
      }
      final sm = Map<String, dynamic>.from(srow);
      if (sm['importador_id']?.toString() != uid) {
        throw StateError('No autorizado a adjuntar factura en este sub-pedido.');
      }
      if (sm['status']?.toString() != SubOrderStatus.preparando) {
        throw StateError(
          'Solo puede adjuntar la factura mientras el sub-pedido está en preparación.',
        );
      }
      final tr = sm['transaction_requests'];
      String? fa;
      if (tr is Map) {
        fa = tr['factura_aliado_storage_path']?.toString().trim();
      }
      if (fa != null && fa.isNotEmpty) {
        throw StateError(
          'MotoLink ya confirmó la factura al aliado; no puede reemplazar la factura del proveedor.',
        );
      }

      final ext = _profileDocExtension(fileName);
      if (!_isAllowedProfileDocExtension(ext)) {
        throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
      }

      var safeBase =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
      if (safeBase.isEmpty) {
        safeBase = 'factura.$ext';
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final path = '$transactionRequestId/sub_$sid/${stamp}_$safeBase';

      final oldPath = sm['proveedor_factura_storage_path']?.toString().trim();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await _client.storage.from(_orderInvoicesBucket).remove([oldPath]);
        } catch (_) {}
      }

      final contentType = _mimeForProfileDocExtension(ext);
      await _client.storage.from(_orderInvoicesBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      await _client.from('sub_orders').update({
        'proveedor_factura_storage_path': path,
        'proveedor_factura_file_name': fileName.trim(),
        'proveedor_factura_submitted_at':
            DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sid);
      return;
    }

    final row = await _client
        .from('transaction_requests')
        .select(
          'owner_id, status, proveedor_factura_storage_path, factura_aliado_storage_path',
        )
        .eq('id', transactionRequestId)
        .maybeSingle();

    if (row == null) {
      throw StateError('Pedido no encontrado.');
    }
    final m = Map<String, dynamic>.from(row);
    if (m['owner_id']?.toString() != uid) {
      throw StateError('No autorizado a adjuntar factura en este pedido.');
    }
    if (m['status']?.toString() != TransactionRequestStatus.enPreparacion) {
      throw StateError(
        'Solo puede adjuntar la factura mientras el pedido está en preparación.',
      );
    }
    final facturaAliadoPath = m['factura_aliado_storage_path']?.toString().trim();
    if (facturaAliadoPath != null && facturaAliadoPath.isNotEmpty) {
      throw StateError(
        'MotoLink ya confirmó la factura del pedido; no puede reemplazar la factura del proveedor.',
      );
    }

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) {
      safeBase = 'factura.$ext';
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final oldPath = m['proveedor_factura_storage_path']?.toString().trim();
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await _client.storage.from(_orderInvoicesBucket).remove([oldPath]);
      } catch (_) {}
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderInvoicesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    await _client.from('transaction_requests').update({
      'proveedor_factura_storage_path': path,
      'proveedor_factura_file_name': fileName.trim(),
      'proveedor_factura_submitted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', transactionRequestId);
  }

  /// Importador: `pedido_listo` → `en_transito` con ETA obligatorio (días 0–365, horas 0–23).
  static Future<void> importerMarcaPedidoEnTransito({
    required String requestId,
    required int transitEtaDays,
    required int transitEtaHours,
  }) async {
    await _client.rpc(
      'importer_marca_pedido_en_transito',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_transit_eta_days': transitEtaDays,
        'p_transit_eta_hours': transitEtaHours,
      },
    );
  }

  /// MotoLink: pasa el pedido a `en_transito`. [transitEtaDays]/[transitEtaHours] son opcionales
  /// (por defecto 0); el ETA en vivo se espera en el enlace de Google Maps del pedido.
  static Future<void> adminMarcaPedidoEnTransito({
    required String requestId,
    int transitEtaDays = 0,
    int transitEtaHours = 0,
  }) async {
    await _client.rpc(
      'admin_marca_pedido_en_transito',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_transit_eta_days': transitEtaDays,
        'p_transit_eta_hours': transitEtaHours,
      },
    );
  }

  /// MotoLink: guarda o borra el enlace de Google Maps de la ruta unificada
  /// (visible a aliado e importador en tránsito).
  static Future<void> adminSetTransactionRequestRutaMapsUrl({
    required String requestId,
    required String? urlOrNull,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final profile = await fetchMyProfile();
    if (profile?.role?.trim().toLowerCase() != 'administrador') {
      throw StateError('Solo MotoLink puede publicar el enlace de ruta.');
    }

    final row = await _client
        .from('transaction_requests')
        .select('status')
        .eq('id', requestId)
        .maybeSingle();
    if (row == null) throw StateError('Pedido no encontrado.');
    final st = Map<String, dynamic>.from(row)['status']?.toString();
    if (!TransactionRequestStatus.adminOperationalActive.contains(st)) {
      throw StateError(
        'El enlace de ruta solo se puede editar mientras el pedido está activo en fulfillment.',
      );
    }

    final trimmed = urlOrNull?.trim();
    String? stored;
    if (trimmed == null || trimmed.isEmpty) {
      stored = null;
    } else {
      final uri = Uri.tryParse(trimmed);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw ArgumentError('Use una URL http(s) válida o deje el campo vacío.');
      }
      stored = trimmed;
    }

    await _client.from('transaction_requests').update({
      'admin_ruta_maps_url': stored,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  static const _trMessagesSelect =
      'id, transaction_request_id, author_id, author_role, body, created_at';

  static Future<List<TransactionRequestMessageModel>>
      fetchTransactionRequestMessages(String transactionRequestId) async {
    if (transactionRequestId.isEmpty) return [];

    final response = await _client
        .from('transaction_request_messages')
        .select(_trMessagesSelect)
        .eq('transaction_request_id', transactionRequestId)
        .order('created_at', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestMessageModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  /// Mensajes de varias líneas del mismo carrito/importador, ordenados por fecha.
  static Future<List<TransactionRequestMessageModel>>
      fetchTransactionRequestMessagesForRequests(
    List<String> transactionRequestIds,
  ) async {
    final ids = transactionRequestIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return [];
    if (ids.length == 1) {
      return fetchTransactionRequestMessages(ids.single);
    }
    final response = await _client
        .from('transaction_request_messages')
        .select(_trMessagesSelect)
        .inFilter('transaction_request_id', ids)
        .order('created_at', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map(
          (row) => TransactionRequestMessageModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  /// Un canal Realtime por solicitud; desuscribir cada uno con [unsubscribeChannel].
  static List<RealtimeChannel> subscribeToTransactionRequestMessagesMany({
    required List<String> transactionRequestIds,
    required void Function() onInsert,
  }) {
    final out = <RealtimeChannel>[];
    for (final raw in transactionRequestIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      out.add(
        subscribeToTransactionRequestMessages(
          transactionRequestId: id,
          onInsert: onInsert,
        ),
      );
    }
    return out;
  }

  /// Documentos KYC aprobados de una contraparte con la que el usuario comparte pedido.
  static Future<List<ProfileDocumentModel>> fetchCounterpartyProfileDocuments(
    String counterpartyProfileId,
  ) async {
    final pid = counterpartyProfileId.trim();
    if (pid.isEmpty) return [];

    final response = await _client
        .from('profile_documents')
        .select(_profileDocumentsSelect)
        .eq('profile_id', pid)
        .eq('is_current', true)
        .eq('review_status', DocumentReviewStatus.aprobado)
        .order('doc_type', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map(
          (row) => ProfileDocumentModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<void> insertTransactionRequestMessageAsImportador({
    required String transactionRequestId,
    required String body,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final t = body.trim();
    if (t.isEmpty) return;

    await _client.from('transaction_request_messages').insert({
      'transaction_request_id': transactionRequestId,
      'author_id': uid,
      'author_role': 'importador',
      'body': t,
    });
  }

  static Future<void> insertTransactionRequestMessageAsAliado({
    required String transactionRequestId,
    required String body,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final t = body.trim();
    if (t.isEmpty) return;

    await _client.from('transaction_request_messages').insert({
      'transaction_request_id': transactionRequestId,
      'author_id': uid,
      'author_role': 'aliado',
      'body': t,
    });
  }

  static Future<void> insertTransactionRequestMessageAsAdmin({
    required String transactionRequestId,
    required String body,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final t = body.trim();
    if (t.isEmpty) return;

    await _client.from('transaction_request_messages').insert({
      'transaction_request_id': transactionRequestId,
      'author_id': uid,
      'author_role': 'administrador',
      'body': t,
    });
  }

  /// Admin MotoLink: anula un pedido ya aprobado / en curso (no pendiente ni entregado), con motivo.
  static Future<void> adminAnulaPedidoPorMotolink({
    required String transactionRequestId,
    required String motivo,
  }) async {
    final t = motivo.trim();
    if (t.length < 3) {
      throw ArgumentError('Indique un motivo de al menos 3 caracteres.');
    }
    await _client.rpc(
      'admin_anula_pedido_por_motolink',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_motivo': t,
      },
    );
  }

  /// Aliado: cancela pedido en `pendiente` (antes de aprobación MotoLink), con motivo.
  static Future<void> aliadoCancelaPedidoPendiente({
    required String transactionRequestId,
    required String motivo,
  }) async {
    final t = motivo.trim();
    if (t.length < 3) {
      throw ArgumentError('Indique un motivo de al menos 3 caracteres.');
    }
    await _client.rpc(
      'aliado_cancela_pedido_pendiente',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_motivo': t,
      },
    );
  }

  /// Importador: acuerda 1–3 cuotas cuya suma = total del pedido; notifica en el chat.
  static Future<void> importerConfirmOrderCreditPlan({
    required String transactionRequestId,
    required List<double> amountsUsd,
    required bool montosPersonalizados,
  }) async {
    if (amountsUsd.isEmpty || amountsUsd.length > 3) {
      throw ArgumentError('Debe indicar 1, 2 o 3 importes de cuota.');
    }
    final n = amountsUsd.length;
    var suma = 0.0;
    for (final a in amountsUsd) {
      suma += a;
    }
    await _client.rpc(
      'importer_confirm_order_credit_plan',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_amounts_usd': amountsUsd,
      },
    );
    DateTime? confirmadoEn;
    final trRow = await _client
        .from('transaction_requests')
        .select('credit_plan_confirmed_at')
        .eq('id', transactionRequestId)
        .maybeSingle();
    if (trRow != null) {
      final raw = Map<String, dynamic>.from(trRow)['credit_plan_confirmed_at'];
      if (raw is String) {
        confirmadoEn = DateTime.tryParse(raw);
      }
    }
    final atStr = formatEsShortDateTime(confirmadoEn);
    final w = StringBuffer();
    if (n == 1) {
      w.write(
        'Acordamos 1 cuota (contado) por ${suma.toStringAsFixed(2)} REF. ',
      );
    } else {
      w.write(
        'Acordamos $n cuotas (cada 15 días) por un total de '
        '${suma.toStringAsFixed(2)} REF. ',
      );
    }
    if (montosPersonalizados) {
      w.write('Desglose personalizado. ');
    }
    w.write(
      'Confirmado: $atStr. Revise la sección Pago del pedido para vencimientos y comprobantes.',
    );
    await insertTransactionRequestMessageAsImportador(
      transactionRequestId: transactionRequestId,
      body: w.toString(),
    );
  }

  /// @deprecated Use [importerConfirmOrderCreditPlan]. Conservado por compatibilidad interna.
  static Future<void> confirmOrderCreditPlan({
    required String transactionRequestId,
    required List<double> amountsUsd,
    required bool montosPersonalizados,
  }) =>
      importerConfirmOrderCreditPlan(
        transactionRequestId: transactionRequestId,
        amountsUsd: amountsUsd,
        montosPersonalizados: montosPersonalizados,
      );

  /// Sólo total del pedido (hilo de chat / cupo de cuotas).
  static Future<double?> fetchTransactionRequestPrecioTotal(
    String transactionRequestId,
  ) async {
    final id = transactionRequestId.trim();
    if (id.isEmpty) return null;
    final row = await _client
        .from('transaction_requests')
        .select('precio_total_usd')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final pt = Map<String, dynamic>.from(row)['precio_total_usd'];
    if (pt is num) return pt.toDouble();
    return double.tryParse(pt?.toString() ?? '');
  }

  /// Comprobante asociado a una fila de [payment_schedule].
  static Future<void> aliadoSubmitComprobantePagoCuota({
    required String paymentScheduleId,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }
    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final row0 = await _client
        .from('payment_schedule')
        .select('transaction_request_id, pago_comprobante_storage_path')
        .eq('id', paymentScheduleId)
        .maybeSingle();
    if (row0 == null) throw StateError('Cuota no encontrada.');
    final m0 = Map<String, dynamic>.from(row0);
    final trid = m0['transaction_request_id']?.toString() ?? '';
    if (trid.isEmpty) throw StateError('Pedido de cuota no válido.');
    final oldPath = m0['pago_comprobante_storage_path']?.toString().trim();

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$trid/cuota_${paymentScheduleId}_${stamp}_$safeBase';
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await _client.storage.from(_orderPaymentProofsBucket).remove([oldPath]);
      } catch (_) {}
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderPaymentProofsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    try {
      await _client.rpc(
        'aliado_registra_comprobante_pago_cuota',
        params: <String, dynamic>{
          'p_schedule_id': paymentScheduleId,
          'p_metodo': metodo,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await _client.storage.from(_orderPaymentProofsBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> adminAprobarPagoAliadoCuota(String paymentScheduleId) async {
    await _client.rpc(
      'admin_aprobar_pago_aliado_cuota',
      params: <String, dynamic>{'p_schedule_id': paymentScheduleId},
    );
  }

  static Future<void> adminRechazarComprobantePagoCuota({
    required String paymentScheduleId,
    required String nota,
  }) async {
    await _client.rpc(
      'admin_rechazar_comprobante_pago_cuota',
      params: <String, dynamic>{
        'p_schedule_id': paymentScheduleId,
        'p_nota': nota.trim(),
      },
    );
  }

  /// Cierra el pedido (aliado): `en_transito` → `entregado` (RPC en base de datos).
  static Future<void> aliadoMarcarPedidoEntregado(String transactionRequestId) async {
    await _client.rpc(
      'aliado_marca_pedido_entregado',
      params: {'p_request_id': transactionRequestId},
    );
  }

  /// Cierra todas las líneas `en_transito` | `enviado` del mismo importador en un carrito.
  static Future<int> aliadoMarcarPedidosEntregadosImportadorEnGrupo({
    required String checkoutGroupId,
    required String importadorId,
  }) async {
    final res = await _client.rpc(
      'aliado_marca_pedidos_entregados_importador_en_grupo',
      params: <String, dynamic>{
        'p_checkout_group_id': checkoutGroupId,
        'p_importador_id': importadorId,
      },
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return int.tryParse(res?.toString() ?? '') ?? 0;
  }

  /// A6: calificación por proveedor cuando varias líneas comparten carrito.
  static Future<void> aliadoSubmitOrderExperienceImportadorGrupo({
    required String checkoutGroupId,
    required String importadorId,
    required int stars,
    String? comment,
  }) async {
    await _client.rpc(
      'aliado_submit_order_experience_importador_grupo',
      params: <String, dynamic>{
        'p_checkout_group_id': checkoutGroupId,
        'p_importador_id': importadorId,
        'p_stars': stars,
        'p_comment': comment?.trim() ?? '',
      },
    );
  }

  /// A6: nota de entrega vs factura fiscal (una sola vez; vía RPC).
  static Future<void> aliadoSetDocumentTypePreference({
    required String transactionRequestId,
    required String documentType,
  }) async {
    await _client.rpc(
      'aliado_set_document_type_preference',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_type': documentType,
      },
    );
  }

  /// A6: calificación y comentario breve tras entrega (una sola vez).
  static Future<void> aliadoSubmitOrderExperience({
    required String transactionRequestId,
    required int stars,
    String? comment,
  }) async {
    await _client.rpc(
      'aliado_submit_order_experience',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_stars': stars,
        'p_comment': comment?.trim() ?? '',
      },
    );
  }

  /// Si falta en la vista (p. ej. ficha cargada solo por ID maestro), resuelve el
  /// sub-pedido del importador actual para aplicar la misma transición.
  static Future<String?> _resolveImporterSubOrderIdForAdvance({
    required String parentOrderId,
    required String newTransactionStatus,
  }) async {
    return null;
  }

  /// Avanza el estado del pedido (importador): pendiente → preparación → listo para despacho
  /// → en tránsito (despacho).
  /// Con [importerSubOrderId] (pedido maestro), actualiza el sub-pedido vía RPC.
  static Future<void> importerAdvanceTransactionRequest({
    required String id,
    required String newStatus,
    String? importerSubOrderId,
  }) async {
    var sid = importerSubOrderId?.trim();
    if (sid == null || sid.isEmpty) {
      sid = await _resolveImporterSubOrderIdForAdvance(
        parentOrderId: id,
        newTransactionStatus: newStatus,
      );
    }
    if (sid != null && sid.isNotEmpty) {
      final subSt = _subStatusFromImporterAdvance(newStatus);
      if (subSt == null) {
        throw StateError('Transición no aplicable al sub-pedido.');
      }
      await importerAdvanceSubOrder(subOrderId: sid, newSubStatus: subSt);
      return;
    }

    final rows = await _client.from('transaction_requests').update({
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).select('id');
    final list = rows as List<dynamic>?;
    if (list == null || list.isEmpty) {
      throw StateError(
        'No se actualizó ninguna fila. Revisa que la migración de trazabilidad esté '
        'aplicada en Supabase, que el pedido sea de tu inventario y que la transición '
        'sea válida (aprobado → en preparación → …).',
      );
    }
  }

  /// Obtiene repuestos desde [products] con paginacion.
  /// Incluye nombre del importador vía FK `owner_id` → `profiles`.
  static Future<List<PartModel>> fetchParts({
    int limit = 6,
    int offset = 0,
    CatalogFilters? filters,
  }) async {
    final f = filters ?? CatalogFilters.empty;
    final locIds = await _importerProfileIdsForSearchLocation(f);
    final embed = _catalogProfileSelect(f);
    dynamic query = _client.from('products').select('*, $embed');
    query = _applyCatalogFilters(query, f, searchLocationImporterIds: locIds);

    if (f.sortByDistanceFromReference) {
      const cap = 800;
      final response = await query.limit(cap);
      final list = response as List<dynamic>;
      final refLat = f.sortReferenceLat!;
      final refLng = f.sortReferenceLng!;
      final withDist = list.map((row) {
        final p = PartModel.fromJson(row as Map<String, dynamic>);
        final km = Haversine.distanceKm(
          refLat,
          refLng,
          p.ownerLatitude,
          p.ownerLongitude,
        );
        return p.copyWith(distanceKmFromReference: km);
      }).toList()
        ..sort((a, b) {
          final da = a.distanceKmFromReference;
          final db = b.distanceKmFromReference;
          if (da == null && db == null) return a.id.compareTo(b.id);
          if (da == null) return 1;
          if (db == null) return -1;
          final c = da.compareTo(db);
          if (c != 0) return c;
          return a.id.compareTo(b.id);
        });
      if (offset >= withDist.length) return [];
      final end = (offset + limit).clamp(0, withDist.length);
      return withDist.sublist(offset, end);
    }

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
    return input
        .replaceAll('%', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'[(),.]'), ' ')
        .trim();
  }

  /// PostgREST no puede parsear `profiles.estado` / `profiles.ciudad` dentro de
  /// un `or` en `products` (PGRST100). Buscamos importadores cuyo estado o
  /// ciudad coincidan y unimos con `owner_id.in.(…)`.
  static const _maxSearchLocationImporterIds = 120;

  static Future<List<String>> _importerProfileIdsForSearchLocation(
    CatalogFilters filters,
  ) async {
    final search = filters.searchQuery?.trim();
    if (search == null || search.isEmpty) return const [];
    final safe = _sanitizeIlike(search);
    if (safe.isEmpty) return const [];
    final pat = '*$safe*';
    try {
      final res = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'importador')
          .or('estado.ilike.$pat,ciudad.ilike.$pat');
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
  }) {
    var q = query;
    final search = filters.searchQuery?.trim();
    if (search != null && search.isNotEmpty) {
      final safe = _sanitizeIlike(search);
      if (safe.isNotEmpty) {
        final pat = '*$safe*';
        if (searchLocationImporterIds.isNotEmpty) {
          final inList = searchLocationImporterIds.join(',');
          q = q.or(
            'name.ilike.$pat,owner_id.in.($inList)',
          );
        } else {
      q = q.ilike('name', '%$safe%');
        }
      }
    }
    final est = filters.ownerEstado?.trim();
    if (est != null && est.isNotEmpty) {
      final s = _sanitizeIlike(est);
      if (s.isNotEmpty) {
        q = q.filter('profiles.estado', 'ilike', '%$s%');
      }
    }
    final ciu = filters.ownerCiudad?.trim();
    if (ciu != null && ciu.isNotEmpty) {
      final s = _sanitizeIlike(ciu);
      if (s.isNotEmpty) {
        q = q.filter('profiles.ciudad', 'ilike', '%$s%');
      }
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
    if (filters.onlyActiveProducts) {
      q = q.eq('is_active', true);
    }
    // Catálogo B2B (aliados): no listar productos sin inventario.
    q = q.gt('stock', 0);
    return q;
  }

  static const _commissionSettlementSelect = '''
    id,
    importador_id,
    period_start,
    period_end,
    total_commission_usd,
    line_count,
    status,
    invoice_reference,
    issued_at,
    paid_at,
    notes,
    created_at,
    pago_comprobante_storage_path,
    pago_comprobante_file_name,
    pago_comprobante_submitted_at,
    pago_estado_revision,
    pago_rechazo_nota,
    invoice_pdf_storage_path,
    invoice_pdf_file_name,
    importador:profiles!commission_settlements_importador_id_fkey (
      business_name,
      rif,
      direccion,
      estado,
      ciudad,
      phone
    )
  ''';

  /// Tasa global MotoLink (fracción; 0.05 = 5 %).
  static Future<double> fetchDefaultCommissionRate() async {
    final row = await _client
        .from('platform_settings')
        .select('value')
        .eq('key', 'default_commission_rate')
        .maybeSingle();
    if (row == null) return 0.05;
    final v = row['value'];
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.05;
  }

  static Future<void> adminSetDefaultCommissionRate(double rate) async {
    await _client.rpc(
      'admin_set_default_commission_rate',
      params: <String, dynamic>{'p_rate': rate},
    );
  }

  static Future<void> adminSetImportadorCommissionRate({
    required String importadorId,
    double? rate,
  }) async {
    await _client.rpc(
      'admin_set_importador_commission_rate',
      params: <String, dynamic>{
        'p_importador_id': importadorId,
        'p_rate': rate,
      },
    );
  }

  /// Cortes de comisión (admin: todos; importador: solo los propios vía RLS).
  static Future<List<CommissionSettlementModel>> fetchCommissionSettlements({
    int limit = 80,
  }) async {
    final response = await _client
        .from('commission_settlements')
        .select(_commissionSettlementSelect)
        .order('period_start', ascending: false)
        .limit(limit);
    final list = response as List<dynamic>;
    return list
        .map((e) => CommissionSettlementModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  static Future<List<CommissionSettlementLineModel>>
      fetchCommissionSettlementLines(String settlementId) async {
    final response = await _client
        .from('transaction_requests')
        .select('''
          id,
          precio_total_usd,
          comision_devengada_usd,
          comision_devengada_at,
          checkout_group_id,
          products ( name )
        ''')
        .eq('commission_settlement_id', settlementId)
        .order('comision_devengada_at', ascending: true);
    final list = response as List<dynamic>;
    return list
        .map((e) => CommissionSettlementLineModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Genera cortes en borrador para la semana en curso (lunes–domingo).
  static Future<Map<String, dynamic>>
      adminGenerateCommissionSettlementsCurrentWeek() async {
    final raw = await _client.rpc(
      'admin_generate_commission_settlements_current_week',
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  /// Genera cortes en borrador para la semana [weekStart] (lunes). Si es null, la RPC usa la semana anterior.
  static Future<Map<String, dynamic>> adminGenerateCommissionSettlementsWeek({
    DateTime? weekStart,
  }) async {
    final params = <String, dynamic>{};
    if (weekStart != null) {
      params['p_week_start'] =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    }
    final raw = await _client.rpc(
      'admin_generate_commission_settlements_week',
      params: params,
    );
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static Future<String> createSignedUrlForCommissionInvoicePdf(
    String storagePath,
  ) async {
    final p = storagePath.trim();
    if (p.isEmpty) throw ArgumentError('Ruta de PDF vacía.');
    return _client.storage
        .from(_commissionSettlementInvoicesBucket)
        .createSignedUrl(p, 3600);
  }

  /// Genera el PDF de comisión y lo sube a Storage (admin, tras emitir corte).
  static Future<void> generateAndUploadCommissionSettlementInvoicePdf({
    required CommissionSettlementModel settlement,
  }) async {
    final lines = await fetchCommissionSettlementLines(settlement.id);
    if (lines.isEmpty) {
      throw StateError('El corte no tiene líneas para la factura PDF.');
    }

    Map<String, dynamic>? impMap;
    final row = await _client
        .from('commission_settlements')
        .select('''
          importador:profiles!commission_settlements_importador_id_fkey (
            direccion, estado, ciudad, phone
          )
        ''')
        .eq('id', settlement.id)
        .maybeSingle();
    if (row != null) {
      final imp = row['importador'];
      if (imp is Map) impMap = Map<String, dynamic>.from(imp);
    }

    final tasa = await fetchGlobalTasaBcv() ?? 1.0;
    final ref = settlement.invoiceReference?.trim();
    final safeRef = (ref != null && ref.isNotEmpty)
        ? ref.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        : settlement.id.substring(0, 8);
    final fileName = 'MotoLink_comision_$safeRef.pdf';
    final path = '${settlement.id}/$fileName';

    final oldPath = settlement.invoicePdfStoragePath?.trim();
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await _client.storage
            .from(_commissionSettlementInvoicesBucket)
            .remove([oldPath]);
      } catch (_) {}
    }

    final bytes = await MotolinkCommissionInvoicePdfService.build(
      settlement: settlement,
      lines: lines,
      tasaBcvEmision: tasa,
      importadorDireccion: impMap?['direccion']?.toString(),
      importadorEstado: impMap?['estado']?.toString(),
      importadorCiudad: impMap?['ciudad']?.toString(),
      importadorPhone: impMap?['phone']?.toString(),
    );

    await _client.storage.from(_commissionSettlementInvoicesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    await _client.rpc(
      'admin_attach_commission_invoice_pdf',
      params: <String, dynamic>{
        'p_settlement_id': settlement.id,
        'p_storage_path': path,
        'p_file_name': fileName,
      },
    );
  }

  /// Vista previa del siguiente Nº de factura de comisión (sin consumir secuencia).
  static Future<String> peekCommissionInvoiceReference() async {
    final raw = await _client.rpc('motoconecta_peek_commission_invoice_reference');
    return raw?.toString().trim() ?? '';
  }

  /// Emite el corte. Si [invoiceReference] es null/vacío, la BD asigna ML-COM-{año}-{seq}.
  static Future<String> adminIssueCommissionSettlement({
    required String settlementId,
    String? invoiceReference,
  }) async {
    final params = <String, dynamic>{'p_settlement_id': settlementId};
    final manual = invoiceReference?.trim();
    if (manual != null && manual.isNotEmpty) {
      params['p_invoice_reference'] = manual;
    }
    final raw = await _client.rpc(
      'admin_issue_commission_settlement',
      params: params,
    );
    return raw?.toString().trim() ?? '';
  }

  /// Importador: sube comprobante y envía a revisión MotoLink.
  static Future<void> importadorSubmitCommissionSettlementPago({
    required String settlementId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = _profileDocExtension(fileName);
    if (!_isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }

    var safeBase =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = 'commission-settlements/$settlementId/${stamp}_$safeBase';

    final row = await _client
        .from('commission_settlements')
        .select('pago_comprobante_storage_path, pago_estado_revision, status')
        .eq('id', settlementId)
        .eq('importador_id', uid)
        .maybeSingle();
    if (row != null) {
      final m = Map<String, dynamic>.from(row);
      final pe = m['pago_estado_revision']?.toString().trim();
      if (pe == PagoRevisionEstado.enRevision) {
        throw StateError('Ya hay un comprobante en revisión.');
      }
      if (m['status']?.toString() == 'pagado') {
        throw StateError('Este corte ya está pagado.');
      }
      final oldPath = m['pago_comprobante_storage_path']?.toString().trim();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await _client.storage.from(_orderPaymentProofsBucket).remove([oldPath]);
        } catch (_) {}
      }
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_orderPaymentProofsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await _client.rpc(
        'importador_registra_pago_comision_corte',
        params: <String, dynamic>{
          'p_settlement_id': settlementId,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await _client.storage.from(_orderPaymentProofsBucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> adminApproveCommissionSettlementPago(
    String settlementId,
  ) async {
    await _client.rpc(
      'admin_approve_commission_settlement_pago',
      params: <String, dynamic>{'p_settlement_id': settlementId},
    );
  }

  static Future<void> adminRejectCommissionSettlementPago({
    required String settlementId,
    String? nota,
  }) async {
    await _client.rpc(
      'admin_reject_commission_settlement_pago',
      params: <String, dynamic>{
        'p_settlement_id': settlementId,
        'p_nota': nota?.trim(),
      },
    );
  }

  static Future<void> adminMarkCommissionSettlementPaid(String settlementId) async {
    await _client.rpc(
      'admin_mark_commission_settlement_paid',
      params: <String, dynamic>{'p_settlement_id': settlementId},
    );
  }

  static Future<void> adminCancelCommissionSettlement(String settlementId) async {
    await _client.rpc(
      'admin_cancel_commission_settlement',
      params: <String, dynamic>{'p_settlement_id': settlementId},
    );
  }
}

/// Totales para tarjetas del dashboard de inventario.
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

class NotificationOrderSummary {
  const NotificationOrderSummary({
    this.productName,
    this.aliadoBusinessName,
  });

  final String? productName;
  final String? aliadoBusinessName;
}

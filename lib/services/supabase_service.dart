import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_phase_exception.dart';
import '../models/cash_phase_policy.dart';
import '../models/catalog_filters.dart';
import '../models/credit_limit_exception.dart';
import '../models/kyc_status.dart';
import '../models/kyc_verification_exception.dart';
import '../models/part_model.dart';
import '../models/profile_document_model.dart';
import '../models/profile_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../utils/broker_pricing.dart';

class SupabaseService {
  SupabaseService._();

  static const _productImagesBucket = 'product-images';
  static const _profileDocumentsBucket = 'profile-documents';

  /// Comisión MotoLink sobre precio mayorista (misma base que [BrokerPricing.feeRate]).
  static double get logisticFeeRate => BrokerPricing.feeRate;

  static double calculateAliadoUnitPrice(double precioUnitarioProveedor) {
    return BrokerPricing.finalUnitPrice(precioUnitarioProveedor);
  }

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
  /// (`importador` / `aliado` / `administrador`). Tras la primera asignación,
  /// los updates omiten `role` para que no pueda cambiarse desde el cliente.
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
    dynamic q = _client.from('products').select('id');
    q = _applyCatalogFilters(q, f);
    final res = await q.count(CountOption.exact);
    return (res as PostgrestResponse<dynamic>).count;
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

  static const _trSelect = '''
    id,
    aliado_id,
    product_id,
    owner_id,
    status,
    cantidad,
    precio_unitario_proveedor,
    precio_unitario_aliado,
    precio_total,
    notas_admin,
    created_at,
    updated_at,
    at_aprobado_admin,
    at_rechazado,
    at_en_preparacion,
    at_en_transito,
    at_entregado,
    products ( name, sku, price_usd ),
    aliado:profiles!transaction_requests_aliado_id_fkey ( business_name, rif, credit_score, phone ),
    owner:profiles!transaction_requests_owner_id_fkey ( business_name, rif, phone )
  ''';

  /// Solicitudes del aliado autenticado (todas).
  static Future<List<TransactionRequestModel>> fetchMyTransactionRequests() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .eq('aliado_id', uid)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Aliado: pendientes de validación MotoLink (pestaña Solicitudes).
  static Future<List<TransactionRequestModel>>
      fetchMyPendingValidationForAliado() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .eq('aliado_id', uid)
        .eq('status', TransactionRequestStatus.pendiente)
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
        .select(_trSelect)
        .eq('aliado_id', uid)
        .inFilter('status', TransactionRequestStatus.aliadoPedidosActivosYCerrados)
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Aprobados por MotoLink pendientes de la primera acción del importador (pestaña Validados).
  static Future<List<TransactionRequestModel>>
      fetchValidatedTransactionRequestsForImporter() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .eq('owner_id', uid)
        .inFilter('status', TransactionRequestStatus.importerSoloValidadosAdmin)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Ciclo completo post-validación: aprobado → … → entregado (pestaña Pedidos).
  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForImporter() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .eq('owner_id', uid)
        .inFilter('status', TransactionRequestStatus.importerPipeline)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Solo aprobados por MotoLink para un producto (importador dueño vía RLS).
  static Future<List<TransactionRequestModel>>
      fetchValidatedTransactionRequestsForProduct(String productId) async {
    if (productId.isEmpty) return [];

    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .eq('product_id', productId)
        .inFilter('status', TransactionRequestStatus.importerSoloValidadosAdmin)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Bandeja admin: todas las solicitudes.
  static Future<List<TransactionRequestModel>>
      fetchTransactionRequestsForAdmin() async {
    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Pedidos en curso tras validación MotoLink (pestaña Pedidos activos — admin).
  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForAdmin() async {
    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .inFilter('status', TransactionRequestStatus.adminOperationalActive)
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Solicitudes pendientes de aprobación/rechazo (pestaña Por validar — admin).
  static Future<List<TransactionRequestModel>>
      fetchPendingValidationForAdmin() async {
    final response = await _client
        .from('transaction_requests')
        .select(_trSelect)
        .inFilter('status', TransactionRequestStatus.adminPendingValidation)
        .order('created_at', ascending: false);

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
        .select(_trSelect)
        .inFilter('status', TransactionRequestStatus.adminClosedOrders)
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            TransactionRequestModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Perfiles aliado para asignar `credit_limit` (vista admin).
  static Future<List<ProfileModel>> fetchAliadoProfilesForAdmin() async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('role', 'aliado')
        .order('business_name', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            ProfileModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Broker: actualiza el cupo negociable del aliado (`profiles.credit_limit`).
  static Future<void> adminSetAliadoCreditLimit({
    required String aliadoId,
    required double creditLimit,
  }) async {
    await _client.rpc(
      'admin_set_aliado_credit_limit',
      params: <String, dynamic>{
        'p_aliado_id': aliadoId,
        'p_credit_limit': creditLimit,
      },
    );
  }

  /// Broker: actualiza estado KYC del aliado.
  static Future<void> adminSetAliadoKycStatus({
    required String aliadoId,
    required String status,
  }) async {
    await _client.rpc(
      'admin_set_aliado_kyc_status',
      params: <String, dynamic>{
        'p_aliado_id': aliadoId,
        'p_status': status,
      },
    );
  }

  /// Aliado: marca documentación en revisión (`en_revision`).
  static Future<void> aliadoSubmitKycForReview() async {
    await _client.rpc('aliado_submit_kyc_for_review');
  }

  /// Documentos subidos por el aliado autenticado.
  static Future<List<ProfileDocumentModel>> fetchMyProfileDocuments() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final response = await _client
        .from('profile_documents')
        .select()
        .eq('profile_id', uid)
        .order('doc_type', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            ProfileDocumentModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Admin: documentos de un aliado (paths en Storage).
  static Future<List<ProfileDocumentModel>> fetchProfileDocumentsForAliado(
    String aliadoId,
  ) async {
    if (aliadoId.isEmpty) return [];

    final response = await _client
        .from('profile_documents')
        .select()
        .eq('profile_id', aliadoId)
        .order('doc_type', ascending: true);

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

  /// Sube o reemplaza un documento KYC (PDF / imagen).
  static Future<void> uploadAliadoProfileDocument({
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

    final existing = await _client
        .from('profile_documents')
        .select('storage_path')
        .eq('profile_id', uid)
        .eq('doc_type', docType)
        .maybeSingle();

    if (existing != null) {
      final oldPath = Map<String, dynamic>.from(existing)['storage_path']
          ?.toString();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await _client.storage.from(_profileDocumentsBucket).remove([oldPath]);
        } catch (_) {}
      }
      await _client
          .from('profile_documents')
          .delete()
          .eq('profile_id', uid)
          .eq('doc_type', docType);
    }

    final contentType = _mimeForProfileDocExtension(ext);
    await _client.storage.from(_profileDocumentsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    await _client.from('profile_documents').insert({
      'profile_id': uid,
      'doc_type': docType,
      'storage_path': path,
      'file_name': fileName,
    });
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

  /// Suma `precio_total` de pedidos abiertos del aliado autenticado (vs. `credit_limit`).
  static Future<double> fetchOpenCreditExposureForCurrentAliado() async {
    final uid = _currentUserId;
    if (uid == null) return 0;

    final response = await _client
        .from('transaction_requests')
        .select('precio_total')
        .eq('aliado_id', uid)
        .inFilter('status', TransactionRequestStatus.aliadoCreditExposureStatuses);

    final list = response as List<dynamic>;
    var sum = 0.0;
    for (final row in list) {
      final m = Map<String, dynamic>.from(row as Map);
      final pt = m['precio_total'];
      if (pt is num) {
        sum += pt.toDouble();
      }
    }
    return sum;
  }

  /// Cantidad de pedidos abiertos (misma lista que el cupo).
  static Future<int> fetchOpenTransactionRequestCountForCurrentAliado() async {
    final uid = _currentUserId;
    if (uid == null) return 0;

    final response = await _client
        .from('transaction_requests')
        .select('id')
        .eq('aliado_id', uid)
        .inFilter('status', TransactionRequestStatus.aliadoCreditExposureStatuses);

    return (response as List<dynamic>).length;
  }

  static const double _creditTol = 0.01;

  static Future<void> insertTransactionRequest({
    required String productId,
    required String ownerId,
    required int cantidad,
    required double precioUnitarioProveedor,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final unitAliado = calculateAliadoUnitPrice(precioUnitarioProveedor);
    final total = unitAliado * cantidad;

    final profile = await fetchMyProfile();
    final role = profile?.role?.trim().toLowerCase();
    if (role != 'aliado') {
      throw StateError('Solo los aliados pueden crear solicitudes de pedido.');
    }
    final ks = profile?.kycStatus?.trim();
    if (ks != KycStatus.aprobado) {
      if (ks == KycStatus.enRevision) {
        throw KycVerificationException(
          'Su documentación está en revisión. MotoLink le avisará al aprobarla.',
        );
      }
      if (ks == KycStatus.rechazado) {
        throw KycVerificationException(
          'Su documentación fue rechazada. Actualice los archivos en su perfil y vuelva a enviar a revisión.',
        );
      }
      throw KycVerificationException(
        'Debe completar la verificación documental en su perfil y obtener la aprobación de MotoLink antes de pedir.',
      );
    }
    final limit = profile?.creditLimit;
    if (limit == null) {
      throw CreditLimitException(
        'MotoLink debe asignar un límite de crédito antes de solicitar pedidos. '
        'Cuando su cupo esté autorizado, podrá continuar.',
      );
    }
    final pce = profile?.primerosPedidosContadoEntregados ?? 0;
    if (pce < CashPhasePolicy.entregasRequeridas) {
      final openCnt = await fetchOpenTransactionRequestCountForCurrentAliado();
      if (openCnt >= 1) {
        throw CashPhaseException(
          'En los primeros ${CashPhasePolicy.entregasRequeridas} pedidos en contado solo puede '
          'tener un pedido activo a la vez. Cuando el actual se entregue o lo cancele con MotoLink, '
          'podrá solicitar otro.',
        );
      }
    }
    final exposure = await fetchOpenCreditExposureForCurrentAliado();
    if (exposure + total > limit + _creditTol) {
      throw CreditLimitException(
        'Este pedido (\$${total.toStringAsFixed(2)}) más su compromiso en pedidos '
        'abiertos (\$${exposure.toStringAsFixed(2)}) supera su límite autorizado '
        '(\$${limit.toStringAsFixed(2)}).',
      );
    }

    await _client.from('transaction_requests').insert({
      'aliado_id': uid,
      'product_id': productId,
      'owner_id': ownerId,
      'status': 'pendiente',
      'cantidad': cantidad,
      'precio_unitario_proveedor': precioUnitarioProveedor,
      'precio_unitario_aliado': unitAliado,
      'precio_total': total,
    });
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

  /// Avanza el estado del pedido (importador): cadena aprobado → preparación → tránsito → entregado.
  static Future<void> importerAdvanceTransactionRequest({
    required String id,
    required String newStatus,
  }) async {
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
    if (filters.onlyActiveProducts) {
      q = q.eq('is_active', true);
    }
    return q;
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

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/payments/payments_service.dart';
import 'package:motolink_pro_app/features/profile/profile_service.dart';
import 'package:motolink_pro_app/features/kyc/kyc_status.dart';
import 'package:motolink_pro_app/features/kyc/kyc_verification_exception.dart';
import 'package:motolink_pro_app/features/profile/profile_location_exception.dart';
import 'package:motolink_pro_app/features/orders/shared/stock_insufficient_exception.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_suspendidos_morosidad_exception.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_message_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

class OrdersService {
  OrdersService._();

  static Future<TransactionRequestModel?> fetchTransactionRequestById(
    String requestId,
  ) async {
    final id = requestId.trim();
    if (id.isEmpty) return null;
    final row = await SupabaseAccess.client
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
    final response = await SupabaseAccess.client
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

  /// Realtime: nuevos mensajes en el hilo de un pedido (misma tabla que inserta el chat).
  static RealtimeChannel subscribeToTransactionRequestMessages({
    required String transactionRequestId,
    required void Function() onInsert,
  }) {
    final id = transactionRequestId.trim();
    if (id.isEmpty) {
      throw ArgumentError('transactionRequestId vacío');
    }
    final channel = SupabaseAccess.client.channel('trm:req:$id');
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

  static const _trSelectMotoconecta = '''
    id,
    aliado_id,
    importador_id,
    product_id,
    products ( name, sku, discount_rules ),
    status,
    cantidad,
    precio_total_usd,
    precio_base_aliado_total,
    precio_unitario_proveedor,
    precio_unitario_aliado,
    commission_rate_snapshot,
    comision_devengada_usd,
    comision_devengada_at,
    commission_settlement_id,
    qty_adjustment_status,
    qty_adjustment_offered,
    qty_adjustment_note,
    qty_adjustment_solicitada_snapshot,
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
    original_checkout_group_id,
    discount_rules,
    confirmado_por,
    promo_campaign_id,
    promo_campaign:promo_campaigns ( display_title, internal_title, campaign_type ),
    importador_cancelacion_motivo,
    cancelado_por_aliado,
    aliado_cancelacion_motivo,
    aliado_experience_stars,
    aliado_experience_comment,
    aliado_experience_submitted_at,
    transit_eta_days,
    transit_eta_hours,
    transit_eta_set_at,
    at_aprobado_admin,
    at_rechazado,
    at_en_preparacion,
    at_pedido_listo,
    at_en_transito,
    at_entregado,
    importer_carrier_id,
    importer_carrier_driver_id,
    carrier_eta_hours_snapshot,
    carrier_distance_km_snapshot,
    carrier_fee_usd_snapshot,
    carrier_flete_pago_modo_snapshot,
    carrier_selected_at,
    carrier_company_name_snapshot,
    carrier_accepted_pago_metodos_snapshot,
    carrier_pago_instrucciones_snapshot,
    carrier_decision,
    carrier_decision_at,
    pickup_location_mode,
    pickup_confirmed_at,
    pickup_label,
    pickup_estado,
    pickup_ciudad,
    pickup_direccion,
    pickup_latitude,
    pickup_longitude,
    pickup_maps_url,
    pickup_location_id,
    pickup_carrier_id,
    flete_factura_storage_path,
    flete_factura_file_name,
    flete_factura_submitted_at,
    flete_pago_metodo,
    flete_comprobante_pago_storage_path,
    flete_comprobante_pago_file_name,
    flete_comprobante_submitted_at,
    flete_pago_estado_revision,
    flete_comprobante_rechazo_nota,
    flete_pago_aprobado_at,
    created_at,
    updated_at,
    aliado:profiles!transaction_requests_aliado_id_fkey ( business_name, rif, phone, estado, ciudad, direccion, fiscal_maps_url, latitude, longitude, logo_storage_path, kyc_status ),
    importer_carrier:importer_carriers!transaction_requests_importer_carrier_id_fkey ( company_name, contact_phone, flete_pago_modo, accepted_pago_metodos, pago_metodo_instrucciones ),
    importador:profiles!transaction_requests_importador_id_fkey ( business_name, rif, phone, estado, ciudad, direccion, fiscal_maps_url, latitude, longitude, logo_storage_path, kyc_status, accepted_pago_metodos, pago_metodo_instrucciones, pago_solo_divisas )
  ''';

  static String get _trSelectForListWithSubs => _trSelectMotoconecta;

  static String get _trSelectForListFlat => _trSelectMotoconecta;

  /// Solicitudes del aliado autenticado (todas).
  static Future<List<TransactionRequestModel>>
      fetchMyTransactionRequests() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .eq('aliado_id', uid)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Aliado: pedidos en curso y cerrados (pestaña Pedidos).
  static Future<List<TransactionRequestModel>>
      fetchMyPedidosActivosYCerradosForAliado() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    final response = await SupabaseAccess.client
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
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
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
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    final response = await SupabaseAccess.client
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
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    final response = await SupabaseAccess.client
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
    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select(_trSelectForListFlat)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Pedidos en curso (pestaña Pedidos activos — admin).
  static Future<List<TransactionRequestModel>>
      fetchActiveTransactionRequestsForAdmin() async {
    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
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

  /// Pedidos cerrados: entregados o rechazados (admin).
  static Future<List<TransactionRequestModel>>
      fetchClosedTransactionRequestsForAdmin() async {
    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .inFilter('status', TransactionRequestStatus.adminClosedOrders)
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Admin: en curso + cerrados (una sola consulta para la bandeja unificada).
  static Future<List<TransactionRequestModel>>
      fetchUnifiedTransactionRequestsForAdmin() async {
    final response = await SupabaseAccess.client
        .from('transaction_requests')
        .select(_trSelectForListWithSubs)
        .inFilter(
            'status', TransactionRequestStatus.adminBandejaUnifiedStatuses)
        .order('updated_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
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

    dynamic query = SupabaseAccess.client
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
        .map((row) => TransactionRequestModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Perfiles aliado e importador (mayorista) para cola de verificación admin.
  /// Incluye datos del vendedor externo si el usuario llegó referido.
  static Future<int> fetchOpenTransactionRequestCountForCurrentAliado() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return 0;

    const exposure =
        TransactionRequestStatus.motoconectaAliadoCreditExposureStatuses;

    final response = await SupabaseAccess.client
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
    final uid = SupabaseAccess.currentUserId;
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

    final profile = await ProfileService.fetchMyProfile();
    final role = profile?.role?.trim().toLowerCase();
    if (role != 'aliado') {
      throw StateError('Solo los aliados pueden crear solicitudes de pedido.');
    }
    if (profile == null) {
      throw StateError('No se encontró el perfil del aliado.');
    }
    if (profile.pedidosSuspendidosMorosidad) {
      throw PedidosSuspendidosMorosidadException(
        'B2B Conecta suspendió temporalmente la creación de nuevos pedidos en su cuenta por morosidad. '
        'Complete o regularice los pagos pendientes de pedidos ya entregados; cuando B2B Conecta confirme '
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

    final unitAliado =
        PaymentsService.calculateAliadoUnitPrice(precioUnitarioProveedor);
    final total = unitAliado * cantidad;

    final prodRes = await SupabaseAccess.client
        .from('products')
        .select('stock')
        .eq('id', productId)
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (prodRes == null) {
      throw StateError('No se encontró el producto para este importador.');
    }
    final stockRaw = Map<String, dynamic>.from(prodRes)['stock'];
    final stock =
        stockRaw is int ? stockRaw : int.tryParse(stockRaw.toString()) ?? 0;
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

    try {
      await SupabaseAccess.client.from('transaction_requests').insert({
        'aliado_id': uid,
        'importador_id': ownerId,
        'product_id': productId,
        'status': TransactionRequestStatus.pendiente,
        'cantidad': cantidad,
        'precio_total_usd': total,
      });
      await SupabaseAccess.client
          .from('products')
          .update({
            'stock': stock - cantidad,
          })
          .eq('id', productId)
          .eq('owner_id', ownerId);
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('stock insuficiente')) {
        throw StockInsufficientException(e.message);
      }
      rethrow;
    }
  }

  /// Confirma carrito multi-importador (una fila `transaction_requests` por importador + snapshot BCV).
  static Future<String> checkoutMultiImportadorCart({
    required List<Map<String, dynamic>> lines,
    bool destinoEntregaUsaPerfil = true,
    String? destinoEntregaTexto,
    String? destinoEntregaMapsUrl,
    Map<String, String> promoByImportador = const {},
    Map<String, Map<String, String?>> carriersByImportador = const {},
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final profile = await ProfileService.fetchMyProfile();
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

    final carrierPayload = <String, dynamic>{};
    for (final entry in carriersByImportador.entries) {
      final imp = entry.key.trim();
      if (imp.isEmpty) continue;
      carrierPayload[imp] = {
        'carrier_id': entry.value['carrier_id'],
        if (entry.value['driver_id'] != null &&
            entry.value['driver_id']!.trim().isNotEmpty)
          'driver_id': entry.value['driver_id'],
      };
    }

    final res = await SupabaseAccess.client.rpc(
      'aliado_checkout_multi_importador',
      params: <String, dynamic>{
        'p_lines': lines,
        'p_destino_entrega_usa_perfil': destinoEntregaUsaPerfil,
        'p_destino_entrega_texto': destinoEntregaTexto,
        'p_destino_entrega_maps_url': destinoEntregaMapsUrl,
        'p_promo_by_importador': promoByImportador,
        'p_carriers_by_importador': carrierPayload,
      },
    );
    return res?.toString() ?? '';
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
    await SupabaseAccess.client
        .from('transaction_requests')
        .update(payload)
        .eq('id', id);
  }

  static Future<void> importerSubmitMotoconectaProveedorFactura({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final row = await SupabaseAccess.client
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

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) {
      safeBase = 'factura.$ext';
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final oldPath = m['proveedor_factura_storage_path']?.toString().trim();
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderInvoicesBucket)
            .remove([oldPath]);
      } catch (_) {}
    }

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderInvoicesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    await SupabaseAccess.client.from('transaction_requests').update({
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
    final uid = SupabaseAccess.currentUserId;
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

    final rows = await SupabaseAccess.client
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
      final cg = m['checkout_group_id']?.toString().trim();
      if (cg == null || cg.isEmpty) {
        throw StateError(
          'Las líneas del carrito no comparten checkout; use adjuntar por pedido.',
        );
      }
      checkoutGroupId ??= cg;
      if (checkoutGroupId != cg) {
        throw StateError(
            'Las líneas no pertenecen al mismo carrito (checkout).');
      }
    }

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) {
      safeBase = 'factura.$ext';
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    // Ruta bajo id de línea ancla: políticas Storage exigen folder = transaction_requests.id
    final anchorId = parsed.first['id']!.toString();
    final path = '$anchorId/${stamp}_$safeBase';

    final oldPaths = <String>{};
    for (final m in parsed) {
      final op = m['proveedor_factura_storage_path']?.toString().trim();
      if (op != null && op.isNotEmpty) {
        oldPaths.add(op);
      }
    }
    for (final op in oldPaths) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderInvoicesBucket)
            .remove([op]);
      } catch (_) {}
    }

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderInvoicesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseAccess.client.from('transaction_requests').update({
      'proveedor_factura_storage_path': path,
      'proveedor_factura_file_name': fileName.trim(),
      'proveedor_factura_submitted_at': now,
      'updated_at': now,
    }).inFilter('id', ids);
  }

  /// Importador: sube o reemplaza la factura al aliado mientras el pedido está en preparación.
  static Future<void> importerSubmitOrderInvoice({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final row = await SupabaseAccess.client
        .from('transaction_requests')
        .select(
          'owner_id, status, proveedor_factura_storage_path, pago_estado_revision',
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
    final pe = m['pago_estado_revision']?.toString().trim();
    if (pe == PagoRevisionEstado.aprobado) {
      throw StateError(
        'El pago ya fue aprobado; no puede reemplazar la factura.',
      );
    }
    if (pe == PagoRevisionEstado.enRevision) {
      throw StateError(
        'Hay un comprobante en revisión. Espere antes de cambiar la factura.',
      );
    }

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) {
      safeBase = 'factura.$ext';
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/${stamp}_$safeBase';

    final oldPath = m['proveedor_factura_storage_path']?.toString().trim();
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderInvoicesBucket)
            .remove([oldPath]);
      } catch (_) {}
    }

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderInvoicesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    await SupabaseAccess.client.from('transaction_requests').update({
      'proveedor_factura_storage_path': path,
      'proveedor_factura_file_name': fileName.trim(),
      'proveedor_factura_submitted_at':
          DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', transactionRequestId);
  }

  /// Importador: `pedido_listo` → `en_transito` con ETA obligatorio (días 0–365, horas 0–23).
  static Future<void> importerMarcaPedidoEnTransito({
    required String requestId,
    required int transitEtaDays,
    required int transitEtaHours,
  }) async {
    await SupabaseAccess.client.rpc(
      'importer_marca_pedido_en_transito',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_transit_eta_days': transitEtaDays,
        'p_transit_eta_hours': transitEtaHours,
      },
    );
  }

  /// B2B Conecta: pasa el pedido a `en_transito`. [transitEtaDays]/[transitEtaHours] son opcionales
  /// (por defecto 0); el ETA en vivo se espera en el enlace de Google Maps del pedido.
  static Future<void> adminMarcaPedidoEnTransito({
    required String requestId,
    int transitEtaDays = 0,
    int transitEtaHours = 0,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_marca_pedido_en_transito',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_transit_eta_days': transitEtaDays,
        'p_transit_eta_hours': transitEtaHours,
      },
    );
  }

  /// B2B Conecta: guarda o borra el enlace de Google Maps de la ruta unificada
  /// (visible a aliado e importador en tránsito).
  static Future<void> adminSetTransactionRequestRutaMapsUrl({
    required String requestId,
    required String? urlOrNull,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final profile = await ProfileService.fetchMyProfile();
    if (profile?.role?.trim().toLowerCase() != 'administrador') {
      throw StateError('Solo B2B Conecta puede publicar el enlace de ruta.');
    }

    final row = await SupabaseAccess.client
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
        throw ArgumentError(
            'Use una URL http(s) válida o deje el campo vacío.');
      }
      stored = trimmed;
    }

    await SupabaseAccess.client.from('transaction_requests').update({
      'admin_ruta_maps_url': stored,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  static const _trMessagesSelect =
      'id, transaction_request_id, author_id, author_role, body, created_at';

  static Future<List<TransactionRequestMessageModel>>
      fetchTransactionRequestMessages(String transactionRequestId) async {
    if (transactionRequestId.isEmpty) return [];

    final response = await SupabaseAccess.client
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
    final response = await SupabaseAccess.client
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

  /// Un canal Realtime por solicitud; desuscribir cada uno con [SupabaseAccess.unsubscribeChannel].
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

  static Future<void> insertTransactionRequestMessageAsImportador({
    required String transactionRequestId,
    required String body,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final t = body.trim();
    if (t.isEmpty) return;

    await SupabaseAccess.client.from('transaction_request_messages').insert({
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
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final t = body.trim();
    if (t.isEmpty) return;

    await SupabaseAccess.client.from('transaction_request_messages').insert({
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
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');
    final t = body.trim();
    if (t.isEmpty) return;

    await SupabaseAccess.client.from('transaction_request_messages').insert({
      'transaction_request_id': transactionRequestId,
      'author_id': uid,
      'author_role': 'administrador',
      'body': t,
    });
  }

  /// Admin B2B Conecta: anula un pedido ya aprobado / en curso (no pendiente ni entregado), con motivo.
  static Future<void> adminAnulaPedidoPorMotolink({
    required String transactionRequestId,
    required String motivo,
  }) async {
    final t = motivo.trim();
    if (t.length < 3) {
      throw ArgumentError('Indique un motivo de al menos 3 caracteres.');
    }
    await SupabaseAccess.client.rpc(
      'admin_anula_pedido_por_motolink',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_motivo': t,
      },
    );
  }

  /// Aliado: cancela pedido en `pendiente` (antes de aprobación B2B Conecta), con motivo.
  static Future<void> aliadoCancelaPedidoPendiente({
    required String transactionRequestId,
    required String motivo,
  }) async {
    final t = motivo.trim();
    if (t.length < 3) {
      throw ArgumentError('Indique un motivo de al menos 3 caracteres.');
    }
    await SupabaseAccess.client.rpc(
      'aliado_cancela_pedido_pendiente',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_motivo': t,
      },
    );
  }

  /// Importador: propone menor cantidad mientras el pedido está `pendiente` (aliado debe aceptar/rechazar).
  static Future<void> importerProponeAjusteCantidad({
    required String transactionRequestId,
    required int offeredQty,
    String note = '',
  }) async {
    await SupabaseAccess.client.rpc(
      'importer_propone_ajuste_cantidad',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_offered_qty': offeredQty,
        'p_note': note.trim(),
      },
    );
  }

  /// Aliado: responde a la propuesta formal de cantidad del importador.
  static Future<void> aliadoRespondeAjusteCantidad({
    required String transactionRequestId,
    required bool aceptar,
  }) async {
    await SupabaseAccess.client.rpc(
      'aliado_responde_ajuste_cantidad',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_aceptar': aceptar,
      },
    );
  }

  /// Importador: cancela pedido en gestión (pendiente / en preparación / listo), con motivo.
  static Future<void> importerCancelaPedidoEnGestion({
    required String transactionRequestId,
    required String motivo,
  }) async {
    final t = motivo.trim();
    if (t.length < 3) {
      throw ArgumentError('Indique un motivo de al menos 3 caracteres.');
    }
    await SupabaseAccess.client.rpc(
      'importer_cancela_pedido_en_gestion',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_motivo': t,
      },
    );
  }

  /// Importador: acuerda 1–3 cuotas cuya suma = total del pedido; notifica en el chat.
  /// Cierra el pedido (aliado): `en_transito` → `entregado` (RPC en base de datos).
  static Future<void> aliadoMarcarPedidoEntregado(
      String transactionRequestId) async {
    await SupabaseAccess.client.rpc(
      'aliado_marca_pedido_entregado',
      params: {'p_request_id': transactionRequestId},
    );
  }

  /// Cierra todas las líneas `en_transito` | `enviado` del mismo importador en un carrito.
  static Future<int> aliadoMarcarPedidosEntregadosImportadorEnGrupo({
    required String checkoutGroupId,
    required String importadorId,
  }) async {
    final res = await SupabaseAccess.client.rpc(
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

  static Future<void> importerAdvanceTransactionRequest({
    required String id,
    required String newStatus,
    List<String>? batchIds,
  }) async {
    final ids = (batchIds != null && batchIds.length > 1)
        ? batchIds
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
        : <String>[id];

    final rows = await SupabaseAccess.client
        .from('transaction_requests')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .inFilter('id', ids)
        .select('id');
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
}

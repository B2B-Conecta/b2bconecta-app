import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo_instrucciones.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/logistics/carrier_flete_pago_modo.dart';
import 'package:motolink_pro_app/features/logistics/importer_carrier_driver_model.dart';
import 'package:motolink_pro_app/features/logistics/importer_carrier_model.dart';
import 'package:motolink_pro_app/features/logistics/importer_pickup_location_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';

class LogisticsService {
  LogisticsService._();

  static List<ImporterCarrierModel> _mapImporterCarriers(dynamic response) {
    final list = response as List<dynamic>? ?? [];
    return list
        .map(
          (row) => ImporterCarrierModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<List<ImporterCarrierModel>> listMyImporterCarriers() async {
    final response =
        await SupabaseAccess.client.rpc('list_my_importer_carriers');
    return _mapImporterCarriers(response);
  }

  static Future<List<ImporterCarrierModel>> listImporterCarriersForCheckout({
    required String importadorId,
    String? destEstado,
    String? destCiudad,
    double? destLatitude,
    double? destLongitude,
  }) async {
    final response = await SupabaseAccess.client.rpc(
      'list_importer_carriers_for_checkout',
      params: <String, dynamic>{
        'p_importador_id': importadorId.trim(),
        'p_dest_estado': destEstado,
        'p_dest_ciudad': destCiudad,
        'p_dest_latitude': destLatitude,
        'p_dest_longitude': destLongitude,
      },
    );
    return _mapImporterCarriers(response);
  }

  static Future<bool> importadorHasActiveCarriers(String importadorId) async {
    final res = await SupabaseAccess.client.rpc(
      'motoconecta_importador_has_active_carriers',
      params: {'p_importador_id': importadorId.trim()},
    );
    return res == true;
  }

  static Future<List<ImporterCarrierModel>> listImporterCarriersForPedido(
    String requestId,
  ) async {
    final response = await SupabaseAccess.client.rpc(
      'list_importer_carriers_for_pedido',
      params: {'p_request_id': requestId.trim()},
    );
    return _mapImporterCarriers(response);
  }

  static Future<void> aliadoSelectCarrierForPedido({
    required String requestId,
    required String carrierId,
    String? driverId,
    String? fletePagoModo,
  }) async {
    await SupabaseAccess.client.rpc(
      'aliado_select_carrier_for_pedido',
      params: <String, dynamic>{
        'p_request_id': requestId.trim(),
        'p_carrier_id': carrierId.trim(),
        'p_driver_id': driverId?.trim(),
        if (fletePagoModo != null) 'p_flete_pago_modo': fletePagoModo.trim(),
      },
    );
  }

  static Future<void> aliadoSkipCarrierForPedido({
    required String requestId,
  }) async {
    await SupabaseAccess.client.rpc(
      'aliado_skip_carrier_for_pedido',
      params: {'p_request_id': requestId.trim()},
    );
  }

  static Future<List<ImporterPickupLocationModel>>
      listMyImporterPickupLocations() async {
    final response =
        await SupabaseAccess.client.rpc('list_importer_pickup_locations');
    final list = response as List<dynamic>? ?? const [];
    return list
        .map(
          (row) => ImporterPickupLocationModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<String> upsertImporterPickupLocation({
    String? id,
    required String label,
    String? estado,
    String? ciudad,
    required String direccion,
    double? latitude,
    double? longitude,
    String? mapsUrl,
    String? contactName,
    String? contactPhone,
    bool isActive = true,
    bool isDefault = false,
    int sortOrder = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'upsert_importer_pickup_location',
      params: <String, dynamic>{
        'p_id': id,
        'p_label': label.trim(),
        'p_estado': estado?.trim(),
        'p_ciudad': ciudad?.trim(),
        'p_direccion': direccion.trim(),
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_maps_url': mapsUrl?.trim(),
        'p_contact_name': contactName?.trim(),
        'p_contact_phone': contactPhone?.trim(),
        'p_is_active': isActive,
        'p_is_default': isDefault,
        'p_sort_order': sortOrder,
      },
    );
    return res?.toString() ?? '';
  }

  static Future<void> setImporterDefaultPickupPreferences({
    required String mode,
    String? pickupLocationId,
  }) async {
    await SupabaseAccess.client.rpc(
      'set_importer_default_pickup_preferences',
      params: <String, dynamic>{
        'p_mode': mode,
        'p_pickup_location_id': pickupLocationId,
      },
    );
  }

  static Future<void> importerConfirmPickupLocation({
    required String requestId,
    required String mode,
    String? pickupLocationId,
  }) async {
    await SupabaseAccess.client.rpc(
      'importer_confirm_pickup_location',
      params: <String, dynamic>{
        'p_request_id': requestId.trim(),
        'p_mode': mode,
        'p_pickup_location_id': pickupLocationId,
      },
    );
  }

  /// Aliado: datos de pago del transportista asignado (cuentas por método).
  static Future<
      ({
        String? companyName,
        List<String> acceptedPagoMetodos,
        Map<String, String> pagoInstrucciones,
      })> fetchAliadoPedidoCarrierPagoInfo(String requestId) async {
    final res = await SupabaseAccess.client.rpc(
      'get_aliado_pedido_carrier_pago_info',
      params: {'p_request_id': requestId.trim()},
    );
    if (res is! Map) {
      throw StateError(
          'Respuesta inválida al consultar datos del transportista.');
    }
    final m = Map<String, dynamic>.from(res);
    return (
      companyName: m['company_name']?.toString().trim(),
      acceptedPagoMetodos:
          ProfileModel.parseStringList(m['accepted_pago_metodos']) ?? const [],
      pagoInstrucciones: PagoMetodoInstrucciones.parseMap(
        m['pago_metodo_instrucciones'],
      ),
    );
  }

  static Future<void> importerSubmitFleteFactura({
    required String transactionRequestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final row = await SupabaseAccess.client
        .from('transaction_requests')
        .select(
          'importador_id, status, carrier_flete_pago_modo_snapshot, flete_factura_storage_path',
        )
        .eq('id', transactionRequestId)
        .maybeSingle();

    if (row == null) throw StateError('Pedido no encontrado.');
    final m = Map<String, dynamic>.from(row);
    if (m['importador_id']?.toString() != uid) {
      throw StateError(
          'No autorizado a adjuntar factura de flete en este pedido.');
    }
    final st = m['status']?.toString();
    if (st != TransactionRequestStatus.pendiente &&
        st != TransactionRequestStatus.enPreparacion &&
        st != TransactionRequestStatus.pedidoListo) {
      throw StateError(
        'Solo puede adjuntar la factura de flete antes de marcar en tránsito.',
      );
    }
    if (m['carrier_flete_pago_modo_snapshot']?.toString() !=
        CarrierFletePagoModo.pagoSeparado) {
      throw StateError(
        'La factura de flete solo aplica cuando el pago del transporte es separado.',
      );
    }

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'flete-factura.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/flete_${stamp}_$safeBase';

    final oldPath = m['flete_factura_storage_path']?.toString().trim();
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
      'flete_factura_storage_path': path,
      'flete_factura_file_name': fileName.trim(),
      'flete_factura_submitted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', transactionRequestId);
  }

  /// Aliado: comprobante de pago del flete (transporte con pago separado).
  static Future<void> aliadoSubmitFleteComprobantePago({
    required String transactionRequestId,
    required String metodo,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use imagen o PDF.');
    }

    var safeBase = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').trim();
    if (safeBase.isEmpty) safeBase = 'flete-comprobante.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$transactionRequestId/flete_pago_${stamp}_$safeBase';

    final row = await SupabaseAccess.client
        .from('transaction_requests')
        .select(
          'flete_comprobante_pago_storage_path, flete_pago_estado_revision',
        )
        .eq('id', transactionRequestId)
        .eq('aliado_id', uid)
        .maybeSingle();
    if (row != null) {
      final m = Map<String, dynamic>.from(row);
      final pe = m['flete_pago_estado_revision']?.toString().trim();
      if (pe == PagoRevisionEstado.aprobado) {
        throw StateError(
          'El pago del flete ya fue confirmado; no puede modificar el comprobante.',
        );
      }
      final oldPath =
          m['flete_comprobante_pago_storage_path']?.toString().trim();
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          await SupabaseAccess.client.storage
              .from(SupabaseAccess.orderPaymentProofsBucket)
              .remove([oldPath]);
        } catch (_) {}
      }
    }

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.orderPaymentProofsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await SupabaseAccess.client.rpc(
        'aliado_registra_comprobante_flete_pago',
        params: <String, dynamic>{
          'p_request_id': transactionRequestId,
          'p_metodo': metodo,
          'p_storage_path': path,
          'p_file_name': fileName.trim(),
        },
      );
    } catch (e) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.orderPaymentProofsBucket)
            .remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Importador: aprueba o rechaza el comprobante del flete.
  static Future<void> importadorSetFletePagoRevisionEstado({
    required String transactionRequestId,
    required String nuevoEstado,
    String? rechazoNota,
  }) async {
    if (SupabaseAccess.currentUserId == null)
      throw StateError('No hay sesión activa.');
    await SupabaseAccess.client.rpc(
      'importador_set_flete_pago_revision_estado',
      params: <String, dynamic>{
        'p_request_id': transactionRequestId,
        'p_nuevo_estado': nuevoEstado,
        'p_rechazo_nota': rechazoNota,
      },
    );
  }

  static Future<String> createImporterCarrier({
    required String companyName,
    required String contactPhone,
    String? contactName,
    String? contactEmail,
    String? contactWhatsapp,
    List<String> coverageEstados = const [],
    List<String> coverageCiudades = const [],
    String? coverageNotes,
    String? baseEstado,
    String? baseCiudad,
    double? baseLatitude,
    double? baseLongitude,
    String? baseMapsUrl,
    List<String> acceptedPagoMetodos = const [],
    Map<String, String> pagoMetodoInstrucciones = const {},
    String fletePagoModo = CarrierFletePagoModo.incluidoFactura,
    double etaBaseHours = 24,
    double etaHoursPerKm = 0.15,
    double? maxCoverageKm,
    double? flatFeeUsd,
    double? pricePerKmUsd,
    String? notes,
    int sortOrder = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'create_importer_carrier',
      params: <String, dynamic>{
        'p_company_name': companyName,
        'p_contact_phone': contactPhone,
        'p_contact_name': contactName,
        'p_contact_email': contactEmail,
        'p_contact_whatsapp': contactWhatsapp,
        'p_coverage_estados': coverageEstados,
        'p_coverage_ciudades': coverageCiudades,
        'p_coverage_notes': coverageNotes,
        'p_base_estado': baseEstado,
        'p_base_ciudad': baseCiudad,
        'p_base_latitude': baseLatitude,
        'p_base_longitude': baseLongitude,
        'p_base_maps_url': baseMapsUrl,
        'p_accepted_pago_metodos': acceptedPagoMetodos,
        'p_pago_metodo_instrucciones':
            PagoMetodoInstrucciones.toJson(pagoMetodoInstrucciones),
        'p_flete_pago_modo': fletePagoModo,
        'p_eta_base_hours': etaBaseHours,
        'p_eta_hours_per_km': etaHoursPerKm,
        'p_max_coverage_km': maxCoverageKm,
        'p_flat_fee_usd': flatFeeUsd,
        'p_price_per_km_usd': pricePerKmUsd,
        'p_notes': notes,
        'p_sort_order': sortOrder,
      },
    );
    return res?.toString() ?? '';
  }

  static Future<void> updateImporterCarrier({
    required String carrierId,
    required String companyName,
    required String contactPhone,
    String? contactName,
    String? contactEmail,
    String? contactWhatsapp,
    List<String> coverageEstados = const [],
    List<String> coverageCiudades = const [],
    String? coverageNotes,
    String? baseEstado,
    String? baseCiudad,
    double? baseLatitude,
    double? baseLongitude,
    String? baseMapsUrl,
    List<String> acceptedPagoMetodos = const [],
    Map<String, String> pagoMetodoInstrucciones = const {},
    String fletePagoModo = CarrierFletePagoModo.incluidoFactura,
    double etaBaseHours = 24,
    double etaHoursPerKm = 0.15,
    double? maxCoverageKm,
    double? flatFeeUsd,
    double? pricePerKmUsd,
    String? notes,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    await SupabaseAccess.client.rpc(
      'update_importer_carrier',
      params: <String, dynamic>{
        'p_carrier_id': carrierId,
        'p_company_name': companyName,
        'p_contact_phone': contactPhone,
        'p_contact_name': contactName,
        'p_contact_email': contactEmail,
        'p_contact_whatsapp': contactWhatsapp,
        'p_coverage_estados': coverageEstados,
        'p_coverage_ciudades': coverageCiudades,
        'p_coverage_notes': coverageNotes,
        'p_base_estado': baseEstado,
        'p_base_ciudad': baseCiudad,
        'p_base_latitude': baseLatitude,
        'p_base_longitude': baseLongitude,
        'p_base_maps_url': baseMapsUrl,
        'p_accepted_pago_metodos': acceptedPagoMetodos,
        'p_pago_metodo_instrucciones':
            PagoMetodoInstrucciones.toJson(pagoMetodoInstrucciones),
        'p_flete_pago_modo': fletePagoModo,
        'p_eta_base_hours': etaBaseHours,
        'p_eta_hours_per_km': etaHoursPerKm,
        'p_max_coverage_km': maxCoverageKm,
        'p_flat_fee_usd': flatFeeUsd,
        'p_price_per_km_usd': pricePerKmUsd,
        'p_notes': notes,
        'p_is_active': isActive,
        'p_sort_order': sortOrder,
      },
    );
  }

  static Future<void> deleteImporterCarrier(String carrierId) async {
    await SupabaseAccess.client.rpc(
      'delete_importer_carrier',
      params: {'p_carrier_id': carrierId.trim()},
    );
  }

  static Future<List<ImporterCarrierDriverModel>> listImporterCarrierDrivers(
    String carrierId,
  ) async {
    final response = await SupabaseAccess.client.rpc(
      'list_importer_carrier_drivers',
      params: {'p_carrier_id': carrierId.trim()},
    );
    final list = response as List<dynamic>? ?? [];
    return list
        .map(
          (row) => ImporterCarrierDriverModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  static Future<String> createImporterCarrierDriver({
    required String carrierId,
    required String driverName,
    String? contactPhone,
    String? licenseId,
    String? notes,
    int sortOrder = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'create_importer_carrier_driver',
      params: <String, dynamic>{
        'p_carrier_id': carrierId,
        'p_driver_name': driverName,
        'p_contact_phone': contactPhone,
        'p_license_id': licenseId,
        'p_notes': notes,
        'p_sort_order': sortOrder,
      },
    );
    return res?.toString() ?? '';
  }

  static Future<void> updateImporterCarrierDriver({
    required String driverId,
    required String driverName,
    String? contactPhone,
    String? licenseId,
    String? notes,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    await SupabaseAccess.client.rpc(
      'update_importer_carrier_driver',
      params: <String, dynamic>{
        'p_driver_id': driverId,
        'p_driver_name': driverName,
        'p_contact_phone': contactPhone,
        'p_license_id': licenseId,
        'p_notes': notes,
        'p_is_active': isActive,
        'p_sort_order': sortOrder,
      },
    );
  }

  static Future<void> deleteImporterCarrierDriver(String driverId) async {
    await SupabaseAccess.client.rpc(
      'delete_importer_carrier_driver',
      params: {'p_driver_id': driverId.trim()},
    );
  }
}

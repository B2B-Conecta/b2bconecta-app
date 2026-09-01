import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_model.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/commissions/bcv_reference_rate_service.dart';
import 'package:motolink_pro_app/features/commissions/motolink_commission_delivery_note_pdf_service.dart';
import 'package:motolink_pro_app/features/commissions/motolink_commission_invoice_pdf_service.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_document_type.dart';
import 'package:motolink_pro_app/features/commissions/importer_commission_volume_context.dart';
import 'package:motolink_pro_app/features/commissions/commission_volume_tiers.dart';

class CommissionsService {
  CommissionsService._();

  static Future<double?> fetchGlobalTasaBcv() async {
    final rec = await fetchGlobalTasaBcvRecord();
    return rec?.tasa;
  }

  static Future<({double tasa, DateTime updatedAt, String? effectiveDate})?>
      fetchGlobalTasaBcvRecord() async {
    try {
      final row = await SupabaseAccess.client
          .from('app_global_config')
          .select('value_numeric, value_text, updated_at')
          .eq('key', 'tasa_bcv')
          .maybeSingle();
      if (row == null) return null;
      final m = Map<String, dynamic>.from(row);
      final v = m['value_numeric'];
      double? tasa;
      if (v is num) {
        tasa = v.toDouble();
      } else {
        tasa = double.tryParse(v?.toString() ?? '');
      }
      if (tasa == null || tasa <= 0) return null;
      final rawAt = m['updated_at']?.toString();
      final updatedAt = rawAt != null ? DateTime.tryParse(rawAt) : null;
      final effective = m['value_text']?.toString().trim();
      return (
        tasa: tasa,
        updatedAt: updatedAt ?? DateTime.now(),
        effectiveDate:
            (effective != null && effective.isNotEmpty) ? effective : null,
      );
    } catch (_) {
      return null;
    }
  }

  static bool globalTasaBcvNeedsDailySync(DateTime? updatedAt) {
    if (updatedAt == null) return true;
    final now = BcvReferenceRateService.caracasWallClock();
    final then = BcvReferenceRateService.caracasWallClock(updatedAt.toUtc());
    return then.year != now.year ||
        then.month != now.month ||
        then.day != now.day;
  }

  static Future<void> adminSetTasaBcv(double tasa) async {
    await SupabaseAccess.client
        .rpc('admin_set_tasa_bcv', params: {'p_tasa': tasa});
  }

  /// Si aún no se notificó hoy (Caracas), avisa a todos los usuarios con la tasa guardada.
  static Future<int> runDailyTasaBcvNotifyIfDue() async {
    try {
      final res = await SupabaseAccess.client.rpc('run_daily_tasa_bcv_notify');
      if (res is num) return res.toInt();
      return int.tryParse(res?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Sincroniza la tasa BCV global desde el boletín publicado más reciente.
  static Future<double?> syncGlobalTasaBcvFromReference() async {
    final quote = await BcvReferenceRateService.fetchPublicBcvUsdRate();
    if (quote == null) return null;
    await adminSetTasaBcv(quote.vesPerUsd);
    final fecha = quote.effectiveDate?.trim();
    if (fecha != null && fecha.isNotEmpty) {
      try {
        await SupabaseAccess.client
            .from('app_global_config')
            .update({'value_text': fecha})
            .eq('key', 'tasa_bcv');
      } catch (_) {}
    }
    return quote.vesPerUsd;
  }

  /// Tasa BCV para facturas y conversiones: DB → referencia automática → 1.0.
  static Future<double> resolveTasaBcvEmision() async {
    final saved = await fetchGlobalTasaBcv();
    if (saved != null && saved > 1.01) return saved;
    final synced = await syncGlobalTasaBcvFromReference();
    if (synced != null && synced > 0) return synced;
    return saved ?? 1.0;
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
    document_type,
    issued_by,
    importador:profiles!commission_settlements_importador_id_fkey (
      business_name,
      rif,
      direccion,
      estado,
      ciudad,
      phone
    )
  ''';

  /// Tasa global B2B Conecta (fracción; 0.05 = 5 %).
  static Future<double> fetchDefaultCommissionRate() async {
    final row = await SupabaseAccess.client
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
    await SupabaseAccess.client.rpc(
      'admin_set_default_commission_rate',
      params: <String, dynamic>{'p_rate': rate},
    );
  }

  static Future<void> adminSetImportadorCommissionRate({
    required String importadorId,
    double? rate,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_set_importador_commission_rate',
      params: <String, dynamic>{
        'p_importador_id': importadorId,
        'p_rate': rate,
      },
    );
  }

  static Future<List<CommissionVolumeTier>> fetchCommissionVolumeTiers() async {
    final raw =
        await SupabaseAccess.client.rpc('admin_get_commission_volume_tiers');
    return parseCommissionVolumeTiers(raw);
  }

  /// E3: volumen mensual + tramo/tasa (propio importador o admin con id).
  static Future<ImporterCommissionVolumeContext?>
      fetchImporterCommissionVolumeContext({
    String? importadorId,
  }) async {
    final params = <String, dynamic>{};
    final id = importadorId?.trim();
    if (id != null && id.isNotEmpty) {
      params['p_importador_id'] = id;
    }
    final raw = await SupabaseAccess.client.rpc(
      'motoconecta_importer_commission_volume_context',
      params: params.isEmpty ? null : params,
    );
    return ImporterCommissionVolumeContext.fromRpc(raw);
  }

  /// Varias consultas en paralelo (admin: cortes por importador).
  static Future<Map<String, ImporterCommissionVolumeContext>>
      fetchImporterCommissionVolumeContexts(
    Iterable<String> importadorIds,
  ) async {
    final unique =
        importadorIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (unique.isEmpty) return {};
    final entries = await Future.wait(
      unique.map((id) async {
        final ctx =
            await fetchImporterCommissionVolumeContext(importadorId: id);
        return MapEntry(id, ctx);
      }),
    );
    return {
      for (final e in entries)
        if (e.value != null) e.key: e.value!,
    };
  }

  static Future<void> adminSetCommissionVolumeTiers(
    List<CommissionVolumeTier> tiers,
  ) async {
    final sorted = [...tiers]
      ..sort((a, b) => a.minMonthlySalesUsd.compareTo(b.minMonthlySalesUsd));
    await SupabaseAccess.client.rpc(
      'admin_set_commission_volume_tiers',
      params: <String, dynamic>{
        'p_tiers': sorted.map((t) => t.toJson()).toList(),
      },
    );
  }

  /// Cortes de comisión (admin: todos; importador: solo los propios vía RLS).
  static Future<List<CommissionSettlementModel>> fetchCommissionSettlements({
    int limit = 80,
  }) async {
    final response = await SupabaseAccess.client
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
    final response = await SupabaseAccess.client
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
    final raw = await SupabaseAccess.client.rpc(
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
    final raw = await SupabaseAccess.client.rpc(
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
    return SupabaseAccess.client.storage
        .from(SupabaseAccess.commissionSettlementInvoicesBucket)
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
    final row =
        await SupabaseAccess.client.from('commission_settlements').select('''
          importador:profiles!commission_settlements_importador_id_fkey (
            direccion, estado, ciudad, phone
          )
        ''').eq('id', settlement.id).maybeSingle();
    if (row != null) {
      final imp = row['importador'];
      if (imp is Map) impMap = Map<String, dynamic>.from(imp);
    }

    final tasa = await resolveTasaBcvEmision();
    final ref = settlement.invoiceReference?.trim();
    final safeRef = (ref != null && ref.isNotEmpty)
        ? ref.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        : settlement.id.substring(0, 8);
    final isNota = settlement.isDeliveryNote;
    final fileName = isNota
        ? 'B2B_Conecta_nota_entrega_$safeRef.pdf'
        : 'B2B_Conecta_comision_$safeRef.pdf';
    final path = '${settlement.id}/$fileName';

    final oldPath = settlement.invoicePdfStoragePath?.trim();
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.commissionSettlementInvoicesBucket)
            .remove([oldPath]);
      } catch (_) {}
    }

    final Uint8List bytes;
    if (isNota) {
      bytes = await MotolinkCommissionDeliveryNotePdfService.build(
        settlement: settlement,
        lines: lines,
        tasaBcvEmision: tasa,
        importadorDireccion: impMap?['direccion']?.toString(),
        importadorEstado: impMap?['estado']?.toString(),
        importadorCiudad: impMap?['ciudad']?.toString(),
        importadorPhone: impMap?['phone']?.toString(),
      );
    } else {
      bytes = await MotolinkCommissionInvoicePdfService.build(
        settlement: settlement,
        lines: lines,
        tasaBcvEmision: tasa,
        importadorDireccion: impMap?['direccion']?.toString(),
        importadorEstado: impMap?['estado']?.toString(),
        importadorCiudad: impMap?['ciudad']?.toString(),
        importadorPhone: impMap?['phone']?.toString(),
      );
    }

    await SupabaseAccess.client.storage
        .from(SupabaseAccess.commissionSettlementInvoicesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    await SupabaseAccess.client.rpc(
      'admin_attach_commission_invoice_pdf',
      params: <String, dynamic>{
        'p_settlement_id': settlement.id,
        'p_storage_path': path,
        'p_file_name': fileName,
      },
    );
  }

  /// Vista previa del siguiente Nº (ML-COM- o ML-NOT- según tipo).
  static Future<String> peekCommissionSettlementReference(
    CommissionSettlementDocumentType documentType,
  ) async {
    final raw = await SupabaseAccess.client.rpc(
      'motoconecta_peek_commission_settlement_reference',
      params: <String, dynamic>{'p_document_type': documentType.rpcValue},
    );
    return raw?.toString().trim() ?? '';
  }

  /// Emite el corte. Referencia automática según [documentType].
  static Future<String> adminIssueCommissionSettlement({
    required String settlementId,
    required CommissionSettlementDocumentType documentType,
    String? invoiceReference,
  }) async {
    final params = <String, dynamic>{
      'p_settlement_id': settlementId,
      'p_document_type': documentType.rpcValue,
    };
    final manual = invoiceReference?.trim();
    if (manual != null && manual.isNotEmpty) {
      params['p_invoice_reference'] = manual;
    }
    final raw = await SupabaseAccess.client.rpc(
      'admin_issue_commission_settlement',
      params: params,
    );
    return raw?.toString().trim() ?? '';
  }

  /// Importador: sube comprobante y envía a revisión B2B Conecta.
  static Future<void> importadorSubmitCommissionSettlementPago({
    required String settlementId,
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
    if (safeBase.isEmpty) safeBase = 'comprobante.$ext';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = 'commission-settlements/$settlementId/${stamp}_$safeBase';

    final row = await SupabaseAccess.client
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
        'importador_registra_pago_comision_corte',
        params: <String, dynamic>{
          'p_settlement_id': settlementId,
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

  static Future<void> adminApproveCommissionSettlementPago(
    String settlementId,
  ) async {
    await SupabaseAccess.client.rpc(
      'admin_approve_commission_settlement_pago',
      params: <String, dynamic>{'p_settlement_id': settlementId},
    );
  }

  static Future<void> adminRejectCommissionSettlementPago({
    required String settlementId,
    String? nota,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_reject_commission_settlement_pago',
      params: <String, dynamic>{
        'p_settlement_id': settlementId,
        'p_nota': nota?.trim(),
      },
    );
  }

  static Future<void> adminMarkCommissionSettlementPaid(
      String settlementId) async {
    await SupabaseAccess.client.rpc(
      'admin_mark_commission_settlement_paid',
      params: <String, dynamic>{'p_settlement_id': settlementId},
    );
  }

  static Future<void> adminCancelCommissionSettlement(
      String settlementId) async {
    await SupabaseAccess.client.rpc(
      'admin_cancel_commission_settlement',
      params: <String, dynamic>{'p_settlement_id': settlementId},
    );
  }
}

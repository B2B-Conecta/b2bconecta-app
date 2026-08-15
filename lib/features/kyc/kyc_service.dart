import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/kyc_approved_aliado_model.dart';
import 'package:motolink_pro_app/features/kyc/admin_aliado_morosidad_flag.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

class KycService {
  KycService._();

  static Future<List<ProfileModel>> fetchB2BProfilesForAdminKycReview() async {
    final response = await SupabaseAccess.client
        .from('profiles')
        .select(
          '*, external_referrers:referred_by_external_id('
          'full_name, code, phone, email'
          ')',
        )
        .inFilter('role', ['aliado', 'importador']).order('business_name',
            ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) =>
            ProfileModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Broker: actualiza estado KYC global del perfil aliado.
  static Future<void> adminSetProfileKycStatus({
    required String profileId,
    required String status,
    String? note,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_set_profile_kyc_status',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_status': status,
        'p_note': note?.trim().isNotEmpty == true ? note!.trim() : null,
      },
    );
  }

  /// Admin: aprueba o rechaza acceso de mayorista (`aprobado` | `rechazado`).
  static Future<void> adminSetImportadorAccountAccess({
    required String profileId,
    required String status,
    String? note,
  }) async {
    await SupabaseAccess.client.rpc(
      'admin_set_importador_account_access',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_status': status,
        'p_note': note?.trim().isNotEmpty == true ? note!.trim() : null,
      },
    );
  }

  /// Admin: aliados con pedido moroso y estado de suspensión por morosidad.
  static Future<Map<String, AdminAliadoMorosidadFlag>>
      adminAliadosPedidosMorososFlags() async {
    final res =
        await SupabaseAccess.client.rpc('admin_aliados_pedidos_morosos_flags');
    final list = res as List<dynamic>;
    final map = <String, AdminAliadoMorosidadFlag>{};
    for (final row in list) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['aliado_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final mor = m['tiene_morosos'];
      final susp = m['pedidos_suspendidos_morosidad'];
      map[id] = AdminAliadoMorosidadFlag(
        tieneMorosos:
            mor is bool ? mor : mor?.toString().toLowerCase() == 'true',
        pedidosSuspendidosMorosidad:
            susp is bool ? susp : susp?.toString().toLowerCase() == 'true',
      );
    }
    return map;
  }

  /// Admin: suspende o reactiva la creación de nuevos pedidos por morosidad.
  static Future<void> adminSetAliadoPedidosSuspendidosMorosidad({
    required String aliadoId,
    required bool suspend,
  }) async {
    await SupabaseAccess.client.rpc(
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
    await SupabaseAccess.client.rpc(
      'admin_set_profile_document_review_status',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_doc_type': docType,
        'p_status': status,
        'p_note': note,
      },
    );
  }

  /// Aliado: envía expediente KYC a revisión B2B Conecta.
  static Future<void> profileSubmitKycForReview() async {
    await SupabaseAccess.client.rpc('profile_submit_kyc_for_review');
  }

  /// Mayorista (importador): envía solicitud de ingreso a revisión (sin KYC docs).
  static Future<void> profileSubmitImportadorForReview() async {
    await SupabaseAccess.client.rpc('profile_submit_importador_for_review');
  }

  static const _profileDocumentsSelect = 'id, profile_id, doc_type, '
      'storage_path, file_name, created_at, is_current, review_status, review_note, '
      'reviewed_at, reviewed_by, '
      'reviewer:profiles!reviewed_by(business_name)';

  /// Documentos subidos por el aliado autenticado.
  static Future<List<ProfileDocumentModel>> fetchMyProfileDocuments() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];

    final response = await SupabaseAccess.client
        .from('profile_documents')
        .select(_profileDocumentsSelect)
        .eq('profile_id', uid)
        .eq('is_current', true)
        .order('doc_type', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((row) => ProfileDocumentModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Admin: documentos de un perfil B2B (vigente + histórico).
  static Future<List<ProfileDocumentModel>> fetchProfileDocumentsForProfile(
    String profileId,
  ) async {
    if (profileId.isEmpty) return [];

    final response = await SupabaseAccess.client
        .from('profile_documents')
        .select(_profileDocumentsSelect)
        .eq('profile_id', profileId)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((row) => ProfileDocumentModel.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// URL firmada (1 h) para abrir un archivo del bucket privado.
  static Future<String> createSignedUrlForProfileDocument(
    String storagePath,
  ) async {
    return SupabaseAccess.client.storage
        .from(SupabaseAccess.profileDocumentsBucket)
        .createSignedUrl(storagePath, 3600);
  }

  /// Sube una **nueva versión** de documento KYC (PDF / imagen).
  /// Las versiones anteriores permanecen en Storage y en BD; el trigger marca `is_current`.
  static Future<void> uploadMyProfileDocument({
    required String docType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw StateError('No hay sesión activa.');

    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }

    final path =
        '$uid/${docType}_${DateTime.now().microsecondsSinceEpoch}.$ext';

    final contentType = SupabaseAccess.mimeForProfileDocExtension(ext);
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.profileDocumentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    try {
      await SupabaseAccess.client.from('profile_documents').insert({
        'profile_id': uid,
        'doc_type': docType,
        'storage_path': path,
        'file_name': fileName,
        'review_status': DocumentReviewStatus.pendiente,
        'is_current': true,
      });
    } catch (e) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.profileDocumentsBucket)
            .remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<List<KycApprovedAliadoModel>>
      listKycApprovedAliadosForImportador() async {
    final res = await SupabaseAccess.client
        .rpc('list_kyc_approved_aliados_for_importador');
    final list = SupabaseAccess.decodeRpcJsonArray(res);
    return list
        .map((e) => KycApprovedAliadoModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .where((a) => a.id.isNotEmpty)
        .toList();
  }

  /// Documentos KYC aprobados de una contraparte con la que el usuario comparte pedido.
  static Future<List<ProfileDocumentModel>> fetchCounterpartyProfileDocuments(
    String counterpartyProfileId,
  ) async {
    final pid = counterpartyProfileId.trim();
    if (pid.isEmpty) return [];

    final response = await SupabaseAccess.client
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
}


import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/admin/admin_user_activity_row_model.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

class AdminService {
  AdminService._();

  static Future<void> logUserLoginEvent({String source = 'app'}) async {
    if (SupabaseAccess.client.auth.currentSession == null) return;
    try {
      await SupabaseAccess.client.rpc(
        'log_user_login_event',
        params: <String, dynamic>{'p_source': source},
      );
    } catch (_) {
      // No bloquear la app si falla el tracking.
    }
  }

  /// Admin: monitoreo de ingresos y pedidos B2B (RPC `list_admin_user_activity_monitoring`).
  static Future<List<AdminUserActivityRowModel>>
      listAdminUserActivityMonitoring({
    String? role,
    String period = 'week',
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_admin_user_activity_monitoring',
      params: <String, dynamic>{
        'p_role': role?.trim().isEmpty == true ? null : role?.trim(),
        'p_period': period,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => AdminUserActivityRowModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Owner: listado de cuentas (RPC `owner_list_profiles`).
  static Future<List<ProfileModel>> ownerListProfiles() async {
    final res = await SupabaseAccess.client.rpc('owner_list_profiles');
    if (res is! List) return const [];
    return res
        .map(
          (e) => ProfileModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Owner: ficha completa (perfiles + correo de Auth).
  static Future<List<ProfileModel>> ownerListProfilesWithDossier() async {
    final listed = await ownerListProfiles();
    final res = await SupabaseAccess.client.from('profiles').select();
    final byId = <String, ProfileModel>{};
    for (final e in res) {
      final p = ProfileModel.fromJson(Map<String, dynamic>.from(e as Map));
      if (p.id.isNotEmpty) byId[p.id] = p;
    }
    return listed
        .map((row) => (byId[row.id] ?? row).withAuthEmail(row.email))
        .toList();
  }

  /// Owner: mapa perfil → correo de Auth.
  static Future<Map<String, String>> ownerAuthEmailsByProfileId() async {
    final rows = await ownerListProfiles();
    return {
      for (final row in rows)
        if (row.email != null && row.email!.trim().isNotEmpty)
          row.id: row.email!.trim(),
    };
  }

  /// Owner: catálogo de un mayorista, incluyendo pausados.
  static Future<List<PartModel>> ownerListImporterCatalog({
    required String importerId,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'owner_list_importer_catalog',
      params: <String, dynamic>{'p_importador_id': importerId},
    );
    if (res is! List) return const [];
    return res
        .map((e) => PartModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<int> ownerSetImporterProductsActive({
    required List<String> productIds,
    required bool isActive,
  }) async {
    final ids = productIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return 0;
    final res = await SupabaseAccess.client.rpc(
      'owner_set_importer_products_active',
      params: <String, dynamic>{
        'p_product_ids': ids,
        'p_is_active': isActive,
      },
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return int.tryParse(res?.toString() ?? '') ?? 0;
  }

  static Future<int> ownerDeleteImporterProducts({
    required List<String> productIds,
  }) async {
    final ids = productIds.where((id) => id.trim().isNotEmpty).toList();
    if (ids.isEmpty) return 0;
    final res = await SupabaseAccess.client.rpc(
      'owner_delete_importer_products',
      params: <String, dynamic>{'p_product_ids': ids},
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return int.tryParse(res?.toString() ?? '') ?? 0;
  }

  static Future<void> ownerSetProfileRole({
    required String profileId,
    required String role,
  }) async {
    await SupabaseAccess.client.rpc(
      'owner_set_profile_role',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_role': role,
      },
    );
  }

  static Future<void> ownerSetAccountAccess({
    required String profileId,
    required String status,
    String? note,
  }) async {
    await SupabaseAccess.client.rpc(
      'owner_set_account_access',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_status': status,
        'p_note': note?.trim().isNotEmpty == true ? note!.trim() : null,
      },
    );
  }

  static Future<void> ownerDeactivateProfile({
    required String profileId,
    required String note,
  }) async {
    await SupabaseAccess.client.rpc(
      'owner_deactivate_profile',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_note': note.trim(),
      },
    );
  }

  static Future<void> ownerHardDeleteProfile({
    required String profileId,
    required String confirm,
  }) async {
    await SupabaseAccess.client.rpc(
      'owner_hard_delete_profile',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_confirm': confirm.trim(),
      },
    );
  }

  static Future<String> ownerCreateAccount({
    required String email,
    required String password,
    required String role,
    required String businessName,
    String? rif,
    String? phone,
    String? estado,
    String? ciudad,
    String? direccion,
    String? fiscalMapsUrl,
    String? legalContactName,
    String? legalContactEmail,
    String? legalContactPhone,
    bool activate = true,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'owner_create_account',
      params: <String, dynamic>{
        'p_email': email.trim(),
        'p_password': password,
        'p_role': role.trim(),
        'p_business_name': businessName.trim(),
        'p_rif': _emptyToNull(rif),
        'p_phone': _emptyToNull(phone),
        'p_estado': _emptyToNull(estado),
        'p_ciudad': _emptyToNull(ciudad),
        'p_direccion': _emptyToNull(direccion),
        'p_fiscal_maps_url': _emptyToNull(fiscalMapsUrl),
        'p_legal_contact_name': _emptyToNull(legalContactName),
        'p_legal_contact_email': _emptyToNull(legalContactEmail),
        'p_legal_contact_phone': _emptyToNull(legalContactPhone),
        'p_activate': activate,
      },
    );
    final id = res?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StateError('No se recibió el id de la cuenta.');
    }
    return id;
  }

  static Future<void> ownerUpdateAccountDossier({
    required String profileId,
    required String businessName,
    String? rif,
    String? phone,
    String? estado,
    String? ciudad,
    String? direccion,
    String? fiscalMapsUrl,
    String? legalContactName,
    String? legalContactEmail,
    String? legalContactPhone,
  }) async {
    await SupabaseAccess.client.rpc(
      'owner_update_account_dossier',
      params: <String, dynamic>{
        'p_profile_id': profileId,
        'p_business_name': businessName.trim(),
        'p_rif': _emptyToNull(rif),
        'p_phone': _emptyToNull(phone),
        'p_estado': _emptyToNull(estado),
        'p_ciudad': _emptyToNull(ciudad),
        'p_direccion': _emptyToNull(direccion),
        'p_fiscal_maps_url': _emptyToNull(fiscalMapsUrl),
        'p_legal_contact_name': _emptyToNull(legalContactName),
        'p_legal_contact_email': _emptyToNull(legalContactEmail),
        'p_legal_contact_phone': _emptyToNull(legalContactPhone),
      },
    );
  }

  static Future<void> ownerUploadProfileDocument({
    required String profileId,
    required String docType,
    required Uint8List bytes,
    required String fileName,
    bool markApproved = true,
  }) async {
    final ext = SupabaseAccess.profileDocExtension(fileName);
    if (!SupabaseAccess.isAllowedProfileDocExtension(ext)) {
      throw ArgumentError('Formato no permitido. Use PDF, JPG o PNG.');
    }
    final path =
        '$profileId/${docType}_${DateTime.now().microsecondsSinceEpoch}.$ext';
    await SupabaseAccess.client.storage
        .from(SupabaseAccess.profileDocumentsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: SupabaseAccess.mimeForProfileDocExtension(ext),
            upsert: true,
          ),
        );
    try {
      await SupabaseAccess.client.rpc(
        'owner_insert_profile_document',
        params: <String, dynamic>{
          'p_profile_id': profileId,
          'p_doc_type': docType,
          'p_storage_path': path,
          'p_file_name': fileName,
          'p_mark_approved': markApproved,
        },
      );
    } catch (e) {
      try {
        await SupabaseAccess.client.storage
            .from(SupabaseAccess.profileDocumentsBucket)
            .remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  static String? _emptyToNull(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }
}



import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/referrals/admin_referral_row_model.dart';
import 'package:motolink_pro_app/features/referrals/external_referrer_model.dart';

class ReferralsService {
  ReferralsService._();

  static Future<void> applyReferralCode(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) {
      throw ArgumentError('Indique un código de referido.');
    }
    await SupabaseAccess.client.rpc(
      'profile_apply_referral_code',
      params: <String, dynamic>{'p_code': c},
    );
  }

  /// Admin: listado de vendedores externos + conteo de referidos.
  static Future<List<ExternalReferrerModel>> listAdminExternalReferrers({
    int limit = 100,
    int offset = 0,
    bool activeOnly = false,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_admin_external_referrers',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_offset': offset,
        'p_active_only': activeOnly,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => ExternalReferrerModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  static Future<ExternalReferrerModel> adminCreateExternalReferrer({
    required String fullName,
    required String phone,
    required String email,
    String? notes,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'admin_create_external_referrer',
      params: <String, dynamic>{
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_email': email.trim(),
        'p_notes': notes?.trim(),
      },
    );
    return ExternalReferrerModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  static Future<ExternalReferrerModel> adminUpdateExternalReferrer({
    required String id,
    String? fullName,
    String? phone,
    String? email,
    bool? active,
    String? notes,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'admin_update_external_referrer',
      params: <String, dynamic>{
        'p_id': id.trim(),
        'p_full_name': fullName?.trim(),
        'p_phone': phone?.trim(),
        'p_email': email?.trim(),
        'p_active': active,
        'p_notes': notes,
      },
    );
    return ExternalReferrerModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// Admin: métricas (vendedores externos con al menos un referido).
  static Future<List<AdminReferralStatRowModel>> listAdminReferralStats({
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_admin_referral_stats',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => AdminReferralStatRowModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Admin: usuarios referidos por un vendedor externo.
  static Future<List<AdminReferredUserRowModel>> listAdminReferredUsers({
    required String referrerId,
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await SupabaseAccess.client.rpc(
      'list_admin_referred_users',
      params: <String, dynamic>{
        'p_referrer_id': referrerId.trim(),
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (res is! List) return const [];
    return res
        .map((e) => AdminReferredUserRowModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }
}

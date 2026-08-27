
import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/admin/admin_user_activity_row_model.dart';
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
}



import 'package:motolink_pro_app/core/data/supabase_access.dart';
import 'package:motolink_pro_app/features/admin/admin_user_activity_row_model.dart';

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
}

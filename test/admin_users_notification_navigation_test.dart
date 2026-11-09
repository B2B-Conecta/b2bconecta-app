import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/notifications/notification_deep_link.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MainShellTabController.unregister();
    MainShellTabController.consumePendingNotificationType();
    MainShellTabController.consumePendingNotificationRelatedId();
    MainShellTabController.consumePendingKycProfileId();
    MainShellTabController.consumePendingAccountProfileId();
    MainShellTabController.consumePendingAdminUsersSection();
  });

  test('KYC admin abre Usuarios → Verificación con userId', () {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    const userId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
    navigateFromNotificationPayload(
      homeRole: AppHomeRole.administrador,
      type: 'kyc',
      relatedId: userId,
    );
    expect(tab, MainShellTabController.adminUsersTabIndex);
    expect(MainShellTabController.peekPendingKycProfileId(), userId);
    expect(
      MainShellTabController.peekPendingAdminUsersSection(),
      AdminUsersHubSection.verificacion,
    );
  });

  test('actividad con UUID admin abre Usuarios → Cuentas', () {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    const userId = '11111111-2222-3333-4444-555555555555';
    navigateFromNotificationPayload(
      homeRole: AppHomeRole.administrador,
      type: 'actividad',
      relatedId: userId,
    );
    expect(tab, MainShellTabController.adminUsersTabIndex);
    expect(MainShellTabController.peekPendingAccountProfileId(), userId);
    expect(
      MainShellTabController.peekPendingAdminUsersSection(),
      AdminUsersHubSection.cuentas,
    );
  });
}

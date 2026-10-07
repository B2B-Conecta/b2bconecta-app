import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/notifications/notification_deep_link.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MainShellTabController.unregister();
    MainShellTabController.consumePendingNotificationType();
    MainShellTabController.consumePendingNotificationRelatedId();
  });

  test('registro incompleto abre el perfil', () {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    navigateFromNotificationPayload(
      homeRole: AppHomeRole.aliado,
      type: 'actividad',
      relatedId: 'registro',
    );
    expect(tab, 3);
    expect(
      MainShellTabController.peekPendingNotificationType(),
      'actividad',
    );
  });

  test('cuenta lista abre el catálogo', () {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    navigateFromNotificationPayload(
      homeRole: AppHomeRole.importador,
      type: 'actividad',
      relatedId: 'catalogo',
    );
    expect(tab, 0);
  });
}

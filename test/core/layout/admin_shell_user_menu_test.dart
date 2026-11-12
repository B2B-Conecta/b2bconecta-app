import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motolink_pro_app/core/layout/admin_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/shell/desktop_nav_rail_preference.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_user_menu.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'desktop_nav_rail_expanded': true,
    });
    await DesktopNavRailPreference.setExpanded(true);
  });

  testWidgets('admin rail footer shows profile card and opens account menu',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDesktopShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          onOpenSettings: () {},
          onOpenProfile: () {},
          onOpenNotificationPrefs: () {},
          onSignOut: () async {
            signedOut = true;
          },
          destinations: const [
            ShellDestination(
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping,
              lucideIcon: LucideGlyph.truck,
              label: 'Pedidos',
              title: 'Pedidos',
            ),
          ],
          pages: const [
            ColoredBox(color: Colors.white, child: Text('Pedidos page')),
          ],
          profile: const ProfileModel(
            id: 'admin-1',
            role: 'administrador',
            businessName: 'Carlos Figueira',
            isOwner: true,
          ),
          unreadNotifications: 0,
          onNotificationTap: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Carlos Figueira'), findsWidgets);
    expect(find.text('Super Admin'), findsOneWidget);

    await tester.tap(find.text('Super Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Configuración de cuenta'), findsOneWidget);
    expect(find.text('Preferencias de notificaciones'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsNothing);
    expect(signedOut, isTrue);
  });

  test('ShellUserIdentity maps owner admin badge', () {
    expect(
      ShellUserIdentity.roleBadge(
        const ProfileModel(
          id: '1',
          role: 'administrador',
          isOwner: true,
        ),
      ),
      'Super Admin',
    );
    expect(
      ShellUserIdentity.roleBadge(
        const ProfileModel(
          id: '1',
          role: 'administrador',
        ),
      ),
      'Administrador',
    );
  });
}

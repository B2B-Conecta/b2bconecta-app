import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motolink_pro_app/core/layout/admin_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/shell/desktop_nav_rail_preference.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'desktop_nav_rail_expanded': true,
    });
    await DesktopNavRailPreference.setExpanded(true);
  });

  testWidgets('Usuarios accordion expands nested children and keeps selection',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedIndex = 0;
    Object? nestedId;

    final destinations = <ShellDestination>[
      const ShellDestination(
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        lucideIcon: LucideGlyph.truck,
        label: 'Pedidos',
        title: 'Pedidos',
      ),
      ShellDestination(
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
        lucideIcon: LucideGlyph.userRound,
        label: 'Usuarios',
        title: 'Usuarios',
        children: const [
          ShellDestination(
            icon: Icons.manage_accounts_outlined,
            selectedIcon: Icons.manage_accounts,
            lucideIcon: LucideGlyph.userRound,
            id: AdminUsersHubSection.cuentas,
            label: 'Cuentas',
            title: 'Cuentas',
          ),
          ShellDestination(
            icon: Icons.monitor_heart_outlined,
            selectedIcon: Icons.monitor_heart,
            lucideIcon: LucideGlyph.refreshCw,
            id: AdminUsersHubSection.actividad,
            label: 'Actividad',
            title: 'Actividad',
          ),
        ],
      ),
    ];

    Future<void> pumpShell() async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDesktopShell(
            selectedIndex: selectedIndex,
            selectedNestedId: nestedId,
            onDestinationSelected: (i) {
              selectedIndex = i;
              nestedId = null;
            },
            onNestedDestinationSelected: (parent, id) {
              selectedIndex = parent;
              nestedId = id;
            },
            destinations: destinations,
            pages: const [
              ColoredBox(color: Colors.white, child: Text('Pedidos page')),
              ColoredBox(color: Colors.white, child: Text('Usuarios page')),
            ],
            profile: const ProfileModel(
              id: 'admin-1',
              role: 'administrador',
              businessName: 'B2B Conecta Ops',
            ),
            unreadNotifications: 0,
            onNotificationTap: () {},
            onOpenSettings: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pumpShell();

    expect(find.text('Cuentas'), findsNothing);

    await tester.tap(find.text('Usuarios'));
    await pumpShell();
    await tester.pump(const Duration(milliseconds: 250));

    expect(selectedIndex, 1);
    expect(nestedId, AdminUsersHubSection.cuentas);
    expect(find.text('Cuentas'), findsWidgets);
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Verificación'), findsNothing);
    expect(find.text('Roles y permisos'), findsNothing);
    expect(find.text('Invitaciones'), findsNothing);
    expect(find.text('Todos los usuarios'), findsNothing);

    await tester.tap(find.text('Actividad'));
    await pumpShell();
    await tester.pump(const Duration(milliseconds: 250));

    expect(nestedId, AdminUsersHubSection.actividad);
    expect(find.text('Cuentas'), findsOneWidget);
  });
}

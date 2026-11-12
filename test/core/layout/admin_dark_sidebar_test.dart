import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:motolink_pro_app/core/layout/admin_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/shell/desktop_nav_rail_preference.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
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

  testWidgets('admin dark rail paints selected destination in blue fill',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDesktopShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            ShellDestination(
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping,
              lucideIcon: LucideGlyph.truck,
              label: 'Pedidos',
              title: 'Pedidos',
            ),
            ShellDestination(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              lucideIcon: LucideGlyph.settings,
              label: 'Perfil',
              title: 'Perfil',
            ),
          ],
          pages: const [
            ColoredBox(color: Colors.white, child: Text('Pedidos page')),
            ColoredBox(color: Colors.white, child: Text('Perfil page')),
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

    expect(find.text('Panel administrador'), findsOneWidget);
    expect(find.text('B2B Conecta Ops'), findsWidgets);

    final materials = tester.widgetList<Material>(
      find.ancestor(
        of: find.text('Pedidos'),
        matching: find.byType(Material),
      ),
    );
    expect(
      materials.any((m) => m.color == const Color(0xFF2563EB)),
      isTrue,
      reason: 'Selected rail tile should use corporate blue fill',
    );
  });
}

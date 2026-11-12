import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/layout/shell/admin_shell_top_bar.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

void main() {
  testWidgets('top bar muestra breadcrumbs y campana sin avatar', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    BuildContext? bellContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AdminShellTopBar(
            breadcrumbs: const [AdminShellBreadcrumb(label: 'Cuentas')],
            profile: const ProfileModel(
              id: 'a1',
              role: 'administrador',
              businessName: 'Admin B2B',
            ),
            unreadNotifications: 72,
            onNotificationTap: (ctx) => bellContext = ctx,
            showUserAvatar: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);

    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pump();
    expect(bellContext, isNotNull);
  });
}

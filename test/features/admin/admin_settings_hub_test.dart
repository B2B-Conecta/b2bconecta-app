import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/features/admin/admin_settings_hub.dart';
import 'package:motolink_pro_app/features/admin/admin_settings_tab.dart';
import 'package:motolink_pro_app/features/admin/commissions_settings_tab.dart';

void main() {
  testWidgets('AdminSettingsHub muestra las 4 pestañas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminSettingsHub(),
      ),
    );
    await tester.pump();

    expect(find.text('Perfil'), findsWidgets);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Seguridad'), findsOneWidget);
    expect(find.text('Comisiones'), findsOneWidget);
    expect(find.text('Ajustes del sistema'), findsOneWidget);
  });

  testWidgets('initialTab Notificaciones selecciona esa pestaña', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminSettingsHub(
          initialTab: AdminSettingsTab.notificaciones,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Notificaciones'), findsWidgets);
  });

  testWidgets('CTA Comisiones invoca callback', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommissionsSettingsTab(
            onOpenCommissions: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(); // allow async load to finish empty
    await tester.tap(find.text('Ver historial completo en Comisiones'));
    await tester.pump();

    expect(opened, isTrue);
  });
}

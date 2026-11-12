import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/quick_actions_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders title and four quick actions including Reportes',
      (tester) async {
    var invite = false;
    var orders = false;
    var reports = false;
    var settings = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: QuickActionsCard(
                onInviteTaller: () => invite = true,
                onReviewOrders: () => orders = true,
                onOpenReports: () => reports = true,
                onOpenSettings: () => settings = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accesos Directos Operativos'), findsOneWidget);
    expect(find.text('Invitar / Nuevo Taller'), findsOneWidget);
    expect(find.text('Revisar Pedidos'), findsOneWidget);
    expect(find.text('Ver Reportes'), findsOneWidget);
    expect(find.text('Ajustes del Sistema'), findsOneWidget);
    expect(find.text('Actualizar Tasa BCV'), findsNothing);

    expect(find.byType(LucideIcon), findsWidgets);

    await tester.tap(find.text('Invitar / Nuevo Taller'));
    await tester.pump();
    expect(invite, isTrue);

    await tester.tap(find.text('Revisar Pedidos'));
    await tester.pump();
    expect(orders, isTrue);

    await tester.tap(find.text('Ver Reportes'));
    await tester.pump();
    expect(reports, isTrue);

    await tester.tap(find.text('Ajustes del Sistema'));
    await tester.pump();
    expect(settings, isTrue);
  });
}

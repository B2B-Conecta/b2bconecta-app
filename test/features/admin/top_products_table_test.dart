import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/features/admin/admin_top_products_week.dart';
import 'package:motolink_pro_app/features/admin/top_products_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders title and five product rows', (tester) async {
    final controller = AdminTopProductsWeek(
      seed: AdminTopProductsWeekSnapshot.structuredFallback(bcvRate: 36.5),
    );
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TopProductsTable(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Productos más vendidos de la semana'),
      findsOneWidget,
    );
    expect(
      find.text('Top 5 artículos ordenados por ingresos generados'),
      findsOneWidget,
    );
    expect(find.text('Disco EBC 245 mm'), findsOneWidget);
    expect(find.text('Casco Venture 1.0 MIPS'), findsOneWidget);
    expect(find.textContaining('Pastillas'), findsOneWidget);
    expect(find.textContaining('USD'), findsWidgets);
    expect(find.textContaining('Bs '), findsWidgets);
  });

  test('structured fallback has five rows sorted by example data', () {
    final snap = AdminTopProductsWeekSnapshot.structuredFallback();
    expect(snap.rows.length, 5);
    expect(snap.isFallback, isTrue);
    expect(snap.rows.first.name, contains('Disco EBC'));
  });
}

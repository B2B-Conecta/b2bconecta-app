import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/features/admin/admin_revenue_over_time.dart';
import 'package:motolink_pro_app/features/admin/revenue_over_time_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AdminRevenueOverTime seeded() {
    final from = DateTime(2026, 10, 14);
    final points = <RevenueDayPoint>[
      for (var i = 0; i < 30; i++)
        RevenueDayPoint(
          date: from.add(Duration(days: i)),
          usd: 800 + i * 40.0,
          previousUsd: 600 + i * 30.0,
        ),
    ];
    return AdminRevenueOverTime(
      seed: AdminRevenueOverTimeSnapshot(
        points: points,
        bcvRate: 36.5,
        from: from,
        to: from.add(const Duration(days: 29)),
      ),
    );
  }

  testWidgets('renders title, subtitle and chart container', (tester) async {
    final series = seeded();
    addTearDown(series.dispose);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RevenueOverTimeChart(series: series),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ingresos en el tiempo'), findsOneWidget);
    expect(find.text('Últimos 30 días'), findsOneWidget);
    expect(find.textContaining('Comparar con los 30 días anteriores'),
        findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('compare toggle enables previous series state', (tester) async {
    final series = seeded();
    addTearDown(series.dispose);
    expect(series.comparePrevious, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RevenueOverTimeChart(series: series),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(series.comparePrevious, isTrue);
  });

  test('axis and money formatters', () {
    expect(RevenueOverTimeChart.formatAxisUsd(0), '\$0');
    expect(RevenueOverTimeChart.formatAxisUsd(10000), '\$10k');
    expect(RevenueOverTimeChart.formatUsdMoney(1234.5), '\$1,234.50 USD');
    expect(
      RevenueOverTimeChart.formatDayLabel(DateTime(2026, 10, 14)),
      '14 Oct',
    );
  });

  test('structured fallback has 30 points', () {
    final snap = AdminRevenueOverTimeSnapshot.structuredFallback(bcvRate: 36);
    expect(snap.points.length, 30);
    expect(snap.isFallback, isTrue);
    expect(snap.maxUsd, greaterThan(0));
  });
}

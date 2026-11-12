import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_dashboard_stats.dart';
import 'package:motolink_pro_app/features/admin/stats_cards_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AdminDashboardStats seededStats() {
    return AdminDashboardStats(
      seed: const AdminDashboardStatsSnapshot(
        activeUsers: 12847,
        activeUsersDeltaPct: 12,
        activeOrders: 342,
        activeOrdersDeltaPct: -3,
        revenueUsd: 48293,
        revenueDeltaPct: 8,
        bcvRate: 36.5,
        conversionPct: 3.2,
        conversionDeltaPct: 0.4,
      ),
    );
  }

  Future<void> pumpRow(
    WidgetTester tester, {
    required Size size,
    required AdminDashboardStats stats,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: size.width,
              child: StatsCardsRow(stats: stats),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders four metric cards with icons and values',
      (tester) async {
    final stats = seededStats();
    addTearDown(stats.dispose);

    await pumpRow(tester, size: const Size(1280, 800), stats: stats);

    expect(find.text('Usuarios / talleres activos'), findsOneWidget);
    expect(find.text('Pedidos activos'), findsOneWidget);
    expect(find.text('Ingresos totales'), findsOneWidget);
    expect(find.text('Tasa de conversión / cierre'), findsOneWidget);

    expect(find.text('12.847'), findsOneWidget);
    expect(find.text('342'), findsOneWidget);
    expect(find.text('48.293,00 USD'), findsOneWidget);
    expect(find.textContaining('Bs '), findsOneWidget);
    expect(find.text('3,2%'), findsOneWidget);

    expect(find.byType(AdminStatCard), findsNWidgets(4));
    // 4 iconos de métrica + 4 de tendencia.
    expect(find.byType(LucideIcon), findsNWidgets(8));
  });

  testWidgets('desktop >1100 lays out four cards in one row', (tester) async {
    final stats = seededStats();
    addTearDown(stats.dispose);

    await pumpRow(tester, size: const Size(1280, 800), stats: stats);

    expect(find.byType(AdminStatCard), findsNWidgets(4));

    final tops = List.generate(4, (i) {
      return tester
          .getTopLeft(find.byKey(ValueKey<String>('admin-stat-card-slot-$i')))
          .dy;
    });
    expect(tops.every((t) => (t - tops.first).abs() < 0.5), isTrue);

    final lefts = List.generate(4, (i) {
      return tester
          .getTopLeft(find.byKey(ValueKey<String>('admin-stat-card-slot-$i')))
          .dx;
    });
    expect(lefts[0] < lefts[1], isTrue);
    expect(lefts[1] < lefts[2], isTrue);
    expect(lefts[2] < lefts[3], isTrue);
  });

  testWidgets('tablet width uses two columns', (tester) async {
    final stats = seededStats();
    addTearDown(stats.dispose);

    await pumpRow(tester, size: const Size(800, 900), stats: stats);

    final widths = List.generate(4, (i) {
      final box = tester.widget<SizedBox>(
        find.byKey(ValueKey<String>('admin-stat-card-slot-$i')),
      );
      return box.width!;
    });
    // 2 cols: (800 - 12) / 2 = 394
    expect(widths.every((w) => (w - 394).abs() < 0.5), isTrue);

    final y0 = tester
        .getTopLeft(find.byKey(const ValueKey('admin-stat-card-slot-0')))
        .dy;
    final y1 = tester
        .getTopLeft(find.byKey(const ValueKey('admin-stat-card-slot-1')))
        .dy;
    final y2 = tester
        .getTopLeft(find.byKey(const ValueKey('admin-stat-card-slot-2')))
        .dy;
    expect((y0 - y1).abs() < 0.5, isTrue);
    expect(y2 > y0 + 20, isTrue);
  });

  testWidgets('mobile width uses compact 2x2 grid', (tester) async {
    final stats = seededStats();
    addTearDown(stats.dispose);

    await pumpRow(tester, size: const Size(390, 900), stats: stats);

    final widths = List.generate(4, (i) {
      final box = tester.widget<SizedBox>(
        find.byKey(ValueKey<String>('admin-stat-card-slot-$i')),
      );
      return box.width!;
    });
    // 2 cols: (390 - 12) / 2 = 189
    expect(widths.every((w) => (w - 189).abs() < 0.5), isTrue);

    final y0 = tester
        .getTopLeft(find.byKey(const ValueKey('admin-stat-card-slot-0')))
        .dy;
    final y1 = tester
        .getTopLeft(find.byKey(const ValueKey('admin-stat-card-slot-1')))
        .dy;
    final y2 = tester
        .getTopLeft(find.byKey(const ValueKey('admin-stat-card-slot-2')))
        .dy;
    expect((y0 - y1).abs() < 0.5, isTrue);
    expect(y2 > y0 + 20, isTrue);
  });

  test('revenueBs uses active BCV rate', () {
    const snap = AdminDashboardStatsSnapshot(
      activeUsers: 1,
      activeUsersDeltaPct: 0,
      activeOrders: 1,
      activeOrdersDeltaPct: 0,
      revenueUsd: 100,
      revenueDeltaPct: 0,
      bcvRate: 36.5,
      conversionPct: 0,
      conversionDeltaPct: 0,
    );
    expect(snap.revenueBs, 3650);
  });
}

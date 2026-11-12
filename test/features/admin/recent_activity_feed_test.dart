import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/features/admin/admin_recent_activity.dart';
import 'package:motolink_pro_app/features/admin/recent_activity_feed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders title, zebra rows and Ver todo', (tester) async {
    final now = DateTime(2026, 11, 12, 10, 0);
    final activity = AdminRecentActivity(
      seed: AdminRecentActivitySnapshot.structuredFallback(now: now),
    );
    addTearDown(activity.dispose);

    var seeAll = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: RecentActivityFeed.preferredHeight,
            width: 360,
            child: RecentActivityFeed(
              activity: activity,
              onSeeAll: () => seeAll = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Actividad reciente'), findsOneWidget);
    expect(find.text('Taller Moto Ruices'), findsOneWidget);
    expect(find.textContaining('creó un nuevo pedido'), findsWidgets);
    expect(find.text('Ver todo'), findsOneWidget);

    await tester.tap(find.text('Ver todo'));
    await tester.pump();
    expect(seeAll, isTrue);
  });

  test('formatRelativeEs covers minutes and hours', () {
    final now = DateTime(2026, 11, 12, 12, 0);
    expect(
      AdminRecentActivity.formatRelativeEs(
        now.subtract(const Duration(minutes: 2)),
        now,
      ),
      'hace 2 min',
    );
    expect(
      AdminRecentActivity.formatRelativeEs(
        now.subtract(const Duration(hours: 1)),
        now,
      ),
      'hace 1 h',
    );
    expect(
      AdminRecentActivity.formatRelativeEs(
        now.subtract(const Duration(minutes: 15)),
        now,
      ),
      'hace 15 min',
    );
  });

  test('structured fallback has eight items', () {
    final snap = AdminRecentActivitySnapshot.structuredFallback();
    expect(snap.items.length, 8);
    expect(snap.isFallback, isTrue);
  });

  test('initials helper', () {
    final item = RecentActivityItem(
      id: '1',
      kind: RecentActivityKind.orderCreated,
      actorName: 'Taller Moto Ruices',
      description: 'x',
      at: DateTime(2026, 1, 1),
    );
    expect(item.initials, 'TM');
  });
}

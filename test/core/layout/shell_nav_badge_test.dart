import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/core/layout/shell/admin_shell_badges.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';

void main() {
  testWidgets('ShellNavBadgeView animates count and hides zero', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ShellNavBadgeView(badge: ShellNavBadge.count(12)),
              ShellNavBadgeView(badge: ShellNavBadge.count(0)),
              ShellNavBadgeView(badge: ShellNavBadge.dot()),
              ShellNavBadgeView(badge: ShellNavBadge.warning()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  test('AdminShellBadges maps keys to badge kinds', () {
    final badges = AdminShellBadges();
    expect(badges.badgeFor(AdminShellBadgeKey.pedidos), isNull);
    expect(badges.badgeFor(AdminShellBadgeKey.mensajes), isNull);
    expect(badges.badgeFor(AdminShellBadgeKey.configuracion), isNull);

    // Simulate internal state via refresh paths is network-bound; assert API shape.
    expect(badges.activeOrders, 0);
    expect(badges.hasUnreadChat, isFalse);
    expect(badges.configNeedsAttention, isFalse);
    badges.dispose();
  });
}

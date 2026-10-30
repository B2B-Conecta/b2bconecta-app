import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';
import 'package:motolink_pro_app/core/layout/shell/desktop_navigation_shell.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/features/orders/shared/order_workspace.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_list_heading.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'order_workspace_test.dart' show fixture;

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final reduceMotion in [false, true]) {
      testWidgets('list and detail reclaim space at $width / $reduceMotion',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final search = TextEditingController();
        addTearDown(search.dispose);
        String? selected;
        final groups = List.generate(23, (i) => [fixture('scroll$i')]);
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 900), disableAnimations: reduceMotion),
                child: StatefulBuilder(builder: (context, setState) {
                  final workspace = OrderWorkspace(
                    groups: groups,
                    selectedKey: selected,
                    onSelect: (key) => setState(() => selected = key),
                    onClose: () => setState(() => selected = null),
                    controls: Column(children: [
                      OrdersListHeading(count: groups.length),
                      TextField(
                          controller: search,
                          decoration:
                              const InputDecoration(labelText: 'Buscar')),
                    ]),
                    detailBuilder: (_) => Column(children: [
                      for (var i = 0; i < 30; i++)
                        SizedBox(height: 80, child: Text('Detalle $i')),
                    ]),
                    onRefresh: () async {},
                    resetKey: 'all',
                    onClearFilters: () {},
                  );
                  if (width < 1000) return Scaffold(body: workspace);
                  return DesktopNavigationShell(
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                    destinations: const [
                      ShellDestination(
                        icon: Icons.shopping_cart_outlined,
                        selectedIcon: Icons.shopping_cart,
                        label: 'Pedidos',
                        title: 'Pedidos',
                        subtitle: 'En curso · entregas',
                        compactHeaderOnScroll: true,
                      ),
                    ],
                    pages: [workspace],
                    profile: const ProfileModel(id: 'qa', role: 'aliado'),
                    unreadNotifications: 0,
                    onNotificationTap: () {},
                    onOpenSettings: () {},
                    railBadgeLabel: 'Tienda de prueba',
                  );
                }))));
        await tester.pumpAndSettle();
        final list = find.byType(Scrollable).last;
        final expandedHeight = tester.getSize(list).height;
        await tester.enterText(find.byType(TextField), 'Texto conservado');
        await tester.drag(list, const Offset(0, -150));
        await tester.pumpAndSettle();
        expect(tester.getSize(list).height, greaterThan(expandedHeight + 20));
        expect(search.text, 'Texto conservado');
        if (width >= 1000) {
          expect(find.text('En curso · entregas'), findsNothing);
          expect(
              tester
                  .getSize(find.byKey(const ValueKey('desktop-page-heading')))
                  .height,
              0);
        } else {
          expect(find.text('Pedidos'), findsNothing);
        }
        expect(find.text('23 pedidos'), findsNothing);
        final position = tester.state<ScrollableState>(list).position;
        final offset = position.pixels;
        // Small movements near the threshold must not flap the header.
        position.jumpTo(40);
        await tester.pumpAndSettle();
        expect(tester.getSize(list).height, greaterThan(expandedHeight + 20));
        position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.getSize(list).height, closeTo(expandedHeight, 1));
        expect(find.text('23 pedidos'), findsOneWidget);
        position.jumpTo(offset);
        await tester.pumpAndSettle();
        final open = find.byType(OrderWorkspace);
        final activeRow = find.descendant(
            of: open, matching: find.textContaining('#SCROLL2'));
        await tester.ensureVisible(activeRow.first);
        await tester.tap(activeRow.first);
        await tester.pumpAndSettle();
        final detailScroll = find.byType(SingleChildScrollView).last;
        final detailHeight = tester.getSize(detailScroll).height;
        await tester.drag(detailScroll, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(tester.getSize(detailScroll).height,
            greaterThan(detailHeight + 20));
        expect(find.byTooltip('Volver a pedidos'), findsOneWidget);
        if (width >= 1000) {
          // The full-collapse behavior belongs to the list only.
          expect(
              tester
                  .getSize(find.byKey(const ValueKey('desktop-page-heading')))
                  .height,
              greaterThan(30));
        }
        await tester.tap(find.byTooltip('Volver a pedidos'));
        await tester.pumpAndSettle();
        expect(search.text, 'Texto conservado');
        expect(find.text('1–10 de 23'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('horizontal and nested scrolls do not compact the page',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ScrollCompactLayout(builder: (context, compact) {
      return Column(children: [
        Text(compact ? 'compacto' : 'completo'),
        SizedBox(
            height: 100,
            child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [SizedBox(width: 2000)])),
        Expanded(
            child: ListView(children: [
          SizedBox(
              height: 200,
              child: ListView(children: const [SizedBox(height: 2000)])),
        ])),
      ]);
    }))));
    await tester.drag(find.byType(ListView).first, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.text('completo'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.text('completo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

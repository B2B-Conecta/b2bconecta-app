import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/catalog_browse_layout.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_quick_filters.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';

void main() {
  testWidgets('active viewport owns the header policy across mounted pages',
      (tester) async {
    final catalogScroll = ScrollController();
    final detailScroll = ScrollController();
    addTearDown(catalogScroll.dispose);
    addTearDown(detailScroll.dispose);
    var page = 0;
    late StateSetter selectPage;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          selectPage = setState;
          return ScrollCompactLayout(
            resetKey: page,
            builder: (context, compact) => Column(children: [
              if (!ScrollCompactState.hideHeadingOf(context))
                const Text('Cabecera del módulo'),
              Expanded(
                child: IndexedStack(index: page, children: [
                  CatalogBrowseLayout(
                    heading: const Text('Catálogo de repuestos'),
                    search: const Text('Buscar'),
                    content: ListView(
                        controller: catalogScroll,
                        children: const [SizedBox(height: 4000)]),
                  ),
                  ScrollCompactLayout(
                    collapseHeadingWhenCompact: false,
                    builder: (_, __) => ListView(
                        controller: detailScroll,
                        children: const [SizedBox(height: 4000)]),
                  ),
                ]),
              ),
            ]),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    catalogScroll.jumpTo(100);
    await tester.pumpAndSettle();
    expect(find.text('Cabecera del módulo'), findsNothing);
    selectPage(() => page = 1);
    await tester.pumpAndSettle();
    detailScroll.jumpTo(100);
    await tester.pumpAndSettle();
    expect(find.text('Cabecera del módulo'), findsOneWidget);
    selectPage(() => page = 0);
    await tester.pumpAndSettle();
    catalogScroll.jumpTo(150);
    await tester.pumpAndSettle();
    expect(find.text('Cabecera del módulo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1440.0]) {
    for (final reduceMotion in [false, true]) {
      testWidgets(
          'catalog keeps controls while chrome recedes: $width / $reduceMotion',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        final search = TextEditingController();
        final focus = FocusNode();
        addTearDown(scroll.dispose);
        addTearDown(search.dispose);
        addTearDown(focus.dispose);
        var selected = AliadoCatalogQuickFilter.all;
        var promotionsOpened = 0;
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 900), disableAnimations: reduceMotion),
            child: Scaffold(
              body: StatefulBuilder(builder: (context, setState) {
                return CatalogBrowseLayout(
                  heading: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Catálogo de repuestos'),
                  ),
                  search: TextField(
                    controller: search,
                    focusNode: focus,
                    decoration: const InputDecoration(hintText: 'Buscar'),
                  ),
                  quickFilters: AliadoCatalogQuickFilters(
                    selected: selected,
                    onSelected: (value) => setState(() => selected = value),
                  ),
                  promotions: TextButton(
                    onPressed: () => promotionsOpened++,
                    child: const Text('Promociones (1)'),
                  ),
                  content: CustomScrollView(
                    controller: scroll,
                    slivers: [
                      SliverList.builder(
                        itemCount: 30,
                        itemBuilder: (_, index) => SizedBox(
                            height: 160, child: Text('Repuesto $index')),
                      ),
                    ],
                  ),
                  footer:
                      const SizedBox(height: 48, child: Text('Ver carrito')),
                );
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final heading = find.byKey(const ValueKey('catalog-heading'));
        final promotions = find.byKey(const ValueKey('catalog-promotions'));
        final viewport = find.byType(CustomScrollView);
        final initialHeight = tester.getSize(viewport).height;
        final searchState = tester.state(find.byType(TextField));
        expect(tester.getSize(heading).height, greaterThan(0));
        await tester.tap(find.text('Promociones (1)'));
        expect(promotionsOpened, 1);
        await tester.enterText(find.byType(TextField), 'Frenos');
        // Programmatic movement avoids a drag deliberately dismissing focus.
        scroll.jumpTo(100);
        await tester.pumpAndSettle();
        expect(tester.getSize(heading).height, 0);
        expect(tester.getSize(promotions).height, 0);
        expect(
            tester.getSize(viewport).height, greaterThan(initialHeight + 50));
        expect(search.text, 'Frenos');
        expect(focus.hasFocus, isTrue);
        expect(tester.state(find.byType(TextField)), same(searchState));
        expect(find.text('Ver carrito'), findsOneWidget);
        await tester.ensureVisible(find.text('Envío incluido'));
        await tester.tap(find.text('Envío incluido'));
        await tester.pumpAndSettle();
        expect(selected, AliadoCatalogQuickFilter.shippingIncluded);
        expect(scroll.offset, 100);
        expect(tester.getSize(heading).height, 0);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.getSize(heading).height, greaterThan(0));
        expect(tester.getSize(promotions).height, greaterThan(0));
        expect(tester.getSize(viewport).height, closeTo(initialHeight, 1));
        expect(search.text, 'Frenos');
        expect(selected, AliadoCatalogQuickFilter.shippingIncluded);
        // The horizontal quick filters must not collapse the page header.
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(-160, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(heading).height, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

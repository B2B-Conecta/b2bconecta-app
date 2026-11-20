import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/layout/shell/aliado_shell_search.dart';
import 'package:motolink_pro_app/core/layout/shell/aliado_shell_search_model.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

void main() {
  tearDown(MainShellTabController.unregister);

  testWidgets('shell search opens the filtered catalog', (tester) async {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliadoShellSearch(focusNode: focus),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'bujia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(tab, AliadoShellTabs.catalogo);
    final typed = MainShellTabController.consumeAliadoCatalogRequest()!;
    expect(typed.filters.searchQuery, 'bujia');
    expect(typed.openFilters, isFalse);
    expect(find.byTooltip('Filtros rápidos'), findsNothing);
  });

  testWidgets('focus shows suggestions and enter selects the highlighted one',
      (tester) async {
    int? tab;
    MainShellTabController.register((index) => tab = index);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliadoShellSearch(
          focusNode: focus,
          recentSearches: AliadoRecentSearchStore(seed: const []),
          loadParts: (_) async => const [],
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('Búsquedas sugeridas'), findsOneWidget);
    expect(find.text('Pastillas de freno'), findsOneWidget);
    expect(find.text('Frenos'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.byKey(const Key('aliado-shell-search-active')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(tab, AliadoShellTabs.catalogo);
    final request = MainShellTabController.consumeAliadoCatalogRequest()!;
    expect(request.filters.searchQuery, 'Pastillas de freno');
    expect(find.text('Búsquedas sugeridas'), findsNothing);
  });

  testWidgets('escape closes the panel and clear removes the query',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliadoShellSearch(
          focusNode: focus,
          recentSearches: AliadoRecentSearchStore(seed: const ['Cadena']),
          loadParts: (_) async => const [],
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('Cadena'), findsOneWidget);
    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    expect(find.text('Cadena'), findsNothing);

    await tester.enterText(find.byType(TextField), 'disco');
    await tester.pump();
    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Búsquedas sugeridas'), findsNothing);
  });

  testWidgets('a typed query previews the part, price and catalog link',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliadoShellSearch(
          focusNode: focus,
          recentSearches: AliadoRecentSearchStore(seed: const []),
          loadParts: (_) async => [
            PartModel(
              id: 'p1',
              nombre: 'Pastilla EBC',
              precio: 12,
              stock: 20,
              sku: 'EBC-1',
              ownerBusinessName: 'Andes',
            ),
          ],
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'pastilla');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Pastilla EBC'), findsWidgets);
    expect(find.text('+ Agregar'), findsOneWidget);
    expect(find.textContaining('12.00 USD'), findsOneWidget);
    expect(
      find.textContaining('Ver todos los resultados para «pastilla»'),
      findsOneWidget,
    );
  });

  test('highlight ignores accents and category shortcuts stay stable', () {
    final pieces = aliadoSearchHighlightPieces('Bujía NGK', 'bujia');
    expect(pieces.first.text, 'Bujía');
    expect(pieces.first.match, isTrue);
    expect(pieces[1].match, isFalse);

    final empty = aliadoShellCategoryHits(query: '', groups: const []);
    expect(
      empty.map((hit) => hit.label).toList(),
      ['Frenos', 'Transmisión', 'Accesorios', 'Motor'],
    );
    final typed = aliadoShellCategoryHits(query: 'pastillas', groups: const []);
    expect(typed.single.label, 'Pastillas');
    expect(typed.single.family, 'Frenos');

    final completions = aliadoShellCompletions(
      query: 'buj',
      parts: [
        PartModel(id: '1', nombre: 'Bujía iridium', precio: 4, stock: 8),
      ],
    );
    expect(completions, contains('Bujía'));
    expect(completions, contains('Bujía iridium'));
  });
}

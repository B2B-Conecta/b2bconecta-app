import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/features/inventory/importer_inventory_layout.dart';

void main() {
  test('el paginador usa el total filtrado, no el lote de 40', () {
    expect(inventoryPagerTotal(loaded: 40, matching: 87), 87);
    expect(inventoryPagerTotal(loaded: 40, matching: null), 40);
    expect(inventoryPagerTotal(loaded: 40, matching: 12), 40);
  });

  test('hay más páginas hasta cubrir el conteo, y se detiene al final', () {
    expect(
      inventoryHasMore(loaded: 40, batchLength: 40, fetchSize: 40, matching: 87),
      isTrue,
    );
    expect(
      inventoryHasMore(loaded: 87, batchLength: 7, fetchSize: 40, matching: 87),
      isFalse,
    );
    expect(
      inventoryHasMore(loaded: 40, batchLength: 40, fetchSize: 40, matching: 40),
      isFalse,
    );
    expect(
      inventoryHasMore(loaded: 40, batchLength: 40, fetchSize: 40),
      isTrue,
    );
  });

  test('el subtítulo coincide con el inventario y explica el filtro', () {
    expect(
      inventoryRegisteredLabel(registered: 87, matching: 87, filtering: false),
      '87 productos registrados',
    );
    expect(
      inventoryRegisteredLabel(registered: 87, matching: 12, filtering: true),
      '12 de 87 productos',
    );
    expect(
      inventoryRegisteredLabel(registered: null, matching: 12, filtering: true),
      'Tus productos',
    );
  });

  testWidgets('la barra llega hasta el último producto, no hasta el lote cargado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ListPageBar(
          total: 87,
          pageIndex: 0,
          pageSize: 10,
          onPageIndex: _noopIndex,
          onPageSize: _noopSize,
        ),
      ),
    ));
    expect(find.text('1–10 de 87'), findsOneWidget);
  });
}

void _noopIndex(int _) {}

void _noopSize(int _) {}

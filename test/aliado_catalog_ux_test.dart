import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/core/layout/aliado_bottom_nav.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/related_products.dart';

void main() {
  test('aliado tabs keep catalog in the center as the entry panel', () {
    expect(AliadoShellTabs.pedidos, 0);
    expect(AliadoShellTabs.reputacion, 1);
    expect(AliadoShellTabs.catalogo, 2);
    expect(AliadoShellTabs.favoritos, 3);
    expect(AliadoShellTabs.perfil, 4);
  });

  test('related products prefer the same importer and skip the current sku', () {
    final current = _part(id: 'current', ownerId: 'moto', category: 'Cauchos');
    final related = pickRelatedProducts(
      current: current,
      candidates: [
        current,
        _part(id: 'other-owner', ownerId: 'boxes', category: 'Cauchos'),
        _part(id: 'same-paused', ownerId: 'moto', category: 'Cauchos', active: false),
        _part(id: 'same-short', ownerId: 'moto', category: 'Cauchos', stock: 1),
        _part(id: 'same-ok', ownerId: 'moto', category: 'Cauchos'),
      ],
    );

    expect(related.map((p) => p.id).toList(), ['same-ok', 'other-owner']);
    expect(relatedProductsTitle(current), 'Más en cauchos');
    expect(
      relatedProductsTitle(_part(id: 'x', ownerId: 'moto')),
      'Más de este proveedor',
    );
  });

  test('similar category spellings share one filter label', () {
    final groups = groupAliadoCatalogCategories(const [
      'Freno',
      'frenos',
      'FRENOS',
      'frnos',
      'Transmisión',
      'transmisiones',
      'Motor',
      'Moto',
      'Accesorio',
      'Accesorios',
    ]);

    String labelOf(String sample) {
      return groups
          .firstWhere((group) => group.values.contains(sample))
          .label;
    }

    expect(labelOf('Freno'), labelOf('frenos'));
    expect(labelOf('Freno'), labelOf('frnos'));
    expect(labelOf('Transmisión'), labelOf('transmisiones'));
    expect(labelOf('Accesorio'), labelOf('Accesorios'));
    expect(labelOf('Motor'), isNot(labelOf('Moto')));
    expect(
      groups.map((group) => group.label).toList(),
      ['Accesorios', 'Frenos', 'Motores', 'Motos', 'Transmisiones'],
    );
    expect(formatCatalogCategoryLabel('casco'), 'Cascos');
    expect(formatCatalogCategoryLabel('repuesto'), 'Repuestos');
    expect(
      formatCatalogCategoryLabel('ACCESORIO UNIVERSAL'),
      'Accesorios universales',
    );
    expect(
      formatCatalogCategoryLabel('BOMBILLOS Y LUCES LEDS'),
      'Bombillos y luces LEDS',
    );
    expect(formatCatalogCategoryLabel('RKV'), 'RKV');
    expect(formatCatalogCategoryLabel('SBR-HORSE-CG'), 'SBR-HORSE-CG');
    expect(formatCatalogCategoryLabel('BWS - SCOOTER'), 'BWS - scooters');
  });

  test('catalog category chips come from published categories', () {
    expect(
      aliadoCatalogCategoryChoices(
        categories: const ['Motor', 'Frenos', 'Motor', '  ', 'Cauchos'],
        selected: 'Eléctrico',
      ),
      ['Todos', 'Cauchos', 'Frenos', 'Motor', 'Eléctrico'],
    );
  });

  testWidgets('center catalog icon is circled and is the selected entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AliadoBottomNav(
            currentIndex: AliadoShellTabs.catalogo,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Reputación'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view), findsOneWidget);

    final circle = tester.widget<Container>(
      find.descendant(
        of: find.byType(AliadoBottomNav),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    final decoration = circle.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
  });
}

PartModel _part({
  required String id,
  required String ownerId,
  String? category,
  bool active = true,
  int stock = 20,
}) {
  return PartModel(
    id: id,
    ownerId: ownerId,
    nombre: id,
    precio: 1,
    stock: stock,
    isActive: active,
    category: category,
  );
}

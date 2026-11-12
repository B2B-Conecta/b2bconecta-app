import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/core/layout/aliado_bottom_nav.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/related_products.dart';

void main() {
  test('aliado opens Inicio and keeps catalog in the center', () {
    expect(AliadoShellTabs.inicio, 0);
    expect(AliadoShellTabs.pedidos, 1);
    expect(AliadoShellTabs.catalogo, 2);
    expect(AliadoShellTabs.favoritos, 3);
    expect(AliadoShellTabs.perfil, 4);
  });

  test('related products prefer the same importer and skip the current sku',
      () {
    final current = _part(id: 'current', ownerId: 'moto', category: 'Cauchos');
    final related = pickRelatedProducts(
      current: current,
      candidates: [
        current,
        _part(id: 'other-owner', ownerId: 'boxes', category: 'Cauchos'),
        _part(
            id: 'same-paused',
            ownerId: 'moto',
            category: 'Cauchos',
            active: false),
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
    expect(
      kRelatedProductsSectionTitle,
      'Productos relacionados que podrían interesarte',
    );
  });

  test('orderPartsByIds preserves RPC ranking and skips missing rows', () {
    final ordered = orderPartsByIds(
      orderedIds: const ['b', 'missing', 'a', 'b'],
      parts: [
        _part(id: 'a', ownerId: 'moto'),
        _part(id: 'b', ownerId: 'moto'),
      ],
      limit: 2,
    );
    expect(ordered.map((p) => p.id).toList(), ['b', 'a']);
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
      return groups.firstWhere((group) => group.values.contains(sample)).label;
    }

    expect(labelOf('Freno'), labelOf('frenos'));
    expect(labelOf('Freno'), labelOf('frnos'));
    expect(labelOf('Transmisión'), labelOf('transmisiones'));
    expect(labelOf('Accesorio'), labelOf('Accesorios'));
    expect(labelOf('Motor'), isNot(labelOf('Moto')));
    expect(
      groups.map((group) => group.label).toList(),
      ['Accesorios', 'Frenos', 'Motor', 'Motos', 'Transmisión'],
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

  test('families expose only published children and retain exact filter values',
      () {
    final groups = catalogCategoryFamilies([
      'Caucho',
      'caucho',
      'TRIPA',
      'Casco',
      'Accesorios / Espejos',
      'Corona',
      'Transmisión / Piñones',
      'Categoría sin homologar',
    ]);
    expect(groups.map((group) => group.label),
        ['Cauchos y ruedas', 'Transmisión', 'Accesorios']);
    expect(catalogValuesForSelection(groups, 'Cauchos y ruedas'),
        unorderedEquals(['Caucho', 'caucho', 'TRIPA']));
    expect(formatCatalogCategoryLabel(groups.first.label), 'Cauchos');
    expect(catalogValuesForSelection(groups, 'Accesorios / Cascos'), ['Casco']);
    expect(
        catalogValuesForSelection(groups, 'Piñon'), ['Transmisión / Piñones']);
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
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          bottomNavigationBar: AliadoBottomNav(
            currentIndex: AliadoShellTabs.catalogo,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Reputación'), findsNothing);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    final catalogIcon = find.byWidgetPredicate((widget) =>
        widget is LucideIcon && widget.glyph == LucideGlyph.layoutGrid);
    expect(catalogIcon, findsOneWidget);
    expect(tester.widget<LucideIcon>(catalogIcon).size, 21);

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

    const labels = ['Inicio', 'Pedidos', 'Catálogo', 'Favoritos', 'Perfil'];
    for (var selected = 0; selected < labels.length; selected++) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          bottomNavigationBar:
              AliadoBottomNav(currentIndex: selected, onTap: (_) {}),
        ),
      ));
      for (final (index, label) in labels.indexed) {
        final entry = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((widget) =>
              widget is Semantics && widget.properties.selected != null),
        );
        expect(tester.widget<Semantics>(entry).properties.selected,
            index == selected);
      }
    }
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

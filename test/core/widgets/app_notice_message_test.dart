import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/app_notice_message.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/catalog_cart_bar.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

double contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('floating notice is readable and actionable in dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final theme = dark ? buildAppDarkTheme() : buildAppTheme();
      final surface = dark ? AppDarkTokens.surfaceElevated : Colors.white;
      var undone = false;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(builder: (context) {
            return Column(children: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  appActionNotice(
                    content: const AppNoticeMessage('Producto eliminado',
                        icon: LucideGlyph.handbag),
                    actionLabel: 'Deshacer',
                    onAction: () => undone = true,
                  ),
                ),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: AppNoticeMessage.error('No se pudo guardar.'),
                  ),
                ),
                child: const Text('Guardar'),
              ),
            ]);
          }),
        ),
      ));

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      final message = find.text('Producto eliminado');
      expect(message, findsOneWidget);
      expect(
        find.ancestor(
          of: message,
          matching: find
              .byWidgetPredicate((w) => w is Material && w.color == surface),
        ),
        findsOneWidget,
      );
      final foreground =
          DefaultTextStyle.of(tester.element(message)).style.color!;
      expect(contrastRatio(foreground, surface), greaterThanOrEqualTo(4.5));

      final button = find.widgetWithText(TextButton, 'Deshacer');
      final style = tester.widget<TextButton>(button).style!;
      final actionBg = style.backgroundColor!.resolve({})!;
      expect(actionBg, const Color(0xFF004BDD));
      expect(contrastRatio(style.foregroundColor!.resolve({})!, actionBg),
          greaterThanOrEqualTo(4.5));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(undone, isTrue);
      expect(message, findsNothing);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final icon = tester.widget<LucideIcon>(find.byType(LucideIcon));
      expect(icon.glyph, LucideGlyph.circleAlert);
      expect(contrastRatio(icon.color!, surface), greaterThanOrEqualTo(3));
      expect(find.text('No se pudo guardar.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('action notice matches the catalog cart bar height',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cart = CartService.instance..clear();
    addTearDown(cart.clear);
    cart.addOrIncrement(
      const PartModel(id: 'brake', nombre: 'Freno', precio: 10, stock: 12),
      precioUnitarioAliadoRef: 10,
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        bottomNavigationBar: CatalogCartBar(onOpen: () {}),
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              appActionNotice(
                content: const AppNoticeMessage('Producto eliminado',
                    icon: LucideGlyph.handbag),
                actionLabel: 'Abrir',
                onAction: () {},
              ),
            ),
            child: const Text('Mostrar aviso'),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar aviso'));
    await tester.pumpAndSettle();

    final cartBar = find.descendant(
      of: find.byType(CatalogCartBar),
      matching:
          find.byWidgetPredicate((w) => w is Material && w.elevation == 6),
    );
    final noticeBar = find.descendant(
      of: find.byType(SnackBar),
      matching:
          find.byWidgetPredicate((w) => w is Material && w.elevation == 4),
    );
    expect(tester.getSize(noticeBar).height, tester.getSize(cartBar).height);
    expect(
        tester.getSize(find.widgetWithText(TextButton, 'Abrir')).height,
        tester
            .getSize(find.widgetWithText(FilledButton, 'Ver carrito'))
            .height);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

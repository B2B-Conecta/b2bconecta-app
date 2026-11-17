import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/importer_inventory_dashboard.dart';

void main() {
  test('page progress becomes a fraction and a plain status stays indeterminate',
      () {
    expect(
      catalogReadPageFraction('Leyendo PDF · página 1 de 7.'),
      closeTo(1 / 7, 0.001),
    );
    expect(catalogReadPageFraction('Leyendo catalogo.pdf…'), isNull);
  });

  for (final size in const [
    Size(320, 640),
    Size(390, 844),
    Size(568, 320),
    Size(1440, 900),
  ]) {
    testWidgets('reading dialog fits $size', (tester) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Leyendo archivo'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(1 / 7, 0.001),
      );
    });
  }

  testWidgets('large text in dark mode stays inside the card and cancel works',
      (tester) async {
    var cancelled = false;
    final progress = await _pump(
      tester,
      size: const Size(390, 844),
      scale: 1.6,
      dark: true,
      onCancel: () => cancelled = true,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    expect(cancelled, isTrue);

    progress.value = 'Leyendo catalogo.pdf…';
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<ValueNotifier<String>> _pump(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  bool dark = false,
  VoidCallback? onCancel,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final progress = ValueNotifier('Leyendo PDF · página 1 de 7.');
  addTearDown(progress.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? buildAppDarkTheme() : buildAppTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: catalogReadProgressPreview(
      fileName: 'catalogo-repuestos-delta-caracas-muy-largo.pdf',
      progress: progress,
      onCancel: onCancel ?? () {},
    ),
  ));
  await tester.pump();
  return progress;
}

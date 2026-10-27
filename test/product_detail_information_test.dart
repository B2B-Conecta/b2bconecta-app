import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_information.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';

const _part = PartModel(
    id: 'internal-product-identity',
    nombre: 'Pastillas de freno delanteras',
    sku: 'FRE-245',
    category: 'Frenos',
    descripcion: 'Compuesto cerámico.\nJuego de dos pastillas.',
    compatibilidad: 'Yamaha XTZ 125\nAños 2019 a 2024',
    precio: 52,
    stock: 100,
    ownerBusinessName: 'Repuestos del Centro');

Future<void> _pump(WidgetTester tester,
    {PartModel part = _part,
    bool support = false,
    double scale = 1,
    bool dark = false}) async {
  await tester.pumpWidget(MaterialApp(
    theme: dark ? buildAppDarkTheme() : buildAppTheme(),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ProductDetailHeading(part: part),
          const SizedBox(height: 24),
          ProductDetailInformation(part: part, showInternalReference: support),
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'name leads identity and description and compatibility stay separate',
      (tester) async {
    await _pump(tester);
    expect(find.text(_part.nombre), findsOneWidget);
    expect(find.text('Código: FRE-245'), findsOneWidget);
    expect(tester.getTopLeft(find.text(_part.nombre)).dy,
        lessThan(tester.getTopLeft(find.text('Código: FRE-245')).dy));
    expect(find.text(_part.descripcion!), findsOneWidget);
    expect(find.text(_part.compatibilidad!), findsOneWidget);
    expect(tester.getTopLeft(find.text('Descripción')).dy,
        lessThan(tester.getTopLeft(find.text('Compatibilidad')).dy));
    expect(find.text('Especificaciones'), findsNothing);
    expect(find.text(_part.id), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing SKU never falls back to an internal identifier',
      (tester) async {
    const part = PartModel(
        id: 'uuid-must-not-be-sku', nombre: 'Corona', precio: 6, stock: 10);
    await _pump(tester, part: part);
    expect(find.textContaining('Código:'), findsNothing);
    expect(find.textContaining('uuid-must'), findsNothing);
    expect(find.text('Descripción'), findsNothing);
    expect(find.text('Compatibilidad'), findsNothing);
    expect(find.text('Especificaciones'), findsNothing);
    expect(find.text('El proveedor aún no ha añadido información técnica.'),
        findsOneWidget);
  });

  testWidgets(
      'published specification values are grouped and private fields stay hidden',
      (tester) async {
    final fields = buildCustomFieldsPayload(values: {
      'marca': 'Yamaha',
      'medida': '245 mm',
      'costo': 'dato-privado'
    }, aliadoVisibleKeys: {
      'marca',
      'medida'
    });
    await _pump(tester, part: _part.copyWith(customFields: fields));
    expect(find.text('Especificaciones'), findsOneWidget);
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Yamaha'), findsOneWidget);
    expect(find.text('Medida'), findsOneWidget);
    expect(find.text('245 mm'), findsOneWidget);
    expect(find.text('Costo'), findsNothing);
    expect(find.text('dato-privado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support details remain collapsed until requested',
      (tester) async {
    await _pump(tester, support: true);
    expect(find.text(_part.id), findsNothing);
    await tester.ensureVisible(find.text('Información para soporte'));
    await tester.tap(find.text('Información para soporte'));
    await tester.pumpAndSettle();
    expect(find.text(_part.id), findsOneWidget);
  });

  for (final scenario in [
    (width: 320.0, scale: 1.0, dark: false),
    (width: 390.0, scale: 1.6, dark: true),
    (width: 800.0, scale: 1.0, dark: false),
    (width: 1440.0, scale: 1.0, dark: false),
  ]) {
    testWidgets(
        'long names, codes and specification values remain readable at $scenario',
        (tester) async {
      tester.view.physicalSize = Size(scenario.width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.brightness = scenario.dark ? Brightness.dark : Brightness.light;
      addTearDown(() => AppColors.brightness = Brightness.light);
      final fields = buildCustomFieldsPayload(values: {
        'presentacion':
            'Juego completo con accesorios y guía de instalación del proveedor',
        'especificacion_tecnica_adicional':
            'Medida de montaje y características registradas para este repuesto',
        'costo': 'privado',
      }, aliadoVisibleKeys: {
        'presentacion',
        'especificacion_tecnica_adicional'
      });
      final part = _part.copyWith(
          nombre:
              'Pastillas de freno delanteras para motocicletas de alta cilindrada y uso urbano',
          sku: 'CODIGO-DE-REPUESTO-MUY-LARGO-12345678901234567890',
          customFields: fields);
      await _pump(tester,
          part: part, scale: scenario.scale, dark: scenario.dark);
      expect(find.text(part.nombre), findsOneWidget);
      expect(find.text('Código: ${part.sku}'), findsOneWidget);
      expect(find.text(fields['presentacion'].toString()), findsOneWidget);
      expect(find.text('privado'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'guest detail integrates identity without exposing support identifiers',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: ProductDetailScreen(
            part: _part, guestPreview: true, onRegisterToOrder: () {})));
    await tester.pumpAndSettle();
    expect(find.text(_part.nombre), findsOneWidget);
    expect(find.text('Código: FRE-245'), findsOneWidget);
    expect(find.text('Referencia interna (ID)'), findsNothing);
    expect(find.text('Información para soporte'), findsNothing);
    expect(find.textContaining(_part.id), findsNothing);
    expect(find.text('Regístrate para pedir'), findsOneWidget);
    expect(tester.getRect(find.text(_part.nombre)).bottom, lessThan(420));
    expect(find.text('Mín. 5 unidades'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(320, 640), scale: 1.6, dark: true),
    (size: const Size(568, 320), scale: 1.0, dark: false),
    (size: const Size(1440, 900), scale: 1.0, dark: false),
  ]) {
    testWidgets('complete detail stays usable at $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.brightness = scenario.dark ? Brightness.dark : Brightness.light;
      addTearDown(() => AppColors.brightness = Brightness.light);
      await tester.pumpWidget(MaterialApp(
        theme: scenario.dark ? buildAppDarkTheme() : buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: child!),
        home: ProductDetailScreen(
            part: _part, guestPreview: true, onRegisterToOrder: () {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text(_part.nombre), findsOneWidget);
      expect(find.text('Regístrate para pedir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

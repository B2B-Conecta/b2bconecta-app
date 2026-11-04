import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/cart/delivery_destination_dialog.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

const _profile = ProfileModel(
  id: 'buyer',
  estado: 'Miranda',
  ciudad: 'Caracas',
  direccion:
      'Av. Francisco de Miranda, Los Ruices, local 14 (frente estación), sector fiscal Caracas 1070.',
  fiscalMapsUrl: 'https://maps.app.goo.gl/test',
);

void main() {
  Future<void> open(WidgetTester tester,
      {ProfileModel profile = _profile,
      Size size = const Size(390, 720),
      ValueChanged<DeliveryDestinationResult?>? onResult}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: Builder(builder: (context) {
        return TextButton(
          onPressed: () async {
            final result = await showDialog<DeliveryDestinationResult>(
                context: context,
                builder: (_) => DeliveryDestinationDialog(
                    profile: profile,
                    paymentSummary: 'Pago en divisas (USD).'));
            onResult?.call(result);
          },
          child: const Text('Entrega'),
        );
      })),
    ));
    await tester.tap(find.text('Entrega'));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(398, 676), const Size(360, 640)]) {
    testWidgets('first validation message stays fully visible at $size',
        (tester) async {
      await open(tester, size: size);
      await tester.ensureVisible(find.text('Otra dirección'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otra dirección'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar pedido'));
      await tester.pumpAndSettle();
      final error = tester.getRect(find.text('Indica el estado.'));
      final action = tester.getRect(find.text('Confirmar pedido'));
      expect(error.bottom, lessThan(action.top - 8));
      expect(find.text('Indica el estado.').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'empty alternate address explains errors inside the dialog and focuses state',
      (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Otra dirección'));
    await tester.tap(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Indica el estado.'), findsOneWidget);
    expect(find.text('Indica la ciudad.'), findsOneWidget);
    expect(find.text('Indica la calle, sector y referencia.'), findsOneWidget);
    expect(find.text('Agrega el enlace de Google Maps.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final firstField = tester.widget<TextField>(find.byType(TextField).first);
    expect(firstField.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'invalid URL stays open and valid alternate address returns trimmed values',
      (tester) async {
    DeliveryDestinationResult? result;
    await open(tester, onResult: (value) => result = value);
    await tester.ensureVisible(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(fields.at(i));
      await tester.enterText(fields.at(i),
          [' Carabobo ', ' Valencia ', ' Calle 1, local 2 ', 'https:'][i]);
    }
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Usa un enlace completo: https://…'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(fields.last, ' https://maps.app.goo.gl/test ');
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(result!.useProfile, isFalse);
    expect(result!.texto,
        'Estado: Carabobo\nCiudad: Valencia\nDomicilio: Calle 1, local 2');
    expect(result!.mapsUrl, 'https://maps.app.goo.gl/test');
  });

  testWidgets(
      'missing profile map displays a visible error and switching clears it',
      (tester) async {
    await open(tester, profile: const ProfileModel(id: 'buyer'));
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Agrega el enlace de Google Maps en Mi perfil o elige otra dirección.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Agrega el enlace de Google Maps en Mi perfil o elige otra dirección.'),
        findsNothing);
  });

  testWidgets(
      'profile selection bypasses alternate errors; cancel returns no destination',
      (tester) async {
    DeliveryDestinationResult? result;
    await open(tester, onResult: (value) => result = value);
    await tester.ensureVisible(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra dirección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dirección de mi perfil'));
    await tester.tap(find.text('Dirección de mi perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(result!.useProfile, isTrue);
    expect(result!.texto, isNull);
    expect(result!.mapsUrl, isNull);
    result = null;
    await tester.tap(find.text('Entrega'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/kyc/importer_kyc_approved_aliados_panel.dart';
import 'package:motolink_pro_app/features/kyc/kyc_approved_aliado_model.dart';

void main() {
  testWidgets('la ficha no repite el estado que ya es sello en el listado',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showImporterActiveStoreSheet(
            context,
            aliado: const KycApprovedAliadoModel(
              id: '1',
              businessName: 'Servicio Biker El Hatillo C.A.',
              rif: 'J-503456789',
              estado: 'Miranda',
              ciudad: 'El Hatillo',
              direccion: 'Calle principal El Hatillo, local 7',
              phone: '+58 414-2000003',
            ),
          ),
          child: const Text('Abrir'),
        ),
      ),
    ));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Estado'), findsNothing);
    expect(find.text('Activa'), findsNothing);
    expect(find.text('RIF'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);
    expect(find.text('Contacto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

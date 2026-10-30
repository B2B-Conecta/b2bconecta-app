import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/payments/importer_pago_transfer_details_card.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';

void main() {
  testWidgets('pago movil transfer card builds in dark', (tester) async {
    AppColors.brightness = Brightness.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppDarkTheme(),
        home: Scaffold(
          body: ImporterPagoTransferDetailsCard(
            metodo: PagoMetodo.pagoMovil,
            instrucciones:
                'Banco: Banco de Venezuela\nTeléfono: +58 424-1000001\nCédula/RIF del titular: J-401234567\nTitular: Repuestos Delta Caracas C.A.',
            importadorNombre: 'Repuestos Delta Caracas C.A.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Datos para'), findsOneWidget);
    expect(find.textContaining('Banco de Venezuela'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
  });
}

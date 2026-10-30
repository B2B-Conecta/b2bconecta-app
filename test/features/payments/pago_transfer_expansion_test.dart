import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/payments/importer_pago_transfer_details_card.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_colors.dart';

void main() {
  testWidgets('transfer card inside ExpansionTile dark', (tester) async {
    FlutterError.onError = (d) {
      // ignore: avoid_print
      print('ERR ${d.exceptionAsString()}\n${d.stack}');
      FlutterError.presentError(d);
    };
    AppColors.brightness = Brightness.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppDarkTheme(),
        home: Builder(builder: (context) {
          final colors = OrderListColors.of(context);
          return Scaffold(
            body: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: colors.surface,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    maintainState: true,
                    title: const Text('Ver factura y opciones'),
                    children: [
                      DropdownButtonFormField<String>(
                        value: PagoMetodo.pagoMovil,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: PagoMetodo.pagoMovil, child: Text('Pago Móvil')),
                        ],
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 10),
                      ImporterPagoTransferDetailsCard(
                        metodo: PagoMetodo.pagoMovil,
                        instrucciones:
                            'Banco: Banco de Venezuela\nTeléfono: +58 424-1000001\nCédula/RIF del titular: J-401234567\nTitular: Repuestos Delta Caracas C.A.',
                        importadorNombre: 'Repuestos Delta Caracas C.A.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.textContaining('Banco de Venezuela'), findsOneWidget);
  });
}

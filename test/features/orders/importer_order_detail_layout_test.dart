import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_expandable_order_card.dart';
import 'package:motolink_pro_app/features/orders/shared/order_detail_layout.dart';
import 'package:motolink_pro_app/features/orders/shared/order_detail_overview.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_order_invoice_section.dart';
import 'order_workspace_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false));
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final width in [320.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('importer detail retains operations at $width dark=$dark',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var advanced = false;
        await tester.pumpWidget(MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ImporterExpandableOrderCard(
              request: fixture('test'),
              workspaceDetail: true,
              expanded: true,
              onToggle: () {},
              statusLabel: 'Por confirmar',
              nextStatus: 'en_preparacion',
              nextActionLabel: 'Confirmar pedido',
              onAdvance: () => advanced = true,
              expandedFooter: const TextField(
                  decoration: InputDecoration(labelText: 'Factura de prueba')),
              deliveryActions: const Text('Entrega de prueba'),
            )))));
        expect(find.byType(OrderDetailColumns), findsOneWidget);
        expect(find.text('Seguimiento'), findsOneWidget);
        expect(find.text('Productos'), findsOneWidget);
        expect(find.text('Pago y factura'), findsOneWidget);
        expect(find.text('Contacto'), findsOneWidget);
        expect(find.text('Ver chat'), findsNothing);
        final overview = find.byType(OrderDetailOverview);
        final chat = find.byTooltip('Mensajes del pedido');
        expect(chat, findsOneWidget);
        expect(find.text('Mensajes'), findsNothing);
        expect(tester.getTopLeft(chat).dy,
            lessThan(tester.getTopLeft(overview).dy + 65));
        final chatButton = find.ancestor(of: chat, matching: find.byType(IconButton)).first;
        expect(tester.getSize(chatButton).width, greaterThanOrEqualTo(44));
        expect(find.descendant(of: overview, matching: find.byType(Divider)), findsNothing);
        expect(find.text('Posventa'), findsNothing);
        expect(find.text('Revisa los productos y el siguiente paso del envío.'),
            findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Entrega de prueba'), findsOneWidget);
        await tester.ensureVisible(find.text('Confirmar pedido'));
        await tester.tap(find.text('Confirmar pedido'));
        expect(advanced, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('invoice action stays visible while help can be expanded',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ImporterOrderInvoiceSection(
                request: fixture('invoice'),
                onChanged: () {},
                useCompactHelp: true))));
    expect(find.text('Adjuntar factura (PDF o imagen)'), findsOneWidget);
    final help = find.text('Instrucciones de factura');
    expect(help, findsOneWidget);
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.text('Adjuntar factura (PDF o imagen)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

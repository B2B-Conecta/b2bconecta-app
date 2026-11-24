import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_order_detail_view.dart';
import 'package:motolink_pro_app/features/payments/mobile_supplier_payment_model.dart';
import 'package:motolink_pro_app/features/payments/mobile_supplier_payment_screen.dart';

TransactionRequestModel paymentFixture(
        {String id = 'one',
        String currency = 'BOLIVARES',
        String state = 'pendiente',
        bool invoice = true,
        bool cash = false}) =>
    TransactionRequestModel.fromJson({
      'id': id,
      'aliado_id': 'ally',
      'importador_id': 'supplier',
      'product_id': 'product',
      'status': 'en_preparacion',
      'cantidad': 5,
      'precio_unitario_proveedor': 100,
      'precio_unitario_aliado': currency == 'DIVISAS' ? 90 : 100,
      'precio_total_usd': currency == 'DIVISAS' ? 450 : 500,
      'precio_base_aliado_total': currency == 'DIVISAS' ? 450 : 500,
      'checkout_group_id': 'checkout',
      'metodo_pago_moneda': currency,
      'total_ref': 500,
      'total_bs': 5000,
      'tasa_bcv_aplicada': 10,
      'discount_rules': {
        'checkout_pricing_version': 1,
        'checkout_payment_currency': currency
      },
      'proveedor_factura_storage_path': invoice ? 'one/factura.pdf' : null,
      'proveedor_factura_file_name': invoice ? 'Factura F-00128.pdf' : null,
      'pago_estado_revision': state,
      'pago_metodo': cash
          ? 'efectivo'
          : currency == 'DIVISAS'
              ? 'zelle_divisas'
              : 'pago_movil',
      if (state != 'pendiente')
        'comprobante_pago_submitted_at': '2026-11-06T12:00:00Z',
      if (state == 'rechazado')
        'pago_comprobante_rechazo_nota': 'No se distingue la referencia',
      if (state == 'aprobado') 'pago_aprobado_at': '2026-11-07T12:00:00Z',
      'products': {'name': 'Disco EBC 245 mm'},
      'importador': {
        'business_name': 'Importadora Valencia',
        'accepted_pago_metodos': [
          'pago_movil',
          'transferencia',
          'zelle_divisas',
          'efectivo'
        ],
        'pago_metodo_instrucciones': {
          'pago_movil': 'Banco: Banco de ejemplo\nTeléfono: 0412 000 0000'
        }
      },
    });
final paymentProof = PickedDocumentBytes(
    bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jVioAAAAASUVORK5CYII='),
    fileName: 'comprobante.png');

Future<void> paymentPump(WidgetTester tester, Widget child,
    {double width = 390,
    double scale = 1,
    ThemeData? theme,
    Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: theme ?? ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: child));
  await tester.pumpAndSettle();
}

Future<void> paymentNext(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

Future<void> fillPayment(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('payment-reference')), '00012345');
  await tester.enterText(
      find.byKey(const ValueKey('payment-amount')), '5.000,00');
  await tester.ensureVisible(find.text('Adjuntar archivo'));
  await tester.tap(find.text('Adjuntar archivo'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('returning from a scrolled form restores the supplier at the top',
      (tester) async {
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture()], onChanged: () {}));
    await paymentNext(tester, 'Ver métodos de pago');
    await paymentNext(tester, 'Ya pagué · Revisar comprobante');
    await tester.enterText(
        find.byKey(const ValueKey('payment-amount')), '5000');
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Método de pago'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Importadora Valencia')).dy,
        greaterThanOrEqualTo(72));
    expect(
        tester.getTopLeft(find.text('Importadora Valencia')).dy, lessThan(160));
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
  });
  testWidgets(
      'mobile payment entry opens a dedicated flow without showing the legacy form',
      (tester) async {
    var opened = 0;
    await paymentPump(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: AliadoOrderDetailView(
          lines: [paymentFixture()],
          compact: true,
          summary: const SizedBox.shrink(),
          sectionsBuilder: (_, __, ___, ____) => AliadoOrderDetailSections(
              payment: const Text('Legacy payment form'),
              paymentStatus: 'Pendiente de pago',
              onOpenPayment: () => opened++),
        ))));
    await tester.ensureVisible(find.text('Pago y factura'));
    await tester.tap(find.text('Pago y factura'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Legacy payment form'), findsNothing);
  });
  test(
      'parses precise amounts without losing a decimal comma or accepting ambiguity',
      () {
    for (final value in [
      '237.033,93',
      '237,033.93',
      '237033.93',
      '237033,93'
    ]) {
      expect(parseDeclaredPaymentAmount(value), 237033.93);
    }
    for (final value in [
      '',
      '0',
      '-1',
      'NaN',
      '1e6',
      '12.345',
      '1,234',
      '12.34,56',
      '1000000000001'
    ]) {
      expect(parseDeclaredPaymentAmount(value), isNull, reason: value);
    }
  });
  test('currency and net snapshot prevent a second discount', () {
    final usd = MobileSupplierPaymentQuote(
        [paymentFixture(currency: 'DIVISAS')], 'zelle_divisas');
    expect(usd.payable, 450);
    expect(usd.methods, ['zelle_divisas', 'efectivo']);
    final bs = MobileSupplierPaymentQuote([paymentFixture()], 'pago_movil');
    expect(bs.payable, 5000);
    expect(bs.methods, ['pago_movil', 'transferencia']);
    expect(
        MobileSupplierPaymentQuote(
                [paymentFixture(), paymentFixture(id: 'two')], 'pago_movil')
            .payable,
        10000);
  });
  for (final config in [
    (390.0, 1.0, Brightness.light),
    (320.0, 1.6, Brightness.dark)
  ]) {
    testWidgets(
        'review before explicit single submission ${config.$1}/${config.$2}',
        (tester) async {
      var calls = 0, changed = 0;
      SupplierPaymentDeclaration? sent;
      await paymentPump(
          tester,
          MobileSupplierPaymentScreen(
              lines: [paymentFixture()],
              onChanged: () => changed++,
              now: () => DateTime(2026, 11, 21),
              pickProof: (_) async => paymentProof,
              submit: (lines, declaration, proof) async {
                calls++;
                sent = declaration;
                expect(proof!.fileName, 'comprobante.png');
                expect(lines.single.ownerId, 'supplier');
              }),
          width: config.$1,
          scale: config.$2,
          brightness: config.$3);
      expect(find.text('Factura F-00128.pdf'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('invoice-payment-status')),
              matching: find.text('Pendiente de pago')),
          findsOneWidget);
      expect(find.text('5 uds × 100.00 REF'), findsOneWidget);
      expect(find.text('500.00 REF'), findsNWidgets(2));
      await paymentNext(tester, 'Ver métodos de pago');
      expect(find.text('Pago Móvil'), findsOneWidget);
      expect(find.text('Pago desde tu banco en bolívares.'), findsOneWidget);
      expect(find.text('Transferencia desde tu cuenta en bolívares.'),
          findsOneWidget);
      expect(find.text('Zelle / divisas'), findsNothing);
      await paymentNext(tester, 'Ya pagué · Revisar comprobante');
      await paymentNext(tester, 'Enviar comprobante');
      expect(calls, 0);
      expect(find.text('Indica la referencia del pago.'), findsOneWidget);
      await fillPayment(tester);
      expect(find.text('Imagen adjunta · aún no enviada'), findsOneWidget);
      expect(calls, 0);
      await paymentNext(tester, 'Enviar comprobante');
      expect(calls, 1);
      expect(changed, 1);
      expect(sent!.reference, '00012345');
      expect(sent!.amount, 5000);
      expect(sent!.currency, 'BS');
      expect(find.text('Comprobante enviado'), findsOneWidget);
      expect(find.text('Pendiente de revisión'), findsOneWidget);
      expect(find.text('Tu pago fue confirmado'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('cash needs no file or payment reference', (tester) async {
    var calls = 0;
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture(currency: 'DIVISAS', cash: true)],
            onChanged: () {},
            submit: (_, declaration, proof) async {
              calls++;
              expect(proof, isNull);
              expect(declaration.method, 'efectivo');
              expect(declaration.currency, 'USD');
            }));
    await paymentNext(tester, 'Ver métodos de pago');
    await paymentNext(tester, 'Ya pagué · Revisar comprobante');
    await paymentNext(tester, 'Registrar pago en efectivo');
    expect(calls, 1);
    expect(find.text('Pago en efectivo registrado'), findsOneWidget);
  });
  testWidgets('no invoice blocks payment, approved payment is read-only',
      (tester) async {
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture(invoice: false)], onChanged: () {}));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Ver métodos de pago'))
            .onPressed,
        isNull);
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            key: const ValueKey('approved'),
            lines: [paymentFixture(state: 'aprobado')],
            onChanged: () {}));
    expect(find.text('Tu pago fue confirmado'), findsOneWidget);
    expect(find.text('Corregir datos o comprobante'), findsNothing);
    expect(
        find.text(
            formatEsShortDateTime(DateTime.parse('2026-11-06T12:00:00Z'))),
        findsOneWidget);
    expect(
        find.text(
            formatEsShortDateTime(DateTime.parse('2026-11-07T12:00:00Z'))),
        findsOneWidget);
  });
  testWidgets('rejection shows actual reason and correction path',
      (tester) async {
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture(state: 'rechazado')], onChanged: () {}));
    expect(find.text('Comprobante rechazado'), findsOneWidget);
    expect(find.text('No se distingue la referencia'), findsWidgets);
    await tester.ensureVisible(find.text('Corregir comprobante'));
    await tester.tap(find.text('Corregir comprobante'));
    await tester.pumpAndSettle();
    expect(find.text('Método de pago'), findsOneWidget);
  });
  testWidgets(
      'pending review keeps the method and refreshes to supplier confirmation',
      (tester) async {
    var approved = false;
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture(state: 'en_revision')],
            onChanged: () {},
            refreshInterval: null,
            loadLines: () async => [
                  paymentFixture(state: approved ? 'aprobado' : 'en_revision')
                ]));
    expect(find.text('Pendiente de revisión'), findsOneWidget);
    approved = true;
    await tester.ensureVisible(find.text('Actualizar estado'));
    await tester.tap(find.text('Actualizar estado'));
    await tester.pumpAndSettle();
    expect(find.text('Tu pago fue confirmado'), findsOneWidget);
  });
  testWidgets(
      'network ambiguity retries the identical declaration and blocks editing',
      (tester) async {
    var calls = 0;
    String? firstId;
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture()],
            onChanged: () {},
            pickProof: (_) async => paymentProof,
            submit: (_, declaration, __) async {
              calls++;
              if (calls == 1) {
                firstId = declaration.submissionId;
                throw TimeoutException('lost response');
              }
              expect(declaration.submissionId, firstId);
            }));
    await paymentNext(tester, 'Ver métodos de pago');
    await paymentNext(tester, 'Ya pagué · Revisar comprobante');
    await fillPayment(tester);
    await paymentNext(tester, 'Enviar comprobante');
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey('payment-reference')),
                matching: find.byType(TextField)))
            .readOnly,
        isTrue);
    await paymentNext(tester, 'Verificar envío');
    expect(calls, 2);
    expect(find.text('Comprobante enviado'), findsOneWidget);
  });
  testWidgets('sending disables duplicate taps until the request completes',
      (tester) async {
    final complete = Completer<void>();
    var calls = 0;
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture()],
            onChanged: () {},
            pickProof: (_) async => paymentProof,
            submit: (_, __, ___) {
              calls++;
              return complete.future;
            }));
    await paymentNext(tester, 'Ver métodos de pago');
    await paymentNext(tester, 'Ya pagué · Revisar comprobante');
    await fillPayment(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar comprobante'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Enviando…'))
            .onPressed,
        isNull);
    expect(calls, 1);
    complete.complete();
    await tester.pumpAndSettle();
    expect(find.text('Comprobante enviado'), findsOneWidget);
  });
  testWidgets(
      'status refresh runs while visible and stops when the page closes',
      (tester) async {
    var approved = false;
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture(state: 'en_revision')],
            onChanged: () {},
            refreshInterval: const Duration(seconds: 1),
            loadLines: () async => [
                  paymentFixture(state: approved ? 'aprobado' : 'en_revision')
                ]));
    approved = true;
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Tu pago fue confirmado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('canceling file selection keeps the form and never submits',
      (tester) async {
    var calls = 0;
    await paymentPump(
        tester,
        MobileSupplierPaymentScreen(
            lines: [paymentFixture()],
            onChanged: () {},
            pickProof: (_) async => null,
            submit: (_, __, ___) async {
              calls++;
            }));
    await paymentNext(tester, 'Ver métodos de pago');
    await paymentNext(tester, 'Ya pagué · Revisar comprobante');
    await tester.enterText(
        find.byKey(const ValueKey('payment-reference')), '0000123');
    await tester.ensureVisible(find.text('Adjuntar archivo'));
    await tester.tap(find.text('Adjuntar archivo'));
    await tester.pumpAndSettle();
    await paymentNext(tester, 'Enviar comprobante');
    expect(calls, 0);
    expect(
        find.text('Adjunta un comprobante antes de enviarlo.'), findsOneWidget);
  });
}

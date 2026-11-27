import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/mobile_order_action_widgets.dart';
import 'package:motolink_pro_app/features/orders/shared/order_postventa_chat_card.dart';
import 'package:motolink_pro_app/features/orders/shared/order_message_media.dart';
import 'package:motolink_pro_app/features/orders/shared/order_message_attachment.dart';
import 'package:motolink_pro_app/features/orders/shared/order_return_rules.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';
import 'mobile_order_actions_test.dart' show actionsPump;

const presentationReport = ParsedReturnRequest(
    preference: '',
    preferenceLabel: '',
    productName: 'Cadena DID 428 para motocicleta',
    units: 1,
    reason: 'Una unidad llegó con un eslabón dañado.');

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'outgoing mobile report separates the blue heading from readable claim content $dark',
        (tester) async {
      await actionsPump(
          tester,
          Scaffold(
              body: ChatMessageBubble(
                  mine: true,
                  at: DateTime(2026, 11, 23, 10, 45),
                  isAction: true,
                  highlightAction: true,
                  mobileStyle: true,
                  child: OrderPostventaChatCard(
                      data: presentationReport,
                      attachments: const [],
                      outgoing: true,
                      orderReference: '#FA6B6E4C',
                      canDecide: false,
                      busy: false,
                      onResolve: (_, __) async {}))),
          brightness: dark ? Brightness.dark : Brightness.light);
      expect(
          tester
              .widget<Text>(find.text('Reporte del pedido #FA6B6E4C'))
              .style!
              .color,
          Colors.white);
      final productContext =
          tester.element(find.text(presentationReport.productName));
      expect(
          DefaultTextStyle.of(productContext).style.color, isNot(Colors.white));
      expect(find.text('1 unidad afectada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test(
      'cancellation dates use the local calendar and keep older dates explicit',
      () {
    final now = DateTime(2026, 11, 23, 0, 5);
    expect(mobileOrderActionDate(DateTime(2026, 11, 23, 0, 1), now: now),
        'Hoy · 00:01');
    expect(mobileOrderActionDate(DateTime(2026, 11, 22, 23, 59), now: now),
        'Ayer · 23:59');
    expect(mobileOrderActionDate(DateTime(2026, 11, 21, 10, 42), now: now),
        '21/11/2026 · 10:42');
    expect(
        mobileOrderActionDate(DateTime(2026, 11, 22, 23, 59).toUtc(), now: now),
        'Ayer · 23:59');
  });

  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'mobile report has readable context, affected units and explicit decisions $width/$dark',
          (tester) async {
        var calls = 0;
        String? decision;
        await actionsPump(
            tester,
            Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
              padding: const EdgeInsets.all(12),
              child: ChatMessageBubble(
                  mine: false,
                  at: DateTime(2026, 11, 23, 10, 42),
                  isAction: true,
                  highlightAction: true,
                  mobileStyle: true,
                  child: OrderPostventaChatCard(
                      data: presentationReport,
                      attachments: const [],
                      orderReference: '#FA6B6E4C',
                      canDecide: true,
                      busy: false,
                      creditAmount: 34,
                      onResolve: (resolution, _) async {
                        calls++;
                        decision = resolution;
                      })),
            ))),
            width: width,
            scale: 1.6,
            brightness: dark ? Brightness.dark : Brightness.light);
        expect(find.text('Reporte del pedido #FA6B6E4C'), findsOneWidget);
        expect(find.text('1 unidad afectada'), findsOneWidget);
        expect(find.textContaining('Observación del pedido'), findsNothing);
        expect(calls, 0);
        await tester.ensureVisible(find.text('Aprobar cambio de producto'));
        await tester.tap(find.text('Aprobar cambio de producto'));
        await tester.pumpAndSettle();
        expect(calls, 0);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(decision, 'cambio');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('desktop report retains its current title and media mode',
      (tester) async {
    await actionsPump(
        tester,
        Scaffold(
            body: OrderPostventaChatCard(
                data: presentationReport,
                attachments: const [],
                orderReference: '#FA6B6E4C',
                canDecide: false,
                busy: false,
                onResolve: (_, __) async {})),
        width: 1024);
    expect(find.text('Observación del pedido'), findsOneWidget);
    expect(find.text('Reporte del pedido #FA6B6E4C'), findsNothing);
  });

  testWidgets(
      'expanded evidence preserves its width while loading and after a failure',
      (tester) async {
    final result = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 280,
                child: OrderMessageMediaStrip(
                    expanded: true,
                    resolveUrl: (_) => result.future,
                    attachments: const [
                      OrderMessageAttachment(
                          path: 'one/photo.png',
                          kind: 'image',
                          mime: 'image/png',
                          name: 'photo.png')
                    ])))));
    await tester.pump();
    final loading = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching:
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 280));
    expect(tester.getSize(loading.first), const Size(280, 210));
    result.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo mostrar la foto'), findsOneWidget);
    final failed = find
        .ancestor(
            of: find.text('No se pudo mostrar la foto'),
            matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(failed), const Size(280, 210));
    expect(tester.takeException(), isNull);
  });
}

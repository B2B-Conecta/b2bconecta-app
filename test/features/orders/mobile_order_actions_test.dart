import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_cancelar_pedido_dialog.dart';
import 'package:motolink_pro_app/features/orders/aliado/mobile_cancel_order_screen.dart';
import 'package:motolink_pro_app/features/orders/shared/order_issue_report_screen.dart';
import 'package:motolink_pro_app/features/orders/shared/order_message_attachment.dart';
import 'package:motolink_pro_app/features/orders/shared/order_message_pick.dart';
import 'package:motolink_pro_app/features/orders/shared/mobile_postventa_context.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

TransactionRequestModel actionsFixture(
        {String id = 'one',
        bool delivered = false,
        bool cancelled = false,
        bool invoice = false,
        bool reported = false,
        int daysAgo = 1}) =>
    TransactionRequestModel.fromJson({
      'id': id,
      'aliado_id': 'ally',
      'importador_id': 'supplier',
      'product_id': id,
      'checkout_group_id': 'D9B21ABA-checkout',
      'status': cancelled
          ? 'rechazado'
          : delivered
              ? 'entregado'
              : 'en_preparacion',
      'cantidad': 3,
      'precio_unitario_proveedor': 80,
      'precio_unitario_aliado': 80,
      'precio_total_usd': 240,
      'metodo_pago_moneda': 'BOLIVARES',
      'cancelado_por_aliado': cancelled,
      if (cancelled) 'aliado_cancelacion_motivo': 'Me equivoqué de producto.',
      if (cancelled) 'at_rechazado': DateTime.now().toUtc().toIso8601String(),
      if (delivered)
        'at_entregado': DateTime.now()
            .subtract(Duration(days: daysAgo))
            .toUtc()
            .toIso8601String(),
      if (invoice) 'proveedor_factura_storage_path': '$id/factura.pdf',
      if (reported)
        'postventa_devolucion_at': DateTime.now().toUtc().toIso8601String(),
      'products': {
        'name': id == 'one' ? 'Cadena DID 428' : 'Pastillas de freno'
      },
      'importador': {'business_name': 'Repuestos Delta'},
    });

final actionsEvidence = PreparedOrderAttachment(
    bytes: Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8))),
    fileName: 'evidencia.png',
    mime: 'image/png',
    kind: 'image');

Future<void> actionsPump(WidgetTester tester, Widget child,
    {double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.light,
    ThemeData? theme}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  AppColors.brightness = brightness;
  addTearDown(() => AppColors.brightness = Brightness.light);
  await tester.pumpWidget(MaterialApp(
      theme: theme ??
          (brightness == Brightness.dark
              ? buildAppDarkTheme()
              : buildAppTheme()),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: child));
  await tester.pumpAndSettle();
}

Future<void> actionsTap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> reportFill(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(TextField));
  await tester.enterText(find.byType(TextField), 'Una unidad llegó dañada.');
  await actionsTap(tester, 'Agregar foto o video');
  await actionsTap(tester, 'Elegir foto');
}

void main() {
  testWidgets('cancel validates the reason before calling the server',
      (tester) async {
    var calls = 0;
    await actionsPump(
        tester,
        MobileCancelOrderScreen(
            lines: [actionsFixture()],
            loadLines: () async => [actionsFixture()],
            cancelLine: (_, __) async {
              calls++;
            }));
    await actionsTap(tester, 'Confirmar cancelación');
    expect(
        find.text('Escribe el motivo (mínimo 3 caracteres).'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('keeping the order does not cancel or load it', (tester) async {
    var calls = 0;
    await actionsPump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MobileCancelOrderScreen(
                                lines: [actionsFixture()],
                                loadLines: () async {
                                  calls++;
                                  return [actionsFixture()];
                                },
                                cancelLine: (_, __) async {
                                  calls++;
                                }))),
                    child: const Text('Abrir')))));
    await actionsTap(tester, 'Abrir');
    await actionsTap(tester, 'Conservar pedido');
    expect(calls, 0);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('invoice arriving while the form is open blocks cancellation',
      (tester) async {
    var calls = 0;
    await actionsPump(
        tester,
        MobileCancelOrderScreen(
            lines: [actionsFixture()],
            loadLines: () async => [actionsFixture(invoice: true)],
            cancelLine: (_, __) async {
              calls++;
            }));
    await tester.enterText(find.byKey(const ValueKey('cancel-reason')),
        'Me equivoqué de producto.');
    await actionsTap(tester, 'Confirmar cancelación');
    expect(calls, 0);
    expect(find.textContaining('ya adjuntó su factura'), findsWidgets);
    expect(find.text('Cancelación registrada'), findsNothing);
  });

  testWidgets('cancellation blocks double taps and rating remains optional',
      (tester) async {
    final complete = Completer<void>();
    var calls = 0, ratings = 0;
    var cancelled = false;
    await actionsPump(
        tester,
        MobileCancelOrderScreen(
            lines: [actionsFixture()],
            loadLines: () async => [actionsFixture(cancelled: cancelled)],
            cancelLine: (_, reason) async {
              calls++;
              expect(reason, 'Me equivoqué de producto.');
              await complete.future;
              cancelled = true;
            },
            onRate: (_, __, ___) async {
              ratings++;
            }));
    await tester.enterText(find.byKey(const ValueKey('cancel-reason')),
        'Me equivoqué de producto.');
    await tester.tap(find.text('Confirmar cancelación'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Cancelando…'))
            .onPressed,
        isNull);
    complete.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(ratings, 0);
    expect(find.text('Cancelación registrada'), findsOneWidget);
    await actionsTap(tester, 'Valorar el servicio');
    expect(ratings, 1);
  });

  testWidgets('partial cancellation retries only unfinished lines',
      (tester) async {
    final calls = <String>[];
    var firstDone = false, failSecond = true;
    await actionsPump(
        tester,
        MobileCancelOrderScreen(
            lines: [actionsFixture(), actionsFixture(id: 'two')],
            loadLines: () async => [
                  actionsFixture(cancelled: firstDone),
                  actionsFixture(id: 'two')
                ],
            cancelLine: (line, _) async {
              calls.add(line.id);
              if (line.id == 'one') {
                firstDone = true;
              } else if (failSecond) {
                failSecond = false;
                throw TimeoutException('network');
              }
            }));
    await tester.enterText(find.byKey(const ValueKey('cancel-reason')),
        'Me equivoqué de producto.');
    await actionsTap(tester, 'Confirmar cancelación');
    expect(find.textContaining('1 de 2 productos ya fueron cancelados'),
        findsOneWidget);
    await actionsTap(tester, 'Reintentar cancelación');
    expect(calls, ['one', 'two', 'two']);
    expect(find.text('Cancelación registrada'), findsOneWidget);
  });

  testWidgets('desktop cancellation explains an invalid reason',
      (tester) async {
    await actionsPump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showAliadoCancelarPedidoPendienteDialog(context),
                    child: const Text('Abrir')))),
        width: 1024);
    await actionsTap(tester, 'Abrir');
    await actionsTap(tester, 'Confirmar cancelación');
    expect(
        find.text('Escribe el motivo (mínimo 3 caracteres).'), findsOneWidget);
  });

  testWidgets(
      'report requires reason and evidence without submitting automatically',
      (tester) async {
    var calls = 0;
    await actionsPump(
        tester,
        OrderIssueReportScreen(
            lines: [actionsFixture(delivered: true)],
            loadReport: (_) async => null,
            registerReport: (_, __, ___, ____) async {
              calls++;
            }));
    expect(find.text('Vista previa'), findsNothing);
    await actionsTap(tester, 'Enviar reporte');
    expect(find.text('Escriba qué ocurrió antes de enviarlo.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Una unidad llegó dañada.');
    await actionsTap(tester, 'Enviar reporte');
    expect(find.text('Adjunte al menos una foto o un video.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
      'report continues to chat only after the explicit successful submission',
      (tester) async {
    var writes = 0, uploads = 0, chats = 0;
    await actionsPump(
        tester,
        OrderIssueReportScreen(
            lines: [actionsFixture(delivered: true)],
            loadReport: (_) async => null,
            pickEvidence: (_, __) async => actionsEvidence,
            uploadEvidence: (id, _) async {
              uploads++;
              return OrderMessageAttachment(
                  path: '$id/evidence.png',
                  kind: 'image',
                  mime: 'image/png',
                  name: 'evidencia.png');
            },
            registerReport: (_, note, qty, files) async {
              writes++;
              expect(note, 'Una unidad llegó dañada.');
              expect(qty, 1);
              expect(files.length, 1);
            },
            onSubmitted: (context, ids) async {
              chats++;
              expect(writes, 1);
              expect(ids, ['one']);
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const Scaffold(body: Text('Chat de posventa'))));
            }));
    await reportFill(tester);
    expect(writes, 0);
    expect(chats, 0);
    await actionsTap(tester, 'Enviar reporte');
    expect(writes, 1);
    expect(uploads, 1);
    expect(chats, 1);
    expect(find.text('Chat de posventa'), findsOneWidget);
  });

  testWidgets('a chat opening failure never resubmits the recorded report',
      (tester) async {
    var writes = 0, chats = 0;
    await actionsPump(
        tester,
        OrderIssueReportScreen(
            lines: [actionsFixture(delivered: true)],
            loadReport: (_) async => null,
            pickEvidence: (_, __) async => actionsEvidence,
            uploadEvidence: (id, _) async => OrderMessageAttachment(
                path: '$id/evidence.png',
                kind: 'image',
                mime: 'image/png',
                name: 'evidencia.png'),
            registerReport: (_, __, ___, ____) async {
              writes++;
            },
            onSubmitted: (_, __) async {
              chats++;
              throw TimeoutException('offline');
            }));
    await reportFill(tester);
    await actionsTap(tester, 'Enviar reporte');
    expect(find.textContaining('El reporte está registrado'), findsOneWidget);
    await actionsTap(tester, 'Continuar en el chat');
    expect(writes, 1);
    expect(chats, 2);
  });

  testWidgets('a lost report response reconciles the saved evidence on retry',
      (tester) async {
    Map<String, dynamic>? saved;
    var writes = 0, uploads = 0;
    await actionsPump(
        tester,
        OrderIssueReportScreen(
            lines: [actionsFixture(delivered: true)],
            loadReport: (_) async => saved,
            pickEvidence: (_, __) async => actionsEvidence,
            uploadEvidence: (id, _) async {
              uploads++;
              return OrderMessageAttachment(
                  path: '$id/evidence.png',
                  kind: 'image',
                  mime: 'image/png',
                  name: 'evidencia.png');
            },
            registerReport: (_, note, qty, files) async {
              writes++;
              saved = {
                'body': note,
                'affected_qty': qty,
                'evidence': files.map((f) => f.toJson()).toList()
              };
              throw TimeoutException('lost response');
            }));
    await reportFill(tester);
    await actionsTap(tester, 'Enviar reporte');
    await actionsTap(tester, 'Reintentar envío');
    expect(writes, 1);
    expect(uploads, 1);
    expect(find.text('Reporte registrado'), findsOneWidget);
  });

  test(
      'postventa status distinguishes pending, approved, rejected and mixed cases',
      () {
    expect(mobilePostventaStatus([]), 'Reporte registrado');
    expect(
        mobilePostventaStatus([
          {'status': 'abierta'}
        ]),
        'Pendiente de acuerdo');
    expect(
        mobilePostventaStatus([
          {'resolution': 'cambio'}
        ]),
        'Cambio aprobado');
    expect(
        mobilePostventaStatus([
          {'resolution': 'credito'}
        ]),
        'Crédito aprobado');
    expect(
        mobilePostventaStatus([
          {'status': 'rechazada'}
        ]),
        'Reporte no aceptado');
    expect(
        mobilePostventaStatus([
          {'status': 'abierta'},
          {'resolution': 'credito'}
        ]),
        '1 pendiente · 1 resuelto');
  });

  testWidgets(
      'postventa refresh replaces the pending status with the actual agreement',
      (tester) async {
    var approved = false;
    await actionsPump(
        tester,
        Scaffold(
            body: MobilePostventaContext(
                lines: [actionsFixture(delivered: true, reported: true)],
                refreshInterval: const Duration(seconds: 1),
                loadCases: () async => [
                      approved
                          ? {'resolution': 'credito'}
                          : {'status': 'abierta'}
                    ])));
    expect(find.text('Pendiente de acuerdo'), findsOneWidget);
    approved = true;
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Crédito aprobado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'partial report retries only remaining lines and reuses their evidence',
      (tester) async {
    final writes = <String>[];
    var uploads = 0, fail = true;
    await actionsPump(
        tester,
        OrderIssueReportScreen(
            lines: [
              actionsFixture(delivered: true),
              actionsFixture(id: 'two', delivered: true)
            ],
            loadReport: (_) async => null,
            pickEvidence: (_, __) async => actionsEvidence,
            uploadEvidence: (id, _) async {
              uploads++;
              return OrderMessageAttachment(
                  path: '$id/evidence.png',
                  kind: 'image',
                  mime: 'image/png',
                  name: 'evidencia.png');
            },
            registerReport: (id, _, __, ___) async {
              writes.add(id);
              if (id == 'two' && fail) {
                fail = false;
                throw TimeoutException('offline');
              }
            }));
    for (final checkbox in find.byType(Checkbox).evaluate().toList()) {
      await tester.tap(find.byWidget(checkbox.widget));
      await tester.pumpAndSettle();
    }
    await reportFill(tester);
    await actionsTap(tester, 'Enviar reporte');
    expect(find.textContaining('1 de 2 productos ya fueron reportados.'),
        findsOneWidget);
    await actionsTap(tester, 'Reintentar envío');
    expect(writes, ['one', 'two', 'two']);
    expect(uploads, 2);
    expect(find.text('Reporte registrado'), findsOneWidget);
  });

  testWidgets(
      'report enforces three photos or one video before picking more files',
      (tester) async {
    var picks = 0;
    await actionsPump(
        tester,
        OrderIssueReportScreen(
            lines: [actionsFixture(delivered: true)],
            pickEvidence: (_, __) async {
              picks++;
              return actionsEvidence;
            }));
    await reportFill(tester);
    for (var i = 0; i < 2; i++) {
      await actionsTap(tester, 'Agregar foto o video');
      await actionsTap(tester, 'Elegir foto');
    }
    expect(picks, 3);
    expect(find.text('Agregar foto o video'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Quitar evidencia 1'));
    await tester.tap(find.byTooltip('Quitar evidencia 1'));
    await tester.pumpAndSettle();
    await actionsTap(tester, 'Agregar foto o video');
    await actionsTap(tester, 'Elegir video');
    expect(picks, 3);
    expect(
        find.text('Quite las fotos si va a enviar un video.'), findsOneWidget);
  });

  testWidgets(
      'unknown postventa status shows a retry without inventing an agreement',
      (tester) async {
    var fail = true;
    await actionsPump(
        tester,
        Scaffold(
            body: MobilePostventaContext(
                lines: [actionsFixture(reported: true)],
                refreshInterval: null,
                loadCases: () async {
                  if (fail) throw TimeoutException('offline');
                  return [
                    {'resolution': 'cambio'}
                  ];
                })));
    expect(find.text('Estado sin actualizar'), findsOneWidget);
    expect(find.text('Cambio aprobado'), findsNothing);
    fail = false;
    await actionsTap(tester, 'Actualizar');
    expect(find.text('Cambio aprobado'), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'mobile actions support narrow screens with enlarged text $width',
        (tester) async {
      await actionsPump(
          tester,
          MobileCancelOrderScreen(
              lines: [actionsFixture()],
              loadLines: () async => [actionsFixture()],
              cancelLine: (_, __) async {}),
          width: width,
          scale: 1.6,
          brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      await actionsPump(tester,
          OrderIssueReportScreen(lines: [actionsFixture(delivered: true)]),
          width: width, scale: 1.6, brightness: Brightness.dark);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

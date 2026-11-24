import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/chat_conversation_widgets.dart';
import 'package:motolink_pro_app/features/support/mobile_create_support_ticket_screen.dart';
import 'package:motolink_pro_app/features/support/mobile_support_widgets.dart';
import 'package:motolink_pro_app/features/support/support_tickets_screen.dart';
import 'package:motolink_pro_app/features/support/support_ticket_detail_screen.dart';

const createdSupportId = 'abcd1234-5678-1234-5678-123456789abc';
const linkedSupportOrder = '12345678-1234-1234-1234-123456789abc';
const supportSubject = 'No puedo adjuntar mi comprobante';
const supportBody =
    'Intento adjuntar el comprobante, pero la carga no termina.';

class SupportFixture {
  int creates = 0;
  bool failFetch = false,
      failCreate = false,
      rejectLimit = false,
      atLimit = false,
      failList = false;
  Completer<void>? holdCreate;
  Map<String, dynamic>? lastCreate;
  final tickets = <Map<String, dynamic>>[];

  void reset() {
    creates = 0;
    failFetch = failCreate = rejectLimit = atLimit = failList = false;
    holdCreate = null;
    lastCreate = null;
    tickets
      ..clear()
      ..addAll([
        row('11111111-1111-1111-1111-111111111111', 'abierto', supportSubject),
        row('22222222-2222-2222-2222-222222222222', 'en_revision',
            'Consulta de verificación'),
        row('33333333-3333-3333-3333-333333333333', 'cerrado',
            'Actualizar teléfono'),
      ]);
  }

  Map<String, dynamic> row(String id, String status, String subject,
          {String? related}) =>
      {
        'id': id,
        'created_by': 'owner',
        'author_role': 'aliado',
        'subject': subject,
        'category': 'pago',
        'status': status,
        'created_at': '2026-11-06T10:00:00Z',
        if (related != null) 'related_transaction_request_id': related,
      };

  Future<http.Response> respond(http.Request request) async {
    dynamic body;
    var status = 200;
    final path = request.url.path;
    if (path.endsWith('/token')) {
      body = {
        'access_token': 'fixture-token',
        'refresh_token': 'fixture-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'owner',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-11-04T00:00:00Z'
        }
      };
    } else if (path.endsWith('/create_support_ticket')) {
      creates++;
      lastCreate = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      if (holdCreate != null) await holdCreate!.future;
      if (failCreate || rejectLimit) {
        status = 400;
        body = {
          'code': 'P0001',
          'message': rejectLimit
              ? 'Ya tiene 3 reclamos abiertos. Cierre uno antes de abrir otro.'
              : 'Internal detail that must not be shown'
        };
      } else {
        final ticket = row(
            createdSupportId, 'abierto', lastCreate!['p_subject'] as String,
            related:
                lastCreate!['p_related_transaction_request_id'] as String?);
        ticket['category'] = lastCreate!['p_category'];
        tickets.insert(0, ticket);
        body = createdSupportId;
      }
    } else if (path.endsWith('/support_tickets')) {
      final id = request.url.queryParameters['id']?.replaceFirst('eq.', '');
      if (id != null) {
        body = failFetch
            ? null
            : tickets.where((row) => row['id'] == id).firstOrNull;
      } else if (failList) {
        status = 400;
        body = {'code': 'P0001', 'message': 'Internal list detail'};
      } else if (request.url.queryParameters['select'] == 'id') {
        body = tickets
            .where((row) => row['status'] != 'cerrado')
            .map((row) => {'id': row['id']})
            .toList();
        if (atLimit) (body as List).add({'id': 'another-open'});
      } else {
        body = tickets;
      }
    } else if (path.endsWith('/support_ticket_messages')) {
      body = [
        {
          'id': 'mine',
          'ticket_id': createdSupportId,
          'author_id': 'owner',
          'author_role': 'aliado',
          'body': supportBody,
          'created_at': '2026-11-06T10:24:00Z'
        },
        {
          'id': 'support',
          'ticket_id': createdSupportId,
          'author_id': 'admin',
          'author_role': 'administrador',
          'body': 'Estamos revisando tu consulta.',
          'created_at': '2026-11-06T10:28:00Z'
        },
      ];
    }
    return http.Response(jsonEncode(body), status,
        request: request, headers: {'content-type': 'application/json'});
  }
}

final supportFixture = SupportFixture();

Future<void> initializeSupportFixture() async {
  SharedPreferences.setMockInitialValues({});
  supportFixture.reset();
  await Supabase.initialize(
      url: 'https://fixture.supabase.co',
      anonKey: 'fixture',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false, autoRefreshToken: false),
      httpClient: MockClient(supportFixture.respond));
  await Supabase.instance.client.auth
      .signInWithPassword(email: 'fixture@example.test', password: 'fixture');
}

Future<void> pumpSupport(WidgetTester tester,
    {double width = 390,
    double height = 844,
    double scale = 1,
    bool dark = false,
    bool linked = false}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? buildAppDarkTheme() : buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: SupportTicketsScreen(
          relatedTransactionRequestId: linked ? linkedSupportOrder : null)));
  await tester.pumpAndSettle();
}

Future<void> openSupportForm(WidgetTester tester) async {
  await tester.tap(supportFilledButton('Nuevo reclamo'));
  await tester.pumpAndSettle();
}

Future<void> revealSupportList(WidgetTester tester, Finder item,
    {double delta = 120}) async {
  await tester.scrollUntilVisible(item, delta,
      scrollable: find
          .descendant(
              of: find.byType(SupportTicketsScreen),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(item), alignment: .3);
  await tester.pumpAndSettle();
}

Finder supportFilledButton(String label) => find
    .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton))
    .first;

Future<void> fillSupportForm(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('support-subject')), supportSubject);
  await tester.enterText(
      find.byKey(const ValueKey('support-body')), supportBody);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeSupportFixture);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(supportFixture.reset);

  test(
      'support references derive from the real identifier and hide technical errors',
      () {
    expect(supportReference(createdSupportId), '#SOP-ABCD1234');
    expect(supportFailureMessage(StateError('private details')),
        isNot(contains('private details')));
  });

  for (final config in [
    (320.0, 1.0, false),
    (390.0, 1.6, false),
    (390.0, 1.0, true)
  ]) {
    testWidgets('list filters and form remain usable at $config',
        (tester) async {
      await pumpSupport(tester,
          width: config.$1, scale: config.$2, dark: config.$3);
      expect(find.text('Abiertos: 2 de 3'), findsOneWidget);
      await revealSupportList(
          tester, find.widgetWithText(ChoiceChip, 'Abiertos'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Abiertos'));
      await tester.pumpAndSettle();
      await revealSupportList(tester, find.text('Consulta de verificación'));
      expect(find.text('Consulta de verificación'), findsOneWidget);
      expect(find.text('Actualizar teléfono'), findsNothing);
      await revealSupportList(
          tester, find.widgetWithText(ChoiceChip, 'Cerrados'),
          delta: -120);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cerrados'));
      await tester.pumpAndSettle();
      await revealSupportList(tester, find.text('Actualizar teléfono'));
      expect(find.text('Actualizar teléfono'), findsOneWidget);
      expect(find.text(supportSubject), findsNothing);
      await openSupportForm(tester);
      expect(find.byType(MobileCreateSupportTicketScreen), findsOneWidget);
      await fillSupportForm(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('open limit includes tickets being reviewed', (tester) async {
    supportFixture.atLimit = true;
    await pumpSupport(tester);
    expect(find.text('Abiertos: 3 de 3'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(supportFilledButton('Nuevo reclamo'))
            .onPressed,
        isNull);
  });

  testWidgets('validation prevents empty and whitespace-only submissions',
      (tester) async {
    await pumpSupport(tester);
    await openSupportForm(tester);
    await tester.tap(find.text('Enviar reclamo'));
    await tester.pumpAndSettle();
    expect(find.text('El asunto debe tener al menos 3 caracteres.'),
        findsOneWidget);
    expect(find.text('La descripción debe tener al menos 3 caracteres.'),
        findsOneWidget);
    expect(supportFixture.creates, 0);
  });

  testWidgets(
      'created claim opens its conversation and preserves the linked order',
      (tester) async {
    await pumpSupport(tester, linked: true);
    await openSupportForm(tester);
    await fillSupportForm(tester);
    await tester.tap(find.text('Enviar reclamo'));
    await tester.pumpAndSettle();
    expect(supportFixture.creates, 1);
    expect(supportFixture.lastCreate!['p_related_transaction_request_id'],
        linkedSupportOrder);
    expect(find.byType(SupportTicketDetailScreen), findsOneWidget);
    expect(find.text('#SOP-ABCD1234'), findsOneWidget);
    final outgoing = tester.widget<ChatMessageBubble>(find.ancestor(
        of: find.text(supportBody), matching: find.byType(ChatMessageBubble)));
    expect(outgoing.mine, isTrue);
    expect(outgoing.mobileStyle, isTrue);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text('Resolver'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry after claim creation only opens the existing conversation',
      (tester) async {
    await pumpSupport(tester);
    await openSupportForm(tester);
    await fillSupportForm(tester);
    supportFixture.failFetch = true;
    await tester.tap(find.text('Enviar reclamo'));
    await tester.pumpAndSettle();
    expect(supportFixture.creates, 1);
    expect(find.textContaining('Tu reclamo ya se registró.'), findsOneWidget);
    supportFixture.failFetch = false;
    await tester.tap(supportFilledButton('Abrir conversación'));
    await tester.pumpAndSettle();
    expect(supportFixture.creates, 1);
    expect(find.byType(SupportTicketDetailScreen), findsOneWidget);
  });

  testWidgets('failed creation preserves draft and uses a readable error',
      (tester) async {
    await pumpSupport(tester);
    await openSupportForm(tester);
    await fillSupportForm(tester);
    supportFixture.failCreate = true;
    await tester.tap(find.text('Enviar reclamo'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('support-subject')))
            .controller!
            .text,
        supportSubject);
    expect(
        find.textContaining('Conservamos lo que escribiste'), findsOneWidget);
    expect(find.textContaining('Internal detail'), findsNothing);
  });

  testWidgets(
      'a limit reached during creation gives guidance and blocks resubmission',
      (tester) async {
    await pumpSupport(tester);
    await openSupportForm(tester);
    await fillSupportForm(tester);
    supportFixture.rejectLimit = true;
    await tester.tap(find.text('Enviar reclamo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ya tienes tres reclamos abiertos.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(supportFilledButton('Enviar reclamo'))
            .onPressed,
        isNull);
  });

  testWidgets('sending blocks duplicate submissions and navigation',
      (tester) async {
    await pumpSupport(tester);
    await openSupportForm(tester);
    await fillSupportForm(tester);
    final hold = Completer<void>();
    supportFixture.holdCreate = hold;
    await tester.tap(find.text('Enviar reclamo'));
    await tester.pump();
    await tester.tap(supportFilledButton('Un momento…'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(MobileCreateSupportTicketScreen), findsOneWidget);
    expect(supportFixture.creates, 1);
    hold.complete();
    await tester.pumpAndSettle();
    expect(supportFixture.creates, 1);
    expect(find.byType(SupportTicketDetailScreen), findsOneWidget);
  });

  testWidgets('canceling a draft requires confirmation', (tester) async {
    await pumpSupport(tester);
    await openSupportForm(tester);
    await fillSupportForm(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar el reclamo?'), findsOneWidget);
    await tester.tap(find.text('Seguir escribiendo'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileCreateSupportTicketScreen), findsOneWidget);
    expect(supportFixture.creates, 0);
  });

  for (final config in [(320.0, 844.0, 1.6), (568.0, 320.0, 1.0)]) {
    testWidgets('support context expands without hiding composer at $config',
        (tester) async {
      await pumpSupport(tester,
          width: config.$1, height: config.$2, scale: config.$3);
      await revealSupportList(tester, find.text(supportSubject));
      await tester.tap(find.text(supportSubject));
      await tester.pumpAndSettle();
      final details = find.text('Ver datos del reclamo');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Identificador completo'), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      if (config.$2 > 320) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.getBottomLeft(find.byType(ChatComposer)).dy,
            closeTo(config.$2 - 280, 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('list failure offers retry without allowing a duplicate action',
      (tester) async {
    supportFixture.failList = true;
    await pumpSupport(tester);
    expect(find.text('No pudimos cargar tus reclamos'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(supportFilledButton('Nuevo reclamo'))
            .onPressed,
        isNull);
    supportFixture.failList = false;
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Abiertos: 2 de 3'), findsOneWidget);
  });

  testWidgets('desktop keeps its original list and bottom-sheet creation',
      (tester) async {
    await pumpSupport(tester, width: 1440);
    expect(find.text('Reclamos activos'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(supportFilledButton('Abrir reclamo'));
    await tester.pumpAndSettle();
    expect(find.byType(MobileCreateSupportTicketScreen), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}

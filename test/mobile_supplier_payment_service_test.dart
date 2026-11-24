import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/payments/payments_service.dart';
import 'package:motolink_pro_app/features/payments/mobile_supplier_payment_model.dart';
import 'mobile_supplier_payment_test.dart' show paymentFixture, paymentProof;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var submitted = false, timeout = false, missingColumn = false;
  const submission = '00000000-0000-4000-8000-000000000001';
  final declaration = SupplierPaymentDeclaration(
      submissionId: submission,
      method: 'pago_movil',
      reference: '000123',
      paidOn: DateTime(2026, 11, 20),
      amount: 5000,
      currency: 'BS');
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://fixture.supabase.co',
        anonKey: 'fixture',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
            detectSessionInUri: false, autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          dynamic body;
          var status = 200;
          if (request.url.path.endsWith('/token')) {
            body = {
              'access_token': 'fixture',
              'refresh_token': 'fixture',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'ally',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-11-01T00:00:00Z'
              }
            };
          } else if (request.url.path.endsWith('/transaction_requests')) {
            if (missingColumn &&
                (request.url.queryParameters['select'] ?? '')
                    .contains('pago_declaracion,')) {
              status = 400;
              body = {
                'code': '42703',
                'message':
                    'column transaction_requests.pago_declaracion does not exist'
              };
            } else {
              body = {
                'id': 'one',
                'pago_declaracion':
                    submitted ? {'submission_id': submission} : {},
                'aliado_id': 'ally',
                'importador_id': 'supplier',
                'product_id': 'p',
                'status': 'pendiente',
                'cantidad': 5,
                'precio_total_usd': 450
              };
            }
          } else if (request.url.path
              .endsWith('/aliado_submit_supplier_payment_v1')) {
            submitted = true;
            if (timeout) throw TimeoutException('response lost');
            body = null;
          } else {
            body = {'Key': 'proof'};
          }
          return http.Response(jsonEncode(body), status,
              headers: {'content-type': 'application/json'}, request: request);
        }));
    await Supabase.instance.client.auth
        .signInWithPassword(email: 'qa@example.test', password: 'fixture');
  });
  setUp(() {
    requests.clear();
    submitted = false;
    timeout = false;
    missingColumn = false;
  });
  tearDownAll(() => Supabase.instance.dispose());
  test(
      'a supplier bundle uploads once and commits one RPC without deleting existing proofs',
      () async {
    await PaymentsService.submitMobileSupplierPayment(
        lines: [paymentFixture(), paymentFixture(id: 'two')],
        declaration: declaration,
        proof: paymentProof);
    final rpc = requests.where((r) => r.url.path.contains('/rpc/')).single;
    final payload = jsonDecode(rpc.body) as Map;
    expect(payload['p_request_ids'], ['one', 'two']);
    expect(payload['p_declaration']['reference'], '000123');
    expect(payload['p_storage_path'], 'one/payment_$submission.png');
    expect(
        requests.where((r) => r.url.path.contains('/storage/')), hasLength(1));
    expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
  });
  test(
      'ambiguous response preserves the uploaded proof and retry does not overwrite it',
      () async {
    timeout = true;
    await expectLater(
        PaymentsService.submitMobileSupplierPayment(
            lines: [paymentFixture()],
            declaration: declaration,
            proof: paymentProof),
        throwsA(isA<TimeoutException>()));
    timeout = false;
    await PaymentsService.submitMobileSupplierPayment(
        lines: [paymentFixture()],
        declaration: declaration,
        proof: paymentProof);
    expect(
        requests.where((r) => r.url.path.contains('/storage/')), hasLength(1));
    expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
  });
  test('cash declaration performs no storage upload', () async {
    await PaymentsService.submitMobileSupplierPayment(
        lines: [paymentFixture(currency: 'DIVISAS')],
        declaration: SupplierPaymentDeclaration(
            submissionId: submission,
            method: 'efectivo',
            reference: '',
            paidOn: DateTime(2026, 11, 20),
            amount: 450,
            currency: 'USD'));
    expect(requests.where((r) => r.url.path.contains('/storage/')), isEmpty);
    expect(jsonDecode(requests.single.body)['p_storage_path'], isNull);
  });
  test('old schema keeps the existing order detail readable', () async {
    missingColumn = true;
    final line = await OrdersService.fetchTransactionRequestById('one');
    expect(line!.id, 'one');
    expect(line.pagoDeclaracion, isEmpty);
    expect(requests, hasLength(2));
  });
}

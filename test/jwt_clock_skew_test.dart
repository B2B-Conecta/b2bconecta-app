import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/core/data/jwt_clock_skew.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isJwtIssuedAtFutureError', () {
    test('detecta PGRST303 y el mensaje de iat', () {
      expect(
        isJwtIssuedAtFutureError(
          const PostgrestException(
            message: 'JWT issued at future',
            code: 'PGRST303',
          ),
        ),
        isTrue,
      );
      expect(
        isJwtIssuedAtFutureError(
          const PostgrestException(
            message:
                '{"code":"PGRST303","details":null,"hint":null,"message":"JWT issued at future"}',
            code: '401',
          ),
        ),
        isTrue,
      );
      expect(
        isJwtIssuedAtFutureError(Exception('row not found')),
        isFalse,
      );
    });
  });

  group('retryOnJwtIssuedAtFuture', () {
    test('devuelve el primer éxito sin esperar', () async {
      var waits = 0;
      final result = await retryOnJwtIssuedAtFuture(
        () async => 7,
        wait: (_) async {
          waits++;
        },
      );
      expect(result, 7);
      expect(waits, 0);
    });

    test('reintenta el mismo token tras PGRST303 y luego acierta', () async {
      var attempts = 0;
      final waits = <Duration>[];
      final result = await retryOnJwtIssuedAtFuture(
        () async {
          attempts++;
          if (attempts == 1) {
            throw const PostgrestException(
              message: 'JWT issued at future',
              code: 'PGRST303',
            );
          }
          return 'ok';
        },
        wait: (d) async => waits.add(d),
      );
      expect(result, 'ok');
      expect(attempts, 2);
      expect(waits, [kJwtIssuedAtFutureRetryDelays.first]);
    });

    test('no reintenta otros errores', () async {
      await expectLater(
        retryOnJwtIssuedAtFuture(
          () async => throw Exception('network'),
          wait: (_) async {},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

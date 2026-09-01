import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:motolink_pro_app/features/commissions/bcv_reference_rate_service.dart';

void main() {
  group('quoteFromMap', () {
    test('lee USD y fecha valor', () {
      final q = BcvReferenceRateService.quoteFromMap({
        'USD': 794.9917,
        'effective_date': '2026-08-31',
        'date': '2026-08-31',
        'updated_at': '2026-08-29T01:23:59.320337+00:00',
      });
      expect(q, isNotNull);
      expect(q!.vesPerUsd, 794.9917);
      expect(q.effectiveDate, '2026-08-31');
    });

    test('usa date si no hay effective_date', () {
      final q = BcvReferenceRateService.quoteFromMap({
        'USD': 798.326,
        'date': '2026-09-01',
      });
      expect(q!.effectiveDate, '2026-09-01');
    });

    test('rechaza USD inválido', () {
      expect(BcvReferenceRateService.quoteFromMap({'USD': 0}), isNull);
      expect(BcvReferenceRateService.quoteFromMap({}), isNull);
    });
  });

  group('pickLatestPublished', () {
    test('elige el boletín de fecha valor más reciente (portada BCV)', () {
      final today = BcvReferenceRateService.quoteFromMap({
        'USD': 794.9917,
        'effective_date': '2026-08-31',
      })!;
      final next = BcvReferenceRateService.quoteFromMap({
        'USD': 798.326,
        'effective_date': '2026-09-01',
      })!;
      final picked = BcvReferenceRateService.pickLatestPublished([today, next]);
      expect(picked!.vesPerUsd, 798.326);
      expect(picked.effectiveDate, '2026-09-01');
    });
  });

  test('historyDatesToProbe cubre hoy y 3 días', () {
    final dates = BcvReferenceRateService.historyDatesToProbe(
      DateTime(2026, 8, 31, 22),
    );
    expect(dates, [
      '2026-08-31',
      '2026-09-01',
      '2026-09-02',
      '2026-09-03',
    ]);
  });

  test('formatFechaValorEs', () {
    expect(
      BcvReferenceRateService.formatFechaValorEs('2026-09-01'),
      '01/09/2026',
    );
  });

  test('fetchPublicBcvUsdRate usa el histórico más reciente, no solo rate.json',
      () async {
    final quote = await BcvReferenceRateService.fetchPublicBcvUsdRate(
      utcNow: DateTime.utc(2026, 8, 31, 22),
      get: (uri) async {
        final path = uri.path;
        if (path.endsWith('/rate.json')) {
          return http.Response(
            '{"USD":794.9917,"effective_date":"2026-08-31","date":"2026-08-31"}',
            200,
          );
        }
        if (path.endsWith('/2026-09-01.json')) {
          return http.Response(
            '{"USD":798.326,"effective_date":"2026-09-01","date":"2026-09-01"}',
            200,
          );
        }
        return http.Response('{}', 404);
      },
    );
    expect(quote, isNotNull);
    expect(quote!.vesPerUsd, 798.326);
    expect(quote.effectiveDate, '2026-09-01');
  });
}

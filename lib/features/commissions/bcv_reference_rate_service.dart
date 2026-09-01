import 'dart:convert';

import 'package:http/http.dart' as http;

/// Referencia de tasa BCV USD (VES por 1 USD ≈ VES por 1 REF en B2B Conecta).
class BcvReferenceQuote {
  const BcvReferenceQuote({
    required this.vesPerUsd,
    this.effectiveDate,
    this.updatedAt,
    required this.sourceLabel,
  });

  final double vesPerUsd;
  final String? effectiveDate;
  final String? updatedAt;
  final String sourceLabel;
}

/// Consulta tasas BCV públicas. [Al Cambio](https://alcambio.app/) no expone API;
/// usamos el espejo [bcv.today](https://bcv.today/) (misma tasa BCV).
///
/// El BCV publica ~16:30 (Caracas) con **fecha valor = siguiente día hábil**.
/// `rate.json` es la tasa vigente hoy; bcv.org.ve muestra el boletín ya
/// publicado (puede ser mañana). Tomamos el de fecha valor más reciente.
class BcvReferenceRateService {
  BcvReferenceRateService._();

  static const String alcambioUrl = 'https://alcambio.app/';
  static const String bcvOfficialUrl = 'https://www.bcv.org.ve/';

  static const _bcvTodayRateUrl = 'https://bcv.today/api/v1/rate.json';
  static const _historyByDatePrefix = 'https://bcv.today/api/v1/history/';

  static const rateEpsilon = 0.00005;

  /// Caracas es UTC−4 todo el año.
  static DateTime caracasWallClock([DateTime? utcNow]) {
    final utc = (utcNow ?? DateTime.now()).toUtc();
    return utc.subtract(const Duration(hours: 4));
  }

  /// Hoy (Caracas) y los 3 días siguientes: boletín de la tarde y viernes→lunes.
  static List<String> historyDatesToProbe(DateTime caracasNow) {
    final start = DateTime(caracasNow.year, caracasNow.month, caracasNow.day);
    return List<String>.generate(4, (i) {
      final d = start.add(Duration(days: i));
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    });
  }

  static BcvReferenceQuote? quoteFromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final usd = data['USD'];
    if (usd is! num || usd <= 0) return null;
    final effective = data['effective_date']?.toString().trim();
    final date = data['date']?.toString().trim();
    return BcvReferenceQuote(
      vesPerUsd: usd.toDouble(),
      effectiveDate: (effective != null && effective.isNotEmpty)
          ? effective
          : (date != null && date.isNotEmpty ? date : null),
      updatedAt: data['updated_at']?.toString(),
      sourceLabel: 'bcv.today (BCV oficial)',
    );
  }

  /// Elige el boletín con fecha valor más reciente (portada BCV).
  static BcvReferenceQuote? pickLatestPublished(
    Iterable<BcvReferenceQuote> quotes,
  ) {
    BcvReferenceQuote? best;
    DateTime? bestDate;
    for (final q in quotes) {
      final raw = q.effectiveDate?.trim();
      final parsed = raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
      if (parsed == null) {
        best ??= q;
        continue;
      }
      if (bestDate == null || parsed.isAfter(bestDate)) {
        best = q;
        bestDate = parsed;
      }
    }
    return best;
  }

  static bool ratesDiffer(double a, double b) => (a - b).abs() > rateEpsilon;

  static String? formatFechaValorEs(String? isoDate) {
    final raw = isoDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final day = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$day/$m/${d.year}';
  }

  /// Tasa USD BCV publicada (VES por 1 USD). Null si la red falla.
  static Future<BcvReferenceQuote?> fetchPublicBcvUsdRate({
    Future<http.Response> Function(Uri uri)? get,
    DateTime? utcNow,
  }) async {
    final doGet = get ??
        (Uri uri) => http.get(uri).timeout(const Duration(seconds: 12));

    Future<BcvReferenceQuote?> fetchUri(String url) async {
      try {
        final res = await doGet(Uri.parse(url));
        if (res.statusCode != 200) return null;
        final decoded = jsonDecode(res.body);
        if (decoded is! Map) return null;
        return quoteFromMap(Map<String, dynamic>.from(decoded));
      } catch (_) {
        return null;
      }
    }

    final dates = historyDatesToProbe(caracasWallClock(utcNow));
    final fetched = await Future.wait<BcvReferenceQuote?>([
      fetchUri(_bcvTodayRateUrl),
      ...dates.map((d) => fetchUri('$_historyByDatePrefix$d.json')),
    ]);
    return pickLatestPublished(fetched.whereType<BcvReferenceQuote>());
  }
}

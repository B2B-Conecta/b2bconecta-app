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
/// usamos el espejo oficial [bcv.today](https://bcv.today/) (misma tasa BCV).
class BcvReferenceRateService {
  BcvReferenceRateService._();

  static const String alcambioUrl = 'https://alcambio.app/';
  static const String bcvOfficialUrl = 'https://www.bcv.org.ve/';

  static const _bcvTodayRateUrl = 'https://bcv.today/api/v1/rate.json';

  /// Tasa USD BCV (VES por 1 USD). Null si la red falla o el JSON no es válido.
  static Future<BcvReferenceQuote?> fetchPublicBcvUsdRate() async {
    try {
      final res = await http
          .get(Uri.parse(_bcvTodayRateUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;
      final usd = data['USD'];
      if (usd is! num || usd <= 0) return null;
      return BcvReferenceQuote(
        vesPerUsd: usd.toDouble(),
        effectiveDate: data['effective_date']?.toString(),
        updatedAt: data['updated_at']?.toString(),
        sourceLabel: 'bcv.today (BCV oficial)',
      );
    } catch (_) {
      return null;
    }
  }
}

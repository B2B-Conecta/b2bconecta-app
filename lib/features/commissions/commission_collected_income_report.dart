import 'commission_settlement_document_type.dart';

/// Resultado agregado de comisión cobrada (RPC motoconecta_collected_commission_report).
class CommissionCollectedIncomeReport {
  const CommissionCollectedIncomeReport({
    required this.timezone,
    required this.from,
    required this.to,
    required this.grain,
    required this.totalCollectedUsd,
    required this.operationCount,
    required this.settlementCount,
    this.importadorId,
    this.documentType,
    this.previous,
    this.variationPct,
    this.series = const [],
    this.byImportador = const [],
    this.byDocumentType = const [],
    this.settlements = const [],
  });

  final String timezone;
  final DateTime from;
  final DateTime to;
  final String grain;
  final double totalCollectedUsd;
  final int operationCount;
  final int settlementCount;
  final String? importadorId;
  final String? documentType;
  final CommissionCollectedIncomeTotals? previous;
  final double? variationPct;
  final List<CommissionCollectedIncomeBucket> series;
  final List<CommissionCollectedIncomeImporterRow> byImportador;
  final List<CommissionCollectedIncomeDocumentRow> byDocumentType;
  final List<CommissionCollectedIncomeSettlementRow> settlements;

  bool get isEmpty => operationCount <= 0 || totalCollectedUsd <= 0;

  bool get canShowVariation =>
      variationPct != null &&
      previous != null &&
      previous!.totalCollectedUsd > 0;

  /// Total y series deben coincidir a 4 decimales (misma fuente SQL).
  bool get seriesMatchesTotal {
    final sum = series.fold<double>(0, (a, b) => a + b.totalCollectedUsd);
    return _usd4(sum) == _usd4(totalCollectedUsd);
  }

  bool get importadorBreakdownMatchesTotal {
    if (byImportador.isEmpty) return true;
    final sum = byImportador.fold<double>(0, (a, b) => a + b.totalCollectedUsd);
    return _usd4(sum) == _usd4(totalCollectedUsd);
  }

  bool get documentBreakdownMatchesTotal {
    if (byDocumentType.isEmpty) return true;
    final sum =
        byDocumentType.fold<double>(0, (a, b) => a + b.totalCollectedUsd);
    return _usd4(sum) == _usd4(totalCollectedUsd);
  }

  factory CommissionCollectedIncomeReport.fromJson(Map<String, dynamic> json) {
    final prev = json['previous'];
    return CommissionCollectedIncomeReport(
      timezone: json['timezone']?.toString() ?? 'America/Caracas',
      from: _asDate(json['from']),
      to: _asDate(json['to']),
      grain: json['grain']?.toString() ?? 'day',
      totalCollectedUsd: _asDouble(json['total_collected_usd']),
      operationCount: _asInt(json['operation_count']),
      settlementCount: _asInt(json['settlement_count']),
      importadorId: json['importador_id']?.toString(),
      documentType: json['document_type']?.toString(),
      previous: prev is Map
          ? CommissionCollectedIncomeTotals.fromJson(
              Map<String, dynamic>.from(prev),
            )
          : null,
      variationPct: json['variation_pct'] == null
          ? null
          : _asDouble(json['variation_pct']),
      series: _mapList(json['series'], CommissionCollectedIncomeBucket.fromJson),
      byImportador: _mapList(
        json['by_importador'],
        CommissionCollectedIncomeImporterRow.fromJson,
      ),
      byDocumentType: _mapList(
        json['by_document_type'],
        CommissionCollectedIncomeDocumentRow.fromJson,
      ),
      settlements: _mapList(
        json['settlements'],
        CommissionCollectedIncomeSettlementRow.fromJson,
      ),
    );
  }

  static int _usd4(double v) => (v * 10000).round();
}

class CommissionCollectedIncomeTotals {
  const CommissionCollectedIncomeTotals({
    required this.from,
    required this.to,
    required this.totalCollectedUsd,
    required this.operationCount,
    required this.settlementCount,
  });

  final DateTime from;
  final DateTime to;
  final double totalCollectedUsd;
  final int operationCount;
  final int settlementCount;

  factory CommissionCollectedIncomeTotals.fromJson(Map<String, dynamic> json) {
    return CommissionCollectedIncomeTotals(
      from: _asDate(json['from']),
      to: _asDate(json['to']),
      totalCollectedUsd: _asDouble(json['total_collected_usd']),
      operationCount: _asInt(json['operation_count']),
      settlementCount: _asInt(json['settlement_count']),
    );
  }
}

class CommissionCollectedIncomeBucket {
  const CommissionCollectedIncomeBucket({
    required this.bucket,
    required this.totalCollectedUsd,
    required this.operationCount,
    required this.settlementCount,
  });

  final DateTime bucket;
  final double totalCollectedUsd;
  final int operationCount;
  final int settlementCount;

  factory CommissionCollectedIncomeBucket.fromJson(Map<String, dynamic> json) {
    return CommissionCollectedIncomeBucket(
      bucket: _asDate(json['bucket']),
      totalCollectedUsd: _asDouble(json['total_collected_usd']),
      operationCount: _asInt(json['operation_count']),
      settlementCount: _asInt(json['settlement_count']),
    );
  }
}

class CommissionCollectedIncomeImporterRow {
  const CommissionCollectedIncomeImporterRow({
    required this.importadorId,
    required this.businessName,
    required this.totalCollectedUsd,
    required this.operationCount,
    required this.settlementCount,
  });

  final String importadorId;
  final String businessName;
  final double totalCollectedUsd;
  final int operationCount;
  final int settlementCount;

  factory CommissionCollectedIncomeImporterRow.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommissionCollectedIncomeImporterRow(
      importadorId: json['importador_id']?.toString() ?? '',
      businessName: (json['business_name']?.toString().trim().isNotEmpty == true)
          ? json['business_name'].toString().trim()
          : 'Importador',
      totalCollectedUsd: _asDouble(json['total_collected_usd']),
      operationCount: _asInt(json['operation_count']),
      settlementCount: _asInt(json['settlement_count']),
    );
  }
}

class CommissionCollectedIncomeDocumentRow {
  const CommissionCollectedIncomeDocumentRow({
    required this.documentType,
    required this.totalCollectedUsd,
    required this.operationCount,
    required this.settlementCount,
  });

  final String documentType;
  final double totalCollectedUsd;
  final int operationCount;
  final int settlementCount;

  String get labelEs =>
      CommissionSettlementDocumentType.effective(documentType).labelEs;

  factory CommissionCollectedIncomeDocumentRow.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommissionCollectedIncomeDocumentRow(
      documentType: json['document_type']?.toString() ?? 'fiscal_invoice',
      totalCollectedUsd: _asDouble(json['total_collected_usd']),
      operationCount: _asInt(json['operation_count']),
      settlementCount: _asInt(json['settlement_count']),
    );
  }
}

class CommissionCollectedIncomeSettlementRow {
  const CommissionCollectedIncomeSettlementRow({
    required this.settlementId,
    required this.importadorId,
    required this.businessName,
    required this.documentType,
    required this.totalCollectedUsd,
    required this.operationCount,
    this.invoiceReference,
    this.paidAt,
  });

  final String settlementId;
  final String? invoiceReference;
  final String importadorId;
  final String businessName;
  final String documentType;
  final DateTime? paidAt;
  final double totalCollectedUsd;
  final int operationCount;

  factory CommissionCollectedIncomeSettlementRow.fromJson(
    Map<String, dynamic> json,
  ) {
    return CommissionCollectedIncomeSettlementRow(
      settlementId: json['settlement_id']?.toString() ?? '',
      invoiceReference: json['invoice_reference']?.toString(),
      importadorId: json['importador_id']?.toString() ?? '',
      businessName: (json['business_name']?.toString().trim().isNotEmpty == true)
          ? json['business_name'].toString().trim()
          : 'Importador',
      documentType: json['document_type']?.toString() ?? 'fiscal_invoice',
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.tryParse(json['paid_at'].toString()),
      totalCollectedUsd: _asDouble(json['total_collected_usd']),
      operationCount: _asInt(json['operation_count']),
    );
  }
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime _asDate(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length >= 10) {
    return DateTime.tryParse(s.substring(0, 10)) ??
        DateTime.tryParse(s) ??
        DateTime(1970);
  }
  return DateTime.tryParse(s) ?? DateTime(1970);
}

List<T> _mapList<T>(
  dynamic raw,
  T Function(Map<String, dynamic> json) map,
) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((e) => map(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

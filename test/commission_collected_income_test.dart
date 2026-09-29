import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_period.dart';
import 'package:motolink_pro_app/features/commissions/commission_collected_income_report.dart';
import 'package:motolink_pro_app/features/commissions/commission_invoice_reference.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_document_type.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_filter_utils.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_model.dart';

CommissionSettlementModel _settlement({
  required String id,
  String? invoiceReference,
  String status = 'pagado',
  String? businessName,
}) {
  return CommissionSettlementModel(
    id: id,
    importadorId: 'imp-1',
    periodStart: DateTime(2026, 9, 1),
    periodEnd: DateTime(2026, 9, 7),
    totalCommissionUsd: 10,
    lineCount: 1,
    status: status,
    invoiceReference: invoiceReference,
    importadorBusinessName: businessName,
  );
}

void main() {
  group('CommissionInvoiceReference', () {
    test('nuevas facturas y notas usan B2B-COM/NOT con correlativo de 6 dígitos', () {
      expect(
        CommissionInvoiceReference.format(kind: 'COM', year: 2026, seq: 42),
        'B2B-COM-2026-000042',
      );
      expect(
        CommissionInvoiceReference.format(kind: 'NOT', year: 2026, seq: 42),
        'B2B-NOT-2026-000042',
      );
      expect(
        CommissionSettlementDocumentType.fiscalInvoice.referencePrefix,
        'B2B-COM-',
      );
      expect(
        CommissionSettlementDocumentType.deliveryNote.referencePrefix,
        'B2B-NOT-',
      );
    });

    test('no genera prefijo ML ni cambia el relleno del correlativo', () {
      final ref = CommissionInvoiceReference.format(
        kind: 'COM',
        year: 2026,
        seq: 1,
      );
      expect(ref.startsWith('ML-'), isFalse);
      expect(ref, 'B2B-COM-2026-000001');
      expect(ref.length, 'B2B-COM-2026-000001'.length);
    });

    test('acepta históricos ML y nuevos B2B', () {
      expect(
        CommissionInvoiceReference.isLegacyFormat('ML-COM-2026-000042'),
        isTrue,
      );
      expect(
        CommissionInvoiceReference.isNewFormat('B2B-NOT-2026-000042'),
        isTrue,
      );
      expect(
        CommissionInvoiceReference.isValidPersisted('ML-NOT-2026-000001'),
        isTrue,
      );
      expect(
        CommissionInvoiceReference.isValidPersisted('B2B-COM-2026-000001'),
        isTrue,
      );
      expect(CommissionInvoiceReference.isValidPersisted('B2B-C-42'), isFalse);
    });

    test('búsqueda acepta ML- y B2B- para el mismo correlativo', () {
      expect(
        CommissionInvoiceReference.matchesQuery(
          'ML-COM-2026-000042',
          'B2B-COM-2026-000042',
        ),
        isTrue,
      );
      expect(
        CommissionInvoiceReference.matchesQuery(
          'B2B-NOT-2026-000042',
          'ML-NOT-2026-000042',
        ),
        isTrue,
      );
      final historical = _settlement(
        id: 'h1',
        invoiceReference: 'ML-COM-2026-000042',
      );
      final neu = _settlement(
        id: 'n1',
        invoiceReference: 'B2B-COM-2026-000042',
      );
      expect(
        commissionSettlementMatchesSearch(historical, 'ML-COM-2026-000042'),
        isTrue,
      );
      expect(
        commissionSettlementMatchesSearch(historical, 'B2B-COM-2026-000042'),
        isTrue,
      );
      expect(
        commissionSettlementMatchesSearch(neu, 'ML-COM-2026-000042'),
        isTrue,
      );
    });
  });

  group('CommissionCollectedIncomePeriod', () {
    final utc = DateTime.utc(2026, 9, 29, 3, 0); // 23:00 del 28 en Caracas

    test('Hoy y últimos 7 días usan calendario Caracas', () {
      final today = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.today,
        utcNow: utc,
      );
      expect(today.from, DateTime(2026, 9, 28));
      expect(today.to, DateTime(2026, 9, 28));
      expect(today.inclusiveDayCount, 1);

      final last7 = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.last7Days,
        utcNow: utc,
      );
      expect(last7.from, DateTime(2026, 9, 22));
      expect(last7.to, DateTime(2026, 9, 28));
      expect(last7.inclusiveDayCount, 7);
    });

    test('este mes y mes anterior', () {
      final month = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.thisMonth,
        utcNow: utc,
      );
      expect(month.from, DateTime(2026, 9, 1));
      expect(month.to, DateTime(2026, 9, 28));

      final prev = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.previousMonth,
        utcNow: utc,
      );
      expect(prev.from, DateTime(2026, 8, 1));
      expect(prev.to, DateTime(2026, 8, 31));
    });

    test('rango inválido y período anterior equivalente', () {
      final invalid = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.custom,
        customFrom: DateTime(2026, 9, 10),
        customTo: DateTime(2026, 9, 1),
      );
      expect(invalid.isInvalidRange, isTrue);

      final week = CommissionCollectedIncomePeriod.fromPreset(
        CommissionCollectedIncomePreset.last7Days,
        utcNow: utc,
      );
      final previous = week.previousEquivalent;
      expect(previous.to, DateTime(2026, 9, 21));
      expect(previous.from, DateTime(2026, 9, 15));
      expect(previous.inclusiveDayCount, week.inclusiveDayCount);
    });
  });

  group('CommissionCollectedIncomeReport', () {
    test('excluye implícitamente no pagados: solo usa total cobrado del JSON', () {
      final report = CommissionCollectedIncomeReport.fromJson({
        'timezone': 'America/Caracas',
        'from': '2026-09-01',
        'to': '2026-09-28',
        'grain': 'week',
        'total_collected_usd': 15.5,
        'operation_count': 3,
        'settlement_count': 2,
        'variation_pct': 10,
        'previous': {
          'from': '2026-08-04',
          'to': '2026-08-31',
          'total_collected_usd': 14.09,
          'operation_count': 2,
          'settlement_count': 1,
        },
        'series': [
          {
            'bucket': '2026-09-01',
            'total_collected_usd': 10.25,
            'operation_count': 2,
            'settlement_count': 1,
          },
          {
            'bucket': '2026-09-08',
            'total_collected_usd': 5.25,
            'operation_count': 1,
            'settlement_count': 1,
          },
        ],
        'by_importador': [
          {
            'importador_id': 'org-a',
            'business_name': 'Org A',
            'total_collected_usd': 10.25,
            'operation_count': 2,
            'settlement_count': 1,
          },
          {
            'importador_id': 'org-b',
            'business_name': 'Org B',
            'total_collected_usd': 5.25,
            'operation_count': 1,
            'settlement_count': 1,
          },
        ],
        'by_document_type': [
          {
            'document_type': 'fiscal_invoice',
            'total_collected_usd': 10.25,
            'operation_count': 2,
            'settlement_count': 1,
          },
          {
            'document_type': 'delivery_note',
            'total_collected_usd': 5.25,
            'operation_count': 1,
            'settlement_count': 1,
          },
        ],
        'settlements': [
          {
            'settlement_id': 's1',
            'invoice_reference': 'B2B-COM-2026-000042',
            'importador_id': 'org-a',
            'business_name': 'Org A',
            'document_type': 'fiscal_invoice',
            'paid_at': '2026-09-10T15:00:00+00:00',
            'total_collected_usd': 10.25,
            'operation_count': 2,
          },
        ],
      });

      expect(report.totalCollectedUsd, 15.5);
      expect(report.operationCount, 3);
      expect(report.seriesMatchesTotal, isTrue);
      expect(report.importadorBreakdownMatchesTotal, isTrue);
      expect(report.documentBreakdownMatchesTotal, isTrue);
      expect(report.canShowVariation, isTrue);
      expect(report.settlements.first.invoiceReference, 'B2B-COM-2026-000042');
    });

    test('período vacío y sin variación si el anterior es cero', () {
      final report = CommissionCollectedIncomeReport.fromJson({
        'from': '2026-09-01',
        'to': '2026-09-01',
        'grain': 'day',
        'total_collected_usd': 0,
        'operation_count': 0,
        'settlement_count': 0,
        'previous': {
          'from': '2026-08-31',
          'to': '2026-08-31',
          'total_collected_usd': 0,
          'operation_count': 0,
          'settlement_count': 0,
        },
        'series': [],
        'by_importador': [],
        'by_document_type': [],
        'settlements': [],
      });
      expect(report.isEmpty, isTrue);
      expect(report.canShowVariation, isFalse);
      expect(report.seriesMatchesTotal, isTrue);
    });
  });
}

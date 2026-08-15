import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/excel_catalog_service.dart';

void main() {
  group('parseGarantiaCell', () {
    test('acepta si y no', () {
      expect(
        ExcelCatalogService.parseGarantiaCell(
          'si',
          rowIndex: 1,
          sku: 'A',
        ).hasWarranty,
        isTrue,
      );
      expect(
        ExcelCatalogService.parseGarantiaCell(
          'no',
          rowIndex: 1,
          sku: 'A',
        ).hasWarranty,
        isFalse,
      );
    });

    test('acepta días numéricos del ERP', () {
      final r30 = ExcelCatalogService.parseGarantiaCell(
        '30',
        rowIndex: 2,
        sku: 'REP-001',
      );
      expect(r30.hasWarranty, isTrue);
      expect(r30.warrantyDays, 30);

      final r90 = ExcelCatalogService.parseGarantiaCell(
        '90 días',
        rowIndex: 3,
        sku: 'REP-002',
      );
      expect(r90.hasWarranty, isTrue);
      expect(r90.warrantyDays, 90);
    });

    test('0 días equivale a sin garantía', () {
      final r = ExcelCatalogService.parseGarantiaCell(
        '0',
        rowIndex: 4,
        sku: 'REP-003',
      );
      expect(r.hasWarranty, isFalse);
    });

    test('rechaza texto no interpretable', () {
      expect(
        () => ExcelCatalogService.parseGarantiaCell(
          'garantia limitada',
          rowIndex: 5,
          sku: 'REP-004',
        ),
        throwsFormatException,
      );
    });
  });
}

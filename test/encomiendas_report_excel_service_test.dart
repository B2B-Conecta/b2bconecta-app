import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/models/document_type_preference.dart';
import 'package:motolink_pro_app/models/transaction_request_model.dart';
import 'package:motolink_pro_app/models/transaction_request_status.dart';
import 'package:motolink_pro_app/services/encomiendas_report_excel_service.dart';

TransactionRequestModel _sampleRow() {
  return TransactionRequestModel(
    id: 'tr-001',
    aliadoId: 'a1',
    productId: 'p1',
    ownerId: 'o1',
    status: TransactionRequestStatus.entregado,
    cantidad: 2,
    precioUnitarioProveedor: 10,
    precioUnitarioAliado: 12,
    precioTotal: 24,
    precioBaseAliadoTotal: 24,
    createdAt: DateTime(2026, 5, 15, 10, 30),
    productName: 'Filtro aceite',
    productSku: 'FLT-001',
    aliadoBusinessName: 'Aliado Demo',
    ownerBusinessName: 'Importador Demo',
    documentTypePreference: DocumentTypePreference.facturaFiscal,
    aliadoExperienceStars: 4,
    aliadoExperienceComment: 'Buen servicio',
    aliadoExperienceSubmittedAt: DateTime(2026, 5, 20),
  );
}

void main() {
  test('buildReportBytes writes data on Encomiendas sheet (not empty Sheet1)', () {
    final bytes = EncomiendasReportExcelService.buildReportBytes(
      [_sampleRow()],
      meta: const EncomiendasReportExportMeta(
        dateFromLabel: '01/01/2026',
        dateToLabel: '31/05/2026',
        filterSummaryLines: ['Filtro: solo entregados'],
      ),
    );

    expect(bytes.length, greaterThan(200));

    final decoded = Excel.decodeBytes(bytes);
    expect(decoded.tables.containsKey('Encomiendas'), isTrue);
    expect(decoded.tables.containsKey('Sheet1'), isFalse);

    final sheet = decoded.tables['Encomiendas']!;
    expect(sheet.maxRows, greaterThan(2));

    var foundHeader = false;
    var foundSku = false;
    for (var r = 0; r < sheet.maxRows; r++) {
      final a = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
          .value
          ?.toString();
      final d = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r))
          .value
          ?.toString();
      if (a == 'ID pedido') foundHeader = true;
      if (d == 'FLT-001') foundSku = true;
    }
    expect(foundHeader, isTrue, reason: 'header row must be present');
    expect(foundSku, isTrue, reason: 'data row must be present');
  });
}

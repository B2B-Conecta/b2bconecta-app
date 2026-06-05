import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/document_type_preference.dart';
import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../utils/admin_product_sales_ranking.dart';
import '../utils/app_date_format.dart';

/// Metadatos opcionales del export (filtros aplicados en pantalla).
class EncomiendasReportExportMeta {
  const EncomiendasReportExportMeta({
    this.generatedAt,
    this.dateFromLabel,
    this.dateToLabel,
    this.filterSummaryLines = const [],
  });

  final DateTime? generatedAt;
  final String? dateFromLabel;
  final String? dateToLabel;
  final List<String> filterSummaryLines;
}

/// Exportación Excel para reportes de encomiendas / facturación (admin).
class EncomiendasReportExcelService {
  EncomiendasReportExcelService._();

  static const _sheetName = 'Encomiendas';

  static const _topProductsSheetName = 'Productos mas vendidos';

  static const _topProductsHeaders = [
    '#',
    'Producto',
    'SKU',
    'Importador',
    'Pedidos',
    'Unidades',
    'Total REF (aliado)',
  ];

  static const _headers = [
    'ID pedido',
    'Creado',
    'Estado',
    'Producto',
    'SKU',
    'Aliado',
    'Importador',
    'Cantidad',
    'Total REF (aliado)',
    'Pref. documento',
    'Factura importador',
    'Pago estado',
    'Método pago',
    'Estrellas',
    'Comentario aliado',
    'Fecha valoración',
  ];

  static Uint8List buildReportBytes(
    List<TransactionRequestModel> rows, {
    EncomiendasReportExportMeta? meta,
    List<AdminProductSalesStat>? topProducts,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    var rowIndex = 0;
    if (meta != null) {
      rowIndex = _appendMetaBlock(sheet, meta, rowIndex);
      rowIndex++; // línea en blanco antes de cabeceras
    }

    sheet.appendRow(_headers.map(TextCellValue.new).toList());
    rowIndex++;

    for (final r in rows) {
      sheet.appendRow(_dataRow(r));
      rowIndex++;
    }

    excel.rename('Sheet1', _sheetName);

    final ranking = topProducts ?? aggregateProductSales(rows);
    if (ranking.isNotEmpty) {
      final topSheet = excel[_topProductsSheetName];
      topSheet.appendRow(_topProductsHeaders.map(TextCellValue.new).toList());
      for (var i = 0; i < ranking.length; i++) {
        final s = ranking[i];
        topSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(s.productName),
          TextCellValue(s.productSku ?? ''),
          TextCellValue(s.importerName ?? ''),
          IntCellValue(s.orderCount),
          IntCellValue(s.unitsSold),
          DoubleCellValue(s.totalRefUsd),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static int _appendMetaBlock(
    Sheet sheet,
    EncomiendasReportExportMeta meta,
    int startRow,
  ) {
    var row = startRow;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue('MotoLink — Reporte de encomiendas');
    row++;
    final stamp = meta.generatedAt ?? DateTime.now();
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      'Generado: ${formatEsShortDateTime(stamp)}',
    );
    row++;
    if (meta.dateFromLabel != null && meta.dateToLabel != null) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        'Rango: ${meta.dateFromLabel} — ${meta.dateToLabel}',
      );
      row++;
    }
    for (final line in meta.filterSummaryLines) {
      if (line.trim().isEmpty) continue;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(line.trim());
      row++;
    }
    return row;
  }

  static List<CellValue?> _dataRow(TransactionRequestModel r) {
    final docPref = r.documentTypePreference?.trim();
    final docLabel = docPref == null || docPref.isEmpty
        ? 'Pendiente'
        : (DocumentTypePreference.labelEs(docPref) ?? docPref);
    return [
      TextCellValue(r.id),
      TextCellValue(formatEsShortDateTime(r.createdAt)),
      TextCellValue(TransactionRequestStatus.labelEs(r.status)),
      TextCellValue(r.productName ?? ''),
      TextCellValue(r.productSku ?? ''),
      TextCellValue(r.aliadoBusinessName ?? ''),
      TextCellValue(r.ownerBusinessName ?? ''),
      IntCellValue(r.cantidad),
      DoubleCellValue(r.precioTotal),
      TextCellValue(docLabel),
      TextCellValue(r.hasProveedorFactura ? 'Sí' : 'No'),
      TextCellValue(_pagoLabel(r)),
      TextCellValue(
        r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
            ? PagoMetodo.labelEs(r.pagoMetodo!)
            : '',
      ),
      r.aliadoExperienceStars != null
          ? IntCellValue(r.aliadoExperienceStars!)
          : TextCellValue(''),
      TextCellValue(r.aliadoExperienceComment ?? ''),
      TextCellValue(formatEsShortDateTime(r.aliadoExperienceSubmittedAt)),
    ];
  }

  static String _pagoLabel(TransactionRequestModel r) {
    final pe = r.pagoEstadoRevision?.trim();
    if (pe == null || pe.isEmpty) return 'Pendiente';
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pendiente';
      case PagoRevisionEstado.enRevision:
        return 'En revisión';
      case PagoRevisionEstado.aprobado:
        return 'Aprobado';
      case PagoRevisionEstado.rechazado:
        return 'Rechazado';
      default:
        return pe;
    }
  }
}

import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/document_type_preference.dart';
import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../utils/app_date_format.dart';

/// Exportación Excel para reportes de encomiendas / facturación (admin).
class EncomiendasReportExcelService {
  EncomiendasReportExcelService._();

  static Uint8List buildReportBytes(
    List<TransactionRequestModel> rows, {
    String sheetTitle = 'Encomiendas',
    Map<String, String> aliadoBucketAnswersByRequestId = const {},
  }) {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel[sheetTitle];
    final headers = [
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
      'Factura MotoLink aliado',
      'Pago estado',
      'Método pago',
      'Estrellas',
      'Comentario aliado',
      'Fecha valoración',
      'Cuestionario aliado (Bucket)',
    ];
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
    }
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rowIndex = i + 1;
      final docPref = r.documentTypePreference?.trim();
      final docLabel = docPref == null || docPref.isEmpty
          ? 'Pendiente'
          : (DocumentTypePreference.labelEs(docPref) ?? docPref);
      final vals = <Object?>[
        r.id,
        formatEsShortDateTime(r.createdAt),
        TransactionRequestStatus.labelEs(r.status),
        r.productName ?? '',
        r.productSku ?? '',
        r.aliadoBusinessName ?? '',
        r.ownerBusinessName ?? '',
        r.cantidad,
        r.precioTotal,
        docLabel,
        r.hasFacturaAliado ? 'Sí' : 'No',
        _pagoLabel(r),
        r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
            ? PagoMetodo.labelEs(r.pagoMetodo!)
            : '',
        r.aliadoExperienceStars ?? '',
        r.aliadoExperienceComment ?? '',
        formatEsShortDateTime(r.aliadoExperienceSubmittedAt),
        aliadoBucketAnswersByRequestId[r.id] ?? '',
      ];
      for (var c = 0; c < vals.length; c++) {
        final v = vals[c];
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex))
            .value = v == null ||
                v == ''
            ? TextCellValue('')
            : TextCellValue(v.toString());
      }
    }
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static String _pagoLabel(TransactionRequestModel r) {
    if (!r.hasFacturaAliado) return '—';
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

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/motolink_fiscal_issuer_constants.dart';
import '../utils/ves_amount_format.dart';

/// Bloques compartidos entre factura fiscal y nota de entrega (mismo formato).
abstract final class MotolinkCommissionSettlementPdfLayout {
  static Future<Uint8List?> loadLogo() async {
    try {
      final data =
          await rootBundle.load('assets/logo-oficial-motolinkpro-nobg.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static String formatIssuedDate(DateTime issued) =>
      '${issued.day.toString().padLeft(2, '0')}/'
      '${issued.month.toString().padLeft(2, '0')}/${issued.year}';

  static String fmtRef(double v) => 'REF ${formatRefAmount(v)}';

  static String fmtBs(double v) => formatBsLabel(v);

  static pw.Widget issuerColumn(Uint8List? logoBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoBytes != null)
          pw.Image(pw.MemoryImage(logoBytes), width: 72, height: 72),
        pw.SizedBox(height: 6),
        pw.Text(
          MotolinkFiscalIssuerConstants.businessName,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'RIF: ${MotolinkFiscalIssuerConstants.rif}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          MotolinkFiscalIssuerConstants.address,
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          'Tel: ${MotolinkFiscalIssuerConstants.phone}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          MotolinkFiscalIssuerConstants.email,
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  static pw.Widget documentMetaColumn({
    required String title,
    String? subtitle,
    required String ref,
    required DateTime issued,
    required String periodLabel,
    required double tasaBcvEmision,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
        ],
        pw.Text(
          'N° $ref',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Emitida: ${formatIssuedDate(issued)}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Periodo: $periodLabel',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Tasa BCV (fecha de emisión): '
          '${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
      ],
    );
  }

  static pw.Widget headerRow({
    required Uint8List? logoBytes,
    required String title,
    String? subtitle,
    required String ref,
    required DateTime issued,
    required String periodLabel,
    required double tasaBcvEmision,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: issuerColumn(logoBytes)),
        documentMetaColumn(
          title: title,
          subtitle: subtitle,
          ref: ref,
          issued: issued,
          periodLabel: periodLabel,
          tasaBcvEmision: tasaBcvEmision,
        ),
      ],
    );
  }

  static pw.Widget clientSection({
    required String impName,
    required String impRif,
    required String impTel,
    required String impDir,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cliente (importador)',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        fieldRow('Razón social', impName),
        fieldRow('RIF', impRif),
        fieldRow('Teléfono', impTel),
        fieldRow('Domicilio fiscal', impDir),
      ],
    );
  }

  static pw.Widget conceptTable({
    required String sectionTitle,
    required String serviceDesc,
    required double amountUsd,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          sectionTitle,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: const ['Cant', 'Descripción', 'P.U. REF', 'Monto REF'],
          data: [
            ['1', serviceDesc, fmtRef(amountUsd), fmtRef(amountUsd)],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(4),
        ),
      ],
    );
  }

  static pw.Widget totalsPanel({
    required String leftNote,
    required List<({String label, String value, bool bold})> rows,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            leftNote,
            style: const pw.TextStyle(fontSize: 7, lineSpacing: 1.2),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              for (final row in rows)
                totRow(row.label, row.value, bold: row.bold),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget paymentAndSignature() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 14),
        pw.Text(
          'Forma de pago: transferencia o medio acordado con B2B Conecta. '
          'Registre el comprobante en la app (Perfil → Cortes de comisión).',
          style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
        ),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Text(
            'B2B Conecta Marketplace — documento generado electrónicamente.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  static pw.Widget pageFooter(String legalNote) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 0.5, color: PdfColors.grey500),
          pw.SizedBox(height: 6),
          pw.Text(
            legalNote,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget fieldRow(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(v, style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );
  }

  static pw.Widget totRow(String k, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            v,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

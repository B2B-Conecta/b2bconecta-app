import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/motolink_fiscal_issuer_constants.dart';
import '../models/commission_settlement_model.dart';
import '../utils/ves_amount_format.dart';

/// Genera PDF de factura de comisión MotoLink → importador (corte semanal C1).
class MotolinkCommissionInvoicePdfService {
  MotolinkCommissionInvoicePdfService._();

  static Future<Uint8List> build({
    required CommissionSettlementModel settlement,
    required List<CommissionSettlementLineModel> lines,
    required double tasaBcvEmision,
    String? importadorDireccion,
    String? importadorEstado,
    String? importadorCiudad,
    String? importadorPhone,
  }) async {
    Uint8List? logoBytes;
    try {
      final data =
          await rootBundle.load('assets/logo-oficial-motolinkpro-nobg.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    final doc = pw.Document();
    final issued = settlement.issuedAt ?? DateTime.now();
    final ref = settlement.invoiceReference?.trim().isNotEmpty == true
        ? settlement.invoiceReference!.trim()
        : settlement.id.substring(0, 8);
    final impName = settlement.importadorBusinessName?.trim().isNotEmpty == true
        ? settlement.importadorBusinessName!.trim()
        : 'Importador';
    final impRif = settlement.importadorRif?.trim() ?? '—';
    final dirParts = <String>[
      if (importadorDireccion?.trim().isNotEmpty == true)
        importadorDireccion!.trim(),
      if (importadorCiudad?.trim().isNotEmpty == true) importadorCiudad!.trim(),
      if (importadorEstado?.trim().isNotEmpty == true) importadorEstado!.trim(),
    ];
    final impDir =
        dirParts.isEmpty ? '—' : dirParts.join(', ');
    final impTel = importadorPhone?.trim() ?? '—';

    final totalUsd = settlement.totalCommissionUsd;
    final totalBs = totalUsd * tasaBcvEmision;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 0.5, color: PdfColors.grey500),
              pw.SizedBox(height: 6),
              pw.Text(
                'Documento de cobro por intermediación B2B (comisión MotoLink). '
                'Sujeto a validación fiscal con su contador. '
                'Tasa BCV referencia: ${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoBytes != null)
                      pw.Image(
                        pw.MemoryImage(logoBytes),
                        width: 72,
                        height: 72,
                      ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      MotolinkFiscalIssuerConstants.businessName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
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
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'FACTURA DE COMISIÓN',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
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
                    'Emitida: ${issued.day.toString().padLeft(2, '0')}/'
                    '${issued.month.toString().padLeft(2, '0')}/${issued.year}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Periodo: ${settlement.periodLabelEs}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    '${settlement.lineCount} línea(s) de pedido',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Cliente (importador)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          _fieldRow('Razón social', impName),
          _fieldRow('RIF', impRif),
          _fieldRow('Teléfono', impTel),
          _fieldRow('Domicilio fiscal', impDir),
          pw.SizedBox(height: 10),
          pw.Text(
            'Detalle de comisiones devengadas (pedidos marcados como Recibido)',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Pedido',
              'Descripción',
              'Venta USD',
              'Comisión USD',
            ],
            data: lines.map((l) {
              final pid = l.requestId.length >= 8
                  ? l.requestId.substring(0, 8)
                  : l.requestId;
              final desc = l.productName?.trim().isNotEmpty == true
                  ? l.productName!.trim()
                  : 'Línea de pedido';
              return [
                pid,
                desc,
                _fmtUsd(l.precioTotalUsd),
                _fmtUsd(l.comisionDevengadaUsd),
              ];
            }).toList(),
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
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _totRow('Total comisión USD', _fmtUsd(totalUsd), bold: true),
                    _totRow(
                      'Referencia Bs (× ${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)})',
                      formatBsLabel(totalBs),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Forma de pago: transferencia o medio acordado con MotoLink. '
            'Registre el comprobante en la app (Perfil → Cortes de comisión).',
            style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.2),
          ),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              'MotoLink Marketplace B2B — documento generado electrónicamente.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _fmtUsd(double v) => 'USD ${formatRefAmount(v)}';

  static pw.Widget _fieldRow(String k, String v) {
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

  static pw.Widget _totRow(String k, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            v,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

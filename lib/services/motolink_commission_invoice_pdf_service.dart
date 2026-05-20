import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/motolink_fiscal_issuer_constants.dart';
import '../models/commission_settlement_model.dart';
import '../utils/commission_settlement_fiscal.dart';
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

    final baseUsd = settlement.baseImponibleComisionUsd;
    final ivaUsd = settlement.ivaComisionUsd;
    final totalUsd = settlement.totalFacturaUsd;
    final baseBs = baseUsd * tasaBcvEmision;
    final ivaBs = ivaUsd * tasaBcvEmision;
    final totalBs = totalUsd * tasaBcvEmision;
    final ivaPct = CommissionSettlementFiscal.ivaPct;
    final serviceDesc =
        'Servicio de intermediación digital y uso de plataforma tecnológica '
        'MotoLink, según corte de cuenta referencia $ref';

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
                'Documento fiscal por intermediación B2B (comisión MotoLink + IVA). '
                'Sujeto a validación con su contador. '
                'Tasa BCV referencia emisión: '
                '${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}.',
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
                    'Tasa BCV (fecha de emisión): '
                    '${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
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
            'Concepto facturado (servicio de intermediación)',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Cant', 'Descripción', 'P.U. REF', 'Monto REF'],
            data: [
              [
                '1',
                serviceDesc,
                _fmtRef(baseUsd),
                _fmtRef(baseUsd),
              ],
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
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Montos en REF (divisa de referencia). Contravalor en bolívares '
                  'según tasa oficial BCV del día de emisión '
                  '(${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}). '
                  'IVA ${formatVesAmount(ivaPct, fractionDigits: 2)} % sobre la base imponible de comisión.',
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
                    _totRow('Subtotal / Base imponible REF', _fmtRef(baseUsd)),
                    _totRow(
                      'Subtotal / Base imponible Bs',
                      _fmtBs(baseBs),
                    ),
                    _totRow(
                      'IVA (${formatVesAmount(ivaPct, fractionDigits: 2)}%) REF',
                      _fmtRef(ivaUsd),
                    ),
                    _totRow('IVA Bs', _fmtBs(ivaBs)),
                    _totRow(
                      'Total general de la factura REF',
                      _fmtRef(totalUsd),
                      bold: true,
                    ),
                    _totRow(
                      'Total general de la factura Bs',
                      _fmtBs(totalBs),
                      bold: true,
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

  static String _fmtRef(double v) => 'REF ${formatRefAmount(v)}';

  static String _fmtBs(double v) => formatBsLabel(v);

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

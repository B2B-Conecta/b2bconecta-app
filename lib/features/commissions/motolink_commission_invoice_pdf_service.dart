import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'commission_settlement_model.dart';
import 'commission_settlement_fiscal.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'motolink_commission_settlement_pdf_layout.dart';

/// Factura fiscal de comisión B2B Conecta → importador (corte semanal).
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
    final logoBytes = await MotolinkCommissionSettlementPdfLayout.loadLogo();
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
    final impDir = dirParts.isEmpty ? '—' : dirParts.join(', ');
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
        'B2B Conecta, según corte de cuenta referencia $ref';

    final tasaTxt =
        formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => MotolinkCommissionSettlementPdfLayout.pageFooter(
          'Documento fiscal por intermediación B2B (comisión B2B Conecta + IVA). '
          'Sujeto a validación con su contador. '
          'Tasa BCV referencia emisión: $tasaTxt.',
        ),
        build: (ctx) => [
          MotolinkCommissionSettlementPdfLayout.headerRow(
            logoBytes: logoBytes,
            title: 'FACTURA DE COMISIÓN',
            ref: ref,
            issued: issued,
            periodLabel: settlement.periodLabelEs,
            tasaBcvEmision: tasaBcvEmision,
          ),
          pw.SizedBox(height: 14),
          MotolinkCommissionSettlementPdfLayout.clientSection(
            impName: impName,
            impRif: impRif,
            impTel: impTel,
            impDir: impDir,
          ),
          pw.SizedBox(height: 10),
          MotolinkCommissionSettlementPdfLayout.conceptTable(
            sectionTitle: 'Concepto facturado (servicio de intermediación)',
            serviceDesc: serviceDesc,
            amountUsd: baseUsd,
          ),
          pw.SizedBox(height: 12),
          MotolinkCommissionSettlementPdfLayout.totalsPanel(
            leftNote:
                'Montos en REF (divisa de referencia). Contravalor en bolívares '
                'según tasa oficial BCV del día de emisión ($tasaTxt). '
                'IVA ${formatVesAmount(ivaPct, fractionDigits: 2)} % sobre la base imponible de comisión.',
            rows: [
              (
                label: 'Subtotal / Base imponible REF',
                value: MotolinkCommissionSettlementPdfLayout.fmtRef(baseUsd),
                bold: false,
              ),
              (
                label: 'Subtotal / Base imponible Bs',
                value: MotolinkCommissionSettlementPdfLayout.fmtBs(baseBs),
                bold: false,
              ),
              (
                label: 'IVA (${formatVesAmount(ivaPct, fractionDigits: 2)}%) REF',
                value: MotolinkCommissionSettlementPdfLayout.fmtRef(ivaUsd),
                bold: false,
              ),
              (
                label: 'IVA Bs',
                value: MotolinkCommissionSettlementPdfLayout.fmtBs(ivaBs),
                bold: false,
              ),
              (
                label: 'Total general de la factura REF',
                value: MotolinkCommissionSettlementPdfLayout.fmtRef(totalUsd),
                bold: true,
              ),
              (
                label: 'Total general de la factura Bs',
                value: MotolinkCommissionSettlementPdfLayout.fmtBs(totalBs),
                bold: true,
              ),
            ],
          ),
          MotolinkCommissionSettlementPdfLayout.paymentAndSignature(),
        ],
      ),
    );

    return doc.save();
  }
}

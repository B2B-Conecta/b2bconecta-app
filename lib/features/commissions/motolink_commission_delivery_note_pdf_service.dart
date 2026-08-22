import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:motolink_pro_app/app/config/brand_copy.dart';

import 'commission_settlement_model.dart';
import 'commission_settlement_fiscal.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'motolink_commission_settlement_pdf_layout.dart';

/// Nota de entrega / relación de control interno (mismo formato que factura fiscal, sin IVA).
class MotolinkCommissionDeliveryNotePdfService {
  MotolinkCommissionDeliveryNotePdfService._();

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

    final netUsd = settlement.baseImponibleComisionUsd;
    final netBs = netUsd * tasaBcvEmision;
    final ventasInfo =
        CommissionSettlementFiscal.totalVentasInformativoUsd(lines);
    final serviceDesc =
        'Servicio de intermediación digital y uso de plataforma tecnológica '
        '${BrandCopy.name}, según corte de cuenta referencia $ref';

    final tasaTxt =
        formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => MotolinkCommissionSettlementPdfLayout.pageFooter(
          'Relación de control interno (nota de entrega). Sin desglose de IVA. '
          'Tasa BCV referencia emisión: $tasaTxt.',
        ),
        build: (ctx) => [
          MotolinkCommissionSettlementPdfLayout.headerRow(
            logoBytes: logoBytes,
            title: 'NOTA DE ENTREGA',
            subtitle: 'Relación de control interno',
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
            sectionTitle:
                'Concepto registrado (servicio de intermediación)',
            serviceDesc: serviceDesc,
            amountUsd: netUsd,
          ),
          pw.SizedBox(height: 12),
          MotolinkCommissionSettlementPdfLayout.totalsPanel(
            leftNote:
                'Montos en REF (divisa de referencia). Contravalor en bolívares '
                'según tasa oficial BCV del día de emisión ($tasaTxt). '
                'Documento exento de IVA (control operativo). '
                'Ventas del periodo (informativo): '
                '${MotolinkCommissionSettlementPdfLayout.fmtRef(ventasInfo)} · '
                '${lines.length} pedido(s) en el corte.',
            rows: [
              (
                label: 'Subtotal / Base comisión REF',
                value: MotolinkCommissionSettlementPdfLayout.fmtRef(netUsd),
                bold: false,
              ),
              (
                label: 'Subtotal / Base comisión Bs',
                value: MotolinkCommissionSettlementPdfLayout.fmtBs(netBs),
                bold: false,
              ),
              (
                label: 'Total neto de la nota REF',
                value: MotolinkCommissionSettlementPdfLayout.fmtRef(netUsd),
                bold: true,
              ),
              (
                label: 'Total neto de la nota Bs',
                value: MotolinkCommissionSettlementPdfLayout.fmtBs(netBs),
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

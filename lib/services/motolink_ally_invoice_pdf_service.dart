import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/motolink_fiscal_issuer_constants.dart';
import '../models/document_type_preference.dart';
import '../models/transaction_request_model.dart';
import '../utils/ves_amount_format.dart';

/// Línea de detalle para el PDF (ítem de pedido).
class MotolinkAllyInvoicePdfLine {
  const MotolinkAllyInvoicePdfLine({
    required this.codigo,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitarioRef,
    required this.montoRef,
  });

  final String codigo;
  final String descripcion;
  final int cantidad;
  final double precioUnitarioRef;
  final double montoRef;
}

/// Genera PDF de Nota de entrega (exenta) o Factura fiscal (IVA + IGTF) al aliado.
class MotolinkAllyInvoicePdfService {
  MotolinkAllyInvoicePdfService._();

  /// Líneas de facturación en orden (order_items del maestro o línea única simple).
  static List<MotolinkAllyInvoicePdfLine> linesFromRequest(TransactionRequestModel r) {
    if (r.isMasterOrder && r.subOrders.isNotEmpty) {
      final out = <MotolinkAllyInvoicePdfLine>[];
      for (final so in r.subOrders) {
        final imp = so.importadorBusinessName?.trim();
        for (final oi in so.orderItems) {
          final name = oi.productName?.trim().isNotEmpty == true
              ? oi.productName!.trim()
              : 'Producto';
          final sku = oi.productSku?.trim() ?? '';
          final desc = imp != null && imp.isNotEmpty ? '$name · $imp' : name;
          out.add(
            MotolinkAllyInvoicePdfLine(
              codigo: sku.isNotEmpty ? sku : '—',
              descripcion: desc,
              cantidad: oi.cantidad,
              precioUnitarioRef: oi.precioUnitarioAliado,
              montoRef: oi.precioLineTotal,
            ),
          );
        }
      }
      if (out.isEmpty) {
        for (final so in r.subOrders) {
          if (so.montoSubtotal <= 0) continue;
          final imp = so.importadorBusinessName?.trim();
          out.add(
            MotolinkAllyInvoicePdfLine(
              codigo: '—',
              descripcion: imp != null && imp.isNotEmpty
                  ? 'Resumen almacén · $imp'
                  : 'Resumen sub-pedido',
              cantidad: 1,
              precioUnitarioRef: so.montoSubtotal,
              montoRef: so.montoSubtotal,
            ),
          );
        }
      }
      if (out.isNotEmpty) return out;
    }
    final pname = r.productName?.trim().isNotEmpty == true
        ? r.productName!.trim()
        : 'Producto';
    final sku = r.productSku?.trim() ?? '';
    return [
      MotolinkAllyInvoicePdfLine(
        codigo: sku.isNotEmpty ? sku : '—',
        descripcion: pname,
        cantidad: r.cantidad,
        precioUnitarioRef: r.precioUnitarioAliado,
        montoRef: r.precioTotal,
      ),
    ];
  }

  static Future<Uint8List> build({
    required TransactionRequestModel request,
    required String documentType,
    required int correlativo,
    required double tasaBcvEmision,
    required double ivaPct,
    required double igtfPct,
    required String emissionId,
    List<MotolinkAllyInvoicePdfLine>? lines,
    int fragmentIndex = 1,
    int fragmentTotal = 1,
  }) async {
    final useLines = lines ?? linesFromRequest(request);
    final subtotalRef =
        useLines.fold<double>(0, (a, e) => a + e.montoRef);

    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/logo-oficial-motolinkpro-nobg.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    final doc = pw.Document();
    final now = DateTime.now();
    final isNota = documentType == DocumentTypePreference.notaEntrega;
    final title = isNota ? 'NOTA DE ENTREGA' : 'FACTURA FISCAL';
    final docLabel = isNota ? 'NE' : 'FF';
    final controlFmt =
        '00-${correlativo.toString().padLeft(6, '0')}';
    final idShort = request.id.length >= 8
        ? request.id.substring(0, 8)
        : request.id;
    final emissionShort = emissionId.length >= 8
        ? emissionId.substring(0, 8)
        : emissionId;

    final aliadoNombre = request.aliadoBusinessName?.trim().isNotEmpty == true
        ? request.aliadoBusinessName!.trim()
        : 'Cliente';
    final aliadoRif = request.aliadoRif?.trim() ?? '—';
    final aliadoTel = request.aliadoPhone?.trim() ?? '—';
    final aliadoDir = request.aliadoDireccionFiscalMultilineaEs?.trim() ??
        request.destinoEntregaTextoParaMapa;

    final subtotalBs = subtotalRef * tasaBcvEmision;
    final baseBs = subtotalBs;
    final ivaBs = isNota ? 0.0 : baseBs * (ivaPct / 100.0);
    final totalOperacionBs = isNota ? subtotalBs : (baseBs + ivaBs);
    final igtfBs =
        isNota ? 0.0 : (totalOperacionBs * (igtfPct / 100.0));
    final totalPagarBs = totalOperacionBs + igtfBs;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 0.5, color: PdfColors.grey500),
              pw.SizedBox(height: 6),
              pw.Text(
                'Tasa BCV utilizada para conversión REF → Bs: '
                '${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Observaciones: Página $fragmentIndex de $fragmentTotal del pedido #$idShort',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
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
                    pw.Text('RIF: ${MotolinkFiscalIssuerConstants.rif}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(MotolinkFiscalIssuerConstants.address,
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Tel: ${MotolinkFiscalIssuerConstants.phone}',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(MotolinkFiscalIssuerConstants.email,
                        style: const pw.TextStyle(fontSize: 8)),
                    if (!isNota) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Código operación: ${MotolinkFiscalIssuerConstants.codigoOperacion}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (!isNota)
                    pw.Text(
                      'Código origen: ${MotolinkFiscalIssuerConstants.codigoOrigen}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'N° $docLabel-${correlativo.toString().padLeft(6, '0')}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900,
                    ),
                  ),
                  pw.Text('N° de Control $controlFmt',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Emitida: ${now.day.toString().padLeft(2, '0')}/'
                    '${now.month.toString().padLeft(2, '0')}/${now.year}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Emisión UUID: $emissionShort…',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Cliente (aliado)',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          _fieldRow('Razón social', aliadoNombre),
          _fieldRow('RIF', aliadoRif),
          _fieldRow('Teléfono', aliadoTel),
          _fieldRow('Domicilio fiscal', aliadoDir),
          _fieldRow(
            'Pedido MotoLink',
            idShort,
          ),
          _fieldRow(
            'Observaciones',
            'Página $fragmentIndex de $fragmentTotal del pedido #$idShort',
          ),
          ..._importerBlockWidgets(request),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: isNota
                ? const ['Cant', 'Descripción', 'P.U. REF', 'Monto REF']
                : const [
                    'Cód',
                    'Descripción',
                    'Cant',
                    'P.U. REF',
                    'Monto REF',
                  ],
            data: useLines.map((e) {
              if (isNota) {
                return [
                  e.cantidad.toString(),
                  '${e.descripcion}${e.codigo.isNotEmpty ? ' (${e.codigo})' : ''}',
                  _fmtRef(e.precioUnitarioRef),
                  _fmtRef(e.montoRef),
                ];
              }
              return [
                e.codigo,
                e.descripcion,
                e.cantidad.toString(),
                _fmtRef(e.precioUnitarioRef),
                _fmtRef(e.montoRef),
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Forma de pago: según acuerdo en la app MotoLink.',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      isNota
                          ? 'Documento exento (nota de entrega). Montos en REF; '
                              'referencia en bolívares según tasa BCV del día de emisión '
                              '(${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}).'
                          : 'Factura fiscal: IVA ${formatVesAmount(ivaPct, fractionDigits: 2)} % e IGTF '
                              '${formatVesAmount(igtfPct, fractionDigits: 2)} % aplicados según parámetros MotoLink '
                              '(ajustables por contador). Tasa BCV emisión: '
                              '${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)}.',
                      style: const pw.TextStyle(fontSize: 7, lineSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _totRow('Subtotal REF', _fmtRef(subtotalRef)),
                    _totRow(
                      'Subtotal Bs (× ${formatTasaBcvDisplay(tasaBcvEmision, fractionDigits: 4)})',
                      _fmtBs(subtotalBs),
                    ),
                    if (isNota) ...[
                      _totRow('Total exento Bs', _fmtBs(subtotalBs)),
                      _totRow('I.V.A.', 'Exento'),
                      _totRow('I.G.T.F.', 'No aplica'),
                      _totRow('Total Bs', _fmtBs(subtotalBs),
                          bold: true),
                    ] else ...[
                      _totRow('Base imponible Bs', _fmtBs(baseBs)),
                      _totRow(
                          'I.V.A. (${formatVesAmount(ivaPct, fractionDigits: 2)}%)',
                          _fmtBs(ivaBs)),
                      _totRow('Total operación Bs', _fmtBs(totalOperacionBs)),
                      _totRow(
                          'I.G.T.F. (${formatVesAmount(igtfPct, fractionDigits: 2)}%)',
                          _fmtBs(igtfBs)),
                      _totRow('Total a pagar Bs', _fmtBs(totalPagarBs),
                          bold: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'MotoLink Marketplace B2B — documento generado electrónicamente.',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _fieldRow(String k, String? v) {
    final t = v?.trim();
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
            child: pw.Text(
              (t != null && t.isNotEmpty) ? t : '—',
              style: const pw.TextStyle(fontSize: 8),
            ),
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

  static String _fmtRef(double v) => 'REF ${formatRefAmount(v)}';

  static String _fmtBs(double v) => formatBsLabel(v);

  static List<String> _importerNamesOrdered(TransactionRequestModel r) {
    if (r.isMasterOrder && r.subOrders.isNotEmpty) {
      final names = <String>[];
      final seen = <String>{};
      for (final so in r.subOrders) {
        final n = so.importadorBusinessName?.trim();
        if (n == null || n.isEmpty) continue;
        if (seen.add(n)) names.add(n);
      }
      return names;
    }
    final o = r.ownerBusinessName?.trim();
    if (o != null && o.isNotEmpty) return [o];
    return const [];
  }

  static List<pw.Widget> _importerBlockWidgets(TransactionRequestModel r) {
    final names = _importerNamesOrdered(r);
    if (names.isEmpty) return const [];
    return [
      pw.SizedBox(height: 8),
      pw.Text(
        'Importadores asociados al pedido',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      ...names.map(
        (n) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text('• $n', style: const pw.TextStyle(fontSize: 8)),
        ),
      ),
    ];
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/commission_settlement_model.dart';
import '../services/supabase_service.dart';
import '../utils/app_date_format.dart';
import '../utils/commission_settlement_fiscal.dart';

/// Importador: registrar comprobante de pago de comisión B2B Conecta por corte.
class ImporterCommissionPagoSection extends StatefulWidget {
  const ImporterCommissionPagoSection({
    super.key,
    required this.settlement,
    required this.onChanged,
  });

  final CommissionSettlementModel settlement;
  final VoidCallback onChanged;

  @override
  State<ImporterCommissionPagoSection> createState() =>
      _ImporterCommissionPagoSectionState();
}

class _ImporterCommissionPagoSectionState
    extends State<ImporterCommissionPagoSection> {
  bool _busy = false;

  CommissionSettlementModel get s => widget.settlement;

  Future<void> _abrirFacturaPdf() async {
    final path = s.invoicePdfStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url =
          await SupabaseService.createSignedUrlForCommissionInvoicePdf(path);
      final uri = Uri.parse(url);
      if (!mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _abrirComprobante() async {
    final path = s.pagoComprobanteStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForComprobantePago(path);
      final uri = Uri.parse(url);
      if (!mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _subirComprobante() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    final name = f.name.trim();
    if (bytes == null || bytes.isEmpty || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.importadorSubmitCommissionSettlementPago(
        settlementId: s.id,
        bytes: bytes,
        fileName: name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comprobante enviado. B2B Conecta revisará el pago y le notificará.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (s.isPagado) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          s.paidAt != null
              ? 'Pago confirmado por B2B Conecta (${formatEsShortDateTime(s.paidAt)}).'
              : 'Pago confirmado por B2B Conecta.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800,
          ),
        ),
      );
    }

    if (!s.isEmitido) return const SizedBox.shrink();

    final ref = s.invoiceReference?.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.brandBlueContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brandAccent.withOpacity(0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pago de comisión a B2B Conecta',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref != null && ref.isNotEmpty
                    ? 'Factura: $ref · Monto a transferir: USD ${s.totalFacturaUsd.toStringAsFixed(2)} (IVA incl.)'
                    : 'Monto a transferir: USD ${s.totalFacturaUsd.toStringAsFixed(2)} (IVA incl.)',
                style: const TextStyle(fontSize: 11, height: 1.3),
              ),
              Text(
                'Base comisión USD ${s.baseImponibleComisionUsd.toStringAsFixed(2)} + '
                'IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} % '
                'USD ${s.ivaComisionUsd.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                s.pagoEstadoLabelEs,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: s.pagoRechazado
                      ? Colors.red.shade800
                      : s.pagoEnRevision
                          ? AppColors.brandBlue
                          : AppColors.textPrimary,
                ),
              ),
              if (s.pagoRechazado && s.pagoRechazoNota != null &&
                  s.pagoRechazoNota!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  s.pagoRechazoNota!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ],
              if (s.pagoComprobanteSubmittedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Enviado: ${formatEsShortDateTime(s.pagoComprobanteSubmittedAt)}',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (s.tieneFacturaPdf)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _abrirFacturaPdf,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Ver factura PDF'),
                    ),
                  if (s.tieneComprobantePago)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _abrirComprobante,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Ver comprobante de pago'),
                    ),
                  if (s.importadorPuedeRegistrarPago)
                    FilledButton.icon(
                      onPressed: _busy ? null : _subirComprobante,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(
                        s.tieneComprobantePago && s.pagoRechazado
                            ? 'Enviar nuevo comprobante'
                            : 'Registrar pago (comprobante)',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

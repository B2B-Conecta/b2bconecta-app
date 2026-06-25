import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/carrier_flete_pago_modo.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura del flete cuando el pago al transportista es separado.
class ImporterOrderFleteInvoiceSection extends StatefulWidget {
  const ImporterOrderFleteInvoiceSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<ImporterOrderFleteInvoiceSection> createState() =>
      _ImporterOrderFleteInvoiceSectionState();
}

class _ImporterOrderFleteInvoiceSectionState
    extends State<ImporterOrderFleteInvoiceSection> {
  bool _busy = false;

  bool get _visible =>
      widget.request.carrierFletePagoSeparado &&
      widget.request.hasImporterCarrierSelected;

  bool _statusPermite(TransactionRequestModel r) {
    return r.status == TransactionRequestStatus.pendiente ||
        r.status == TransactionRequestStatus.enPreparacion ||
        r.status == TransactionRequestStatus.pedidoListo;
  }

  Future<void> _abrir(BuildContext context) async {
    final path = widget.request.fleteFacturaStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForOrderInvoice(path);
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _upload(BuildContext context) async {
    if (!_statusPermite(widget.request)) return;

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
      await SupabaseService.importerSubmitFleteFactura(
        transactionRequestId: widget.request.id,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura de flete adjuntada.')),
      );
      widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final r = widget.request;
    final editable = _statusPermite(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Factura del flete',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pago separado al transportista (${CarrierFletePagoModo.shortLabelEs(r.carrierFletePagoModoSnapshot)}). '
          'Adjunte la factura del flete además de la del proveedor antes de «En tránsito».',
          style: TextStyle(fontSize: 11, height: 1.35, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        if (r.hasFleteFactura) ...[
          Text(
            r.fleteFacturaFileName?.trim().isNotEmpty == true
                ? 'Archivo: ${r.fleteFacturaFileName}'
                : 'Factura de flete registrada',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Text(
            'Fecha: ${formatEsShortDateTime(r.fleteFacturaSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _abrir(context),
            icon: const Icon(Icons.open_in_new_outlined, size: 18),
            label: const Text('Ver / descargar'),
          ),
        ],
        if (editable) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : () => _upload(context),
              child: Text(
                r.hasFleteFactura
                    ? 'Reemplazar factura de flete'
                    : 'Adjuntar factura de flete',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura digital del importador (pedido en preparación).
class ImporterOrderInvoiceSection extends StatefulWidget {
  const ImporterOrderInvoiceSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<ImporterOrderInvoiceSection> createState() =>
      _ImporterOrderInvoiceSectionState();
}

class _ImporterOrderInvoiceSectionState extends State<ImporterOrderInvoiceSection> {
  bool _busy = false;

  Future<void> _pickAndUpload(BuildContext context) async {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.enPreparacion) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    final name = f.name.trim();
    if (bytes == null || bytes.isEmpty || name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo.')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.importerSubmitOrderInvoice(
        transactionRequestId: r.id,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Factura enviada. MotoLink emitirá la factura al aliado y gestionará el pago antes del tránsito.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.enPreparacion) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Factura digital',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'MotoLink usará este archivo como referencia para emitir la factura al aliado a nombre de MotoLink.',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (r.hasProveedorFactura) ...[
          Text(
            r.proveedorFacturaFileName?.trim().isNotEmpty == true
                ? 'Enviada: ${r.proveedorFacturaFileName}'
                : 'Factura registrada',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Text(
            'Fecha: ${formatEsShortDateTime(r.proveedorFacturaSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : () => _pickAndUpload(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ] else
                  const Icon(Icons.upload_file_outlined, size: 20),
                if (!_busy) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    r.hasProveedorFactura
                        ? 'Reemplazar factura'
                        : 'Adjuntar factura digital (PDF o imagen)',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

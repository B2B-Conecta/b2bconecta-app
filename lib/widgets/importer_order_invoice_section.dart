import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_backend.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura digital del importador: edición solo en preparación; después solo consulta.
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

class _ImporterOrderInvoiceSectionState
    extends State<ImporterOrderInvoiceSection> {
  bool _busy = false;

  Future<void> _abrirFactura(BuildContext context) async {
    final path = widget.request.proveedorFacturaStoragePath?.trim();
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

  Future<void> _pickAndUpload(BuildContext context) async {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.enPreparacion) return;
    if (r.hasFacturaAliado) return;

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
        subOrderId: r.importerSubOrderId,
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

  Future<void> _pickAndUploadMotoconecta(BuildContext context) async {
    final r = widget.request;
    final okStatus = r.status == TransactionRequestStatus.pendiente ||
        r.status == TransactionRequestStatus.enPreparacion;
    if (!okStatus) return;

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
      await SupabaseService.importerSubmitMotoconectaProveedorFactura(
        transactionRequestId: r.id,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura del proveedor adjuntada.'),
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
    if (kAppUsesMotoConectaBackend) {
      final editable = r.status == TransactionRequestStatus.pendiente ||
          r.status == TransactionRequestStatus.enPreparacion;
      if (!editable && !r.hasProveedorFactura) {
        return const SizedBox.shrink();
      }
      final soloLectura = !editable;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            soloLectura
                ? 'Factura del proveedor (referencia)'
                : 'Factura del proveedor',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            soloLectura
                ? 'Archivo adjunto · solo consulta.'
                : 'Adjunte PDF o imagen antes de marcar el pedido como enviado.',
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
                  ? 'Archivo: ${r.proveedorFacturaFileName}'
                  : 'Factura registrada',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            Text(
              'Fecha: ${formatEsShortDateTime(r.proveedorFacturaSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _abrirFactura(context),
              icon: const Icon(Icons.open_in_new_outlined, size: 18),
              label: const Text('Ver / descargar'),
            ),
          ],
          if (!soloLectura) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : () => _pickAndUploadMotoconecta(context),
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
                            ? 'Reemplazar archivo'
                            : 'Adjuntar factura (PDF o imagen)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }
    final mostrar = r.status == TransactionRequestStatus.enPreparacion ||
        r.hasProveedorFactura;
    if (!mostrar) return const SizedBox.shrink();

    final soloLectura = r.status != TransactionRequestStatus.enPreparacion;
    final facturaConfirmadaPorMotoLink = r.hasFacturaAliado;
    final puedeEditarFactura = !soloLectura && !facturaConfirmadaPorMotoLink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          soloLectura ? 'Factura digital (referencia)' : 'Factura digital',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        if (soloLectura)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Archivo confirmado · solo consulta (visible aunque el pedido ya esté entregado).',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
          )
        else
          Text(
            facturaConfirmadaPorMotoLink
                ? 'Factura confirmada por MotoLink. Ya no se puede reemplazar en esta orden.'
                : 'MotoLink usará este archivo como referencia para emitir la factura al aliado a nombre de MotoLink.',
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
          OutlinedButton.icon(
            onPressed: () => _abrirFactura(context),
            icon: const Icon(Icons.open_in_new_outlined, size: 18),
            label: const Text('Ver / descargar factura'),
          ),
        ],
        if (!soloLectura) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy || !puedeEditarFactura
                  ? null
                  : () => _pickAndUpload(context),
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
                      !puedeEditarFactura
                          ? 'Factura confirmada por MotoLink'
                          : r.hasProveedorFactura
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
      ],
    );
  }
}

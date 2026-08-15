import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_payment_flow_copy.dart';

/// Factura del proveedor (PDF o imagen).
class ImporterOrderInvoiceSection extends StatefulWidget {
  const ImporterOrderInvoiceSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.hideMajorTitle = false,
    /// Junto a [hideMajorTitle] en carritos multi-línea: evita repetir el párrafo largo en cada línea.
    this.useCompactHelp = false,
    /// Mismo carrito (`checkout_group_id`): una factura para todas las líneas; debe incluir [request].
    this.invoiceBundleLines,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final bool hideMajorTitle;
  final bool useCompactHelp;
  final List<TransactionRequestModel>? invoiceBundleLines;

  @override
  State<ImporterOrderInvoiceSection> createState() =>
      _ImporterOrderInvoiceSectionState();
}

class _ImporterOrderInvoiceSectionState
    extends State<ImporterOrderInvoiceSection> {
  bool _busy = false;

  bool _statusPermiteFacturaProveedor(TransactionRequestModel r) {
    return r.status == TransactionRequestStatus.pendiente ||
        r.status == TransactionRequestStatus.enPreparacion ||
        r.status == TransactionRequestStatus.pedidoListo;
  }

  TransactionRequestModel get _filaFacturaVisual {
    final b = widget.invoiceBundleLines;
    if (b == null || b.length <= 1) return widget.request;
    for (final r in b) {
      if (r.hasProveedorFactura) return r;
    }
    return widget.request;
  }

  bool get _unArchivoVariasLineas =>
      widget.invoiceBundleLines != null &&
      widget.invoiceBundleLines!.length > 1;

  bool get _algunaLineaConFactura {
    final b = widget.invoiceBundleLines;
    if (b == null || b.length <= 1) return widget.request.hasProveedorFactura;
    return b.any((r) => r.hasProveedorFactura);
  }

  bool get _todasLineasEditablesFactura {
    final b = widget.invoiceBundleLines;
    if (b == null || b.length <= 1) {
      return _statusPermiteFacturaProveedor(widget.request);
    }
    return b.every(_statusPermiteFacturaProveedor);
  }

  Future<void> _abrirFactura(BuildContext context) async {
    final path = _filaFacturaVisual.proveedorFacturaStoragePath?.trim();
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

  Future<void> _pickAndUploadProveedor(BuildContext context) async {
    final r = widget.request;
    final okStatus = _todasLineasEditablesFactura;
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
      final bundle = widget.invoiceBundleLines;
      if (bundle != null && bundle.length > 1) {
        await SupabaseService.importerSubmitMotoconectaProveedorFacturaBundle(
          transactionRequestIds: bundle.map((e) => e.id).toList(),
          bytes: bytes,
          fileName: name,
        );
      } else {
        await SupabaseService.importerSubmitMotoconectaProveedorFactura(
          transactionRequestId: r.id,
          bytes: bytes,
          fileName: name,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(OrderPaymentFlowCopy.importadorFacturaExito),
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
    final editable = _todasLineasEditablesFactura;
    if (!editable && !_algunaLineaConFactura) {
      return const SizedBox.shrink();
    }
    final soloLectura = !editable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hideMajorTitle) ...[
          Text(
            soloLectura
                ? OrderPaymentFlowCopy.importadorFacturaTituloReferencia
                : OrderPaymentFlowCopy.importadorFacturaTitulo,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          soloLectura
              ? OrderPaymentFlowCopy.importadorFacturaSoloLectura
              : (_unArchivoVariasLineas
                  ? OrderPaymentFlowCopy.importadorFacturaAyudaCarrito
                  : (widget.useCompactHelp
                      ? OrderPaymentFlowCopy.importadorFacturaAyudaCompacta
                      : OrderPaymentFlowCopy.importadorFacturaAyuda)),
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (_algunaLineaConFactura) ...[
          Text(
            _filaFacturaVisual.proveedorFacturaFileName?.trim().isNotEmpty == true
                ? 'Archivo: ${_filaFacturaVisual.proveedorFacturaFileName}'
                : OrderPaymentFlowCopy.importadorFacturaRegistrada,
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          Text(
            'Fecha: ${formatEsShortDateTime(_filaFacturaVisual.proveedorFacturaSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
              onPressed: _busy ? null : () => _pickAndUploadProveedor(context),
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
                      _algunaLineaConFactura
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
}

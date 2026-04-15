import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura MotoLink, método de pago y comprobante (pedido en preparación).
class AliadoOrderPagoSection extends StatefulWidget {
  const AliadoOrderPagoSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<AliadoOrderPagoSection> createState() => _AliadoOrderPagoSectionState();
}

class _AliadoOrderPagoSectionState extends State<AliadoOrderPagoSection> {
  String? _metodoSeleccionado;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final m = widget.request.pagoMetodo?.trim();
    _metodoSeleccionado =
        (m != null && m.isNotEmpty && PagoMetodo.values.contains(m)) ? m : PagoMetodo.pagoMovil;
  }

  @override
  void didUpdateWidget(covariant AliadoOrderPagoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      final m = widget.request.pagoMetodo?.trim();
      _metodoSeleccionado =
          (m != null && m.isNotEmpty && PagoMetodo.values.contains(m)) ? m : PagoMetodo.pagoMovil;
    }
  }

  Future<void> _abrirFactura(BuildContext context) async {
    final path = widget.request.facturaAliadoStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForFacturaAliado(path);
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

  Future<void> _abrirComprobante(BuildContext context) async {
    final path = widget.request.comprobantePagoStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForComprobantePago(path);
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

  Future<void> _subirComprobante(BuildContext context) async {
    final r = widget.request;
    final metodo = _metodoSeleccionado;
    if (metodo == null || !PagoMetodo.values.contains(metodo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago.')),
      );
      return;
    }

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
      await SupabaseService.aliadoSubmitComprobantePago(
        transactionRequestId: r.id,
        metodo: metodo,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante enviado. MotoLink lo revisará.'),
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

    final pe = r.pagoEstadoRevisionEfectivo;
    final puedeEnviarComprobante =
        r.hasFacturaAliado &&
            (pe == PagoRevisionEstado.pendiente || pe == PagoRevisionEstado.rechazado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Factura y pago',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        if (r.aliadoPagoEstadoResumenEs != null)
          Text(
            r.aliadoPagoEstadoResumenEs!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue.withOpacity(0.95),
              height: 1.25,
            ),
          ),
        const SizedBox(height: 8),
        if (r.hasFacturaAliado) ...[
          Text(
            'Factura MotoLink: ${r.facturaAliadoFileName ?? 'documento'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Text(
            'Emitida: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _abrirFactura(context),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Ver / descargar factura'),
          ),
        ] else
          Text(
            'Cuando MotoLink emita la factura oficial, podrá descargarla aquí y continuar con el pago.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.25),
          ),
        if (r.hasFacturaAliado) ...[
          const SizedBox(height: 14),
          const Text(
            'Método de pago',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _metodoSeleccionado,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: PagoMetodo.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(PagoMetodo.labelEs(c)),
                  ),
                )
                .toList(),
            onChanged: puedeEnviarComprobante
                ? (v) => setState(() => _metodoSeleccionado = v)
                : null,
          ),
          if (r.hasComprobantePago) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _abrirComprobante(context),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Ver mi comprobante'),
            ),
          ],
          if (puedeEnviarComprobante) ...[
            const SizedBox(height: 10),
            Text(
              'Adjunte una foto clara del comprobante (Pago Móvil, Zelle o transferencia).',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : () => _subirComprobante(context),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        r.hasComprobantePago &&
                                (pe == PagoRevisionEstado.rechazado)
                            ? 'Enviar nuevo comprobante'
                            : 'Adjuntar comprobante de pago',
                      ),
              ),
            ),
          ],
          if (pe == PagoRevisionEstado.enRevision)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Su comprobante está en revisión. MotoLink le avisará al aprobarlo.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
          if (pe == PagoRevisionEstado.aprobado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pago confirmado. MotoLink marcará pronto el envío en tránsito.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          if (pe == PagoRevisionEstado.rechazado &&
              r.pagoComprobanteRechazoNota != null &&
              r.pagoComprobanteRechazoNota!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'MotoLink: ${r.pagoComprobanteRechazoNota}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade900, height: 1.3),
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

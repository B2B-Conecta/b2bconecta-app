import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Importador: revisión del comprobante de pago del flete (transporte pago separado).
class ImporterOrderFleteComprobanteSection extends StatefulWidget {
  const ImporterOrderFleteComprobanteSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<ImporterOrderFleteComprobanteSection> createState() =>
      _ImporterOrderFleteComprobanteSectionState();
}

class _ImporterOrderFleteComprobanteSectionState
    extends State<ImporterOrderFleteComprobanteSection> {
  bool _busy = false;

  bool get _visible =>
      widget.request.carrierFletePagoSeparado &&
      widget.request.hasImporterCarrierSelected &&
      widget.request.hasFleteFactura;

  Future<void> _abrirComprobante(BuildContext context) async {
    final path = widget.request.fleteComprobantePagoStoragePath?.trim();
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

  Future<void> _setEstado(BuildContext context, String estado) async {
    String? nota;
    if (estado == PagoRevisionEstado.rechazado) {
      final ctrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar comprobante del flete'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      nota = ctrl.text.trim();
      ctrl.dispose();
      if (confirmed != true || !context.mounted) return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.importadorSetFletePagoRevisionEstado(
        transactionRequestId: widget.request.id,
        nuevoEstado: estado,
        rechazoNota: nota,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estado == PagoRevisionEstado.aprobado
                ? 'Pago del flete acreditado.'
                : 'Comprobante del flete rechazado.',
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

  static String _etiquetaEstado(String pe) {
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pendiente';
      case PagoRevisionEstado.enRevision:
        return 'Por revisar';
      case PagoRevisionEstado.aprobado:
        return 'Acreditado';
      case PagoRevisionEstado.rechazado:
        return 'Rechazado';
      default:
        return pe;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final r = widget.request;
    final carrier = r.carrierDisplayCompanyName?.trim();
    final pe = r.fletePagoEstadoRevisionEfectivo;
    final puedeConfirmar = r.status != TransactionRequestStatus.rechazado &&
        pe == PagoRevisionEstado.enRevision &&
        r.hasFleteComprobantePago;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Comprobante de pago del flete',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          carrier != null && carrier.isNotEmpty
              ? 'Pago del aliado al transportista $carrier.'
              : 'Pago del aliado al transportista.',
          style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (!r.hasFleteComprobantePago)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_top_outlined,
                    size: 20, color: Colors.amber.shade900),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'El aliado aún no registra el comprobante del pago del flete.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (r.fletePagoMetodo != null && r.fletePagoMetodo!.trim().isNotEmpty)
            Text(
              'Método: ${PagoMetodo.labelEs(r.fletePagoMetodo!)}',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          if (r.fleteComprobantePagoFileName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              'Archivo: ${r.fleteComprobantePagoFileName}',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ],
          if (r.fleteComprobanteSubmittedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'Recibido: ${formatEsShortDateTime(r.fleteComprobanteSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Estado: ${_etiquetaEstado(pe)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
          if (pe == PagoRevisionEstado.rechazado &&
              r.fleteComprobanteRechazoNota != null &&
              r.fleteComprobanteRechazoNota!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Motivo del rechazo: ${r.fleteComprobanteRechazoNota}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade800,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _abrirComprobante(context),
            icon: const Icon(Icons.open_in_new_outlined, size: 18),
            label: const Text('Ver comprobante del flete'),
          ),
          if (puedeConfirmar) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _setEstado(context, PagoRevisionEstado.aprobado),
                    child: const Text('Confirmar pago del flete'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _setEstado(context, PagoRevisionEstado.rechazado),
                    child: const Text('Rechazar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

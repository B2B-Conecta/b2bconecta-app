import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Verificación del comprobante declarado por el aliado (Zelle, Pago Móvil, Binance, transferencia).
class ImporterOrderPagoVerificationSection extends StatefulWidget {
  const ImporterOrderPagoVerificationSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  @override
  State<ImporterOrderPagoVerificationSection> createState() =>
      _ImporterOrderPagoVerificationSectionState();
}

class _ImporterOrderPagoVerificationSectionState
    extends State<ImporterOrderPagoVerificationSection> {
  bool _busy = false;

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

  Future<void> _setEstado(BuildContext context, String estado) async {
    final r = widget.request;
    String? nota;
    if (estado == PagoRevisionEstado.rechazado) {
      final ctrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar comprobante'),
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
      await SupabaseService.importadorSetPagoRevisionEstado(
        transactionRequestId: r.id,
        nuevoEstado: estado,
        rechazoNota: nota,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estado == PagoRevisionEstado.aprobado
                ? 'Pago acreditado confirmado.'
                : 'Comprobante rechazado.',
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
    final r = widget.request;
    final pe = r.pagoEstadoRevisionEfectivo;
    final mostrarAcciones = r.status != TransactionRequestStatus.rechazado &&
        r.hasComprobantePago &&
        pe == PagoRevisionEstado.enRevision;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pago del aliado',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
                ? 'Método declarado: ${PagoMetodo.labelEs(r.pagoMetodo!)}'
                : 'Método declarado: —',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          if (r.comprobantePagoSubmittedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Registrado: ${formatEsShortDateTime(r.comprobantePagoSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
              r.pagoComprobanteRechazoNota != null &&
              r.pagoComprobanteRechazoNota!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Motivo del rechazo: ${r.pagoComprobanteRechazoNota}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade800,
                height: 1.3,
              ),
            ),
          ],
          if (r.hasComprobantePago) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _abrirComprobante(context),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Ver comprobante'),
            ),
          ],
          if (mostrarAcciones) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _setEstado(context, PagoRevisionEstado.aprobado),
                    child: const Text('Confirmar pago recibido'),
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
          if (!r.hasComprobantePago)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'El aliado puede declarar método y adjuntar comprobante desde su ficha del pedido.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}

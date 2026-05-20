import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

String _adminEstadoPagoLabelEs(TransactionRequestModel r) {
  final pe = r.pagoEstadoRevisionEfectivo;
  final m = r.pagoMetodo?.trim();
  final efectivo = m == PagoMetodo.efectivo;

  switch (pe) {
    case PagoRevisionEstado.pendiente:
      return efectivo
          ? 'Pendiente de comprobante de efectivo del aliado'
          : 'Pendiente de comprobante del aliado';
    case PagoRevisionEstado.enRevision:
      if (efectivo && !r.hasComprobantePago) {
        return 'Pago en efectivo en revisión';
      }
      return 'Comprobante en revisión';
    case PagoRevisionEstado.aprobado:
      return efectivo ? 'Pago en efectivo aprobado' : 'Pago aprobado';
    case PagoRevisionEstado.rechazado:
      return efectivo
          ? 'Comprobante de efectivo rechazado (aliado puede reenviar)'
          : 'Comprobante rechazado (aliado puede reenviar)';
    default:
      return pe;
  }
}

/// Revisión del pago del aliado (comprobante / efectivo): ver archivo y aprobar o rechazar.
/// Aplica en cualquier fase operativa con factura MotoLink al aliado; el RPC admite hasta `entregado`.
class AdminPagoRevisionSection extends StatefulWidget {
  const AdminPagoRevisionSection({
    super.key,
    required this.request,
    required this.onRefresh,
    this.highlightEntregadoPagado = false,
    this.includeSectionTitle = true,
  });

  final TransactionRequestModel request;
  final VoidCallback onRefresh;

  /// Si el pedido ya está entregado y el pago fue aprobado, muestra un cierre explícito “entregado · pagado”.
  final bool highlightEntregadoPagado;

  /// En “En preparación” el título `Pago del aliado` va arriba junto al aviso si aún no hay factura.
  final bool includeSectionTitle;

  static String estadoPagoLabelEs(TransactionRequestModel r) =>
      _adminEstadoPagoLabelEs(r);

  @override
  State<AdminPagoRevisionSection> createState() =>
      _AdminPagoRevisionSectionState();
}

class _AdminPagoRevisionSectionState extends State<AdminPagoRevisionSection> {
  bool _busyAprobar = false;
  bool _busyRechazar = false;

  Future<void> _openUrl(
    BuildContext context,
    Future<String> Function() signed,
  ) async {
    try {
      final url = await signed();
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _aprobarPago(BuildContext context) async {
    setState(() => _busyAprobar = true);
    try {
      await SupabaseService.adminAprobarPagoAliado(widget.request.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago del aliado aprobado.')),
      );
      widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyAprobar = false);
    }
  }

  Future<void> _rechazarPago(BuildContext context) async {
    final ctrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar comprobante'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Motivo opcional; puede enviar otro comprobante.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo / indicaciones',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
      if (ok != true || !context.mounted) return;

      final nota = ctrl.text;
      setState(() => _busyRechazar = true);
      try {
        await SupabaseService.adminRechazarComprobantePago(
          requestId: widget.request.id,
          nota: nota,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comprobante rechazado.')),
        );
        widget.onRefresh();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        if (mounted) setState(() => _busyRechazar = false);
      }
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (!r.hasFacturaAliado) return const SizedBox.shrink();

    final pe = r.pagoEstadoRevisionEfectivo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.includeSectionTitle) ...[
          const Text(
            'Pago del aliado',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Estado: ${_adminEstadoPagoLabelEs(r)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brandBlue,
          ),
        ),
        if (widget.highlightEntregadoPagado &&
            pe == PagoRevisionEstado.aprobado &&
            r.status == TransactionRequestStatus.entregado) ...[
          const SizedBox(height: 8),
          Material(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pedido entregado y pagado.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty)
          Text(
            'Método declarado: ${PagoMetodo.labelEs(r.pagoMetodo!)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        if (r.hasComprobantePago) ...[
          Text(
            'Comprobante: ${r.comprobantePagoFileName ?? 'archivo'} · '
            '${formatEsShortDateTime(r.comprobantePagoSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _openUrl(
              context,
              () => SupabaseService.createSignedUrlForComprobantePago(
                r.comprobantePagoStoragePath!.trim(),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Ver comprobante'),
          ),
        ],
        if (r.pagoComprobanteRechazoNota != null &&
            r.pagoComprobanteRechazoNota!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Último rechazo: ${r.pagoComprobanteRechazoNota}',
            style: TextStyle(fontSize: 11, color: Colors.red.shade800, height: 1.25),
          ),
        ],
        if (pe == PagoRevisionEstado.enRevision) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busyAprobar ? null : () => _aprobarPago(context),
                child: _busyAprobar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Aprobar pago'),
              ),
              OutlinedButton(
                onPressed: _busyRechazar ? null : () => _rechazarPago(context),
                child: _busyRechazar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Rechazar comprobante'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import 'efectivo_respaldo_registrar.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// En preparación: factura proveedor, factura MotoLink al aliado, pago y paso a tránsito.
class AdminOrderPreTransitSection extends StatefulWidget {
  const AdminOrderPreTransitSection({
    super.key,
    required this.request,
    required this.onRefresh,
    required this.onMarcarEnTransito,
  });

  final TransactionRequestModel request;
  final VoidCallback onRefresh;
  final VoidCallback onMarcarEnTransito;

  @override
  State<AdminOrderPreTransitSection> createState() =>
      _AdminOrderPreTransitSectionState();
}

class _AdminOrderPreTransitSectionState extends State<AdminOrderPreTransitSection> {
  bool _busyFacturaAliado = false;
  bool _busyAprobar = false;
  bool _busyRechazar = false;

  Future<void> _openUrl(BuildContext context, Future<String> Function() signed) async {
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

  Future<void> _pickFacturaAliado(BuildContext context) async {
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
    if (bytes == null || bytes.isEmpty || name.isEmpty) return;

    setState(() => _busyFacturaAliado = true);
    try {
      await SupabaseService.adminSubmitFacturaAliadoOrder(
        transactionRequestId: r.id,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura oficial al aliado registrada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyFacturaAliado = false);
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
    final esCredito =
        widget.request.pagoMetodo?.trim() == PagoMetodo.creditoSistema;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            esCredito
                ? 'Rechazar solicitud de crédito'
                : 'Rechazar comprobante',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                esCredito
                    ? 'Indique al aliado el motivo (opcional). Podrá solicitar de nuevo el pago con crédito.'
                    : 'Indique al aliado qué corregir (opcional). Podrá enviar otro comprobante.',
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
          SnackBar(
            content: Text(
              esCredito ? 'Solicitud rechazada.' : 'Comprobante rechazado.',
            ),
          ),
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
    if (r.status != TransactionRequestStatus.enPreparacion) {
      return const SizedBox.shrink();
    }

    final pe = r.pagoEstadoRevisionEfectivo;
    final puedeTransito =
        r.hasProveedorFactura && r.hasFacturaAliado;

    String? bloqueoTransito;
    if (!r.hasProveedorFactura) {
      bloqueoTransito = 'Falta factura del proveedor (importador).';
    } else if (!r.hasFacturaAliado) {
      bloqueoTransito = 'Adjunte la factura oficial al aliado.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        const Text(
          'Facturación y pago',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'El aliado solo puede enviar comprobante o declarar pago en la app tras la factura MotoLink al aliado; '
          'puede hacerlo en cualquier fase activa del pedido. En el cronograma de envío no figura como paso del ciclo. '
          'Marcar en tránsito solo exige factura del proveedor, factura MotoLink al aliado y ETA; el pago puede regularizarse antes o después.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
        ),
        const SizedBox(height: 12),
        Text(
          'Factura del proveedor (referencia interna)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (r.hasProveedorFactura)
          OutlinedButton.icon(
            onPressed: () => _openUrl(
              context,
              () => SupabaseService.createSignedUrlForOrderInvoice(
                r.proveedorFacturaStoragePath!.trim(),
              ),
            ),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(r.proveedorFacturaFileName ?? 'Abrir factura'),
          )
        else
          Text(
            'Pendiente: el importador debe adjuntar la factura en su pestaña Pedidos.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        const SizedBox(height: 14),
        Text(
          'Factura oficial al aliado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Referencia fiscal para el aliado; habilita en la app la sección de pago y comprobante.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        if (r.hasFacturaAliado) ...[
          Text(
            r.facturaAliadoFileName ?? 'Archivo',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Text(
            'Subida: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openUrl(
                  context,
                  () => SupabaseService.createSignedUrlForFacturaAliado(
                    r.facturaAliadoStoragePath!.trim(),
                  ),
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Abrir / descargar'),
              ),
              if (pe != PagoRevisionEstado.aprobado &&
                  pe != PagoRevisionEstado.enRevision)
                OutlinedButton(
                  onPressed: _busyFacturaAliado ? null : () => _pickFacturaAliado(context),
                  child: _busyFacturaAliado
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reemplazar factura'),
                ),
            ],
          ),
        ] else
          OutlinedButton(
            onPressed: !r.hasProveedorFactura || _busyFacturaAliado
                ? null
                : () => _pickFacturaAliado(context),
            child: _busyFacturaAliado
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Adjuntar factura oficial al aliado'),
          ),
        const SizedBox(height: 14),
        Text(
          'Pago del aliado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (!r.hasFacturaAliado)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Sin factura MotoLink al aliado: el aliado aún no puede enviar comprobante desde la app.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.25),
            ),
          ),
        Text(
          'Estado: ${_estadoPagoLabel(r)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brandBlue,
          ),
        ),
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
                    : Text(
                        r.pagoMetodo?.trim() == PagoMetodo.creditoSistema
                            ? 'Rechazar solicitud'
                            : 'Rechazar comprobante',
                      ),
              ),
            ],
          ),
        ],
        EfectivoRespaldoRegistrar(
          request: r,
          onRegistered: widget.onRefresh,
        ),
        const SizedBox(height: 14),
        Text(
          'Envío en tránsito',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        if (puedeTransito)
          FilledButton.icon(
            onPressed: widget.onMarcarEnTransito,
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Marcar en tránsito (ETA)'),
          )
        else
          Text(
            bloqueoTransito ?? 'Complete los pasos anteriores.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  static String _estadoPagoLabel(TransactionRequestModel r) {
    final pe = r.pagoEstadoRevisionEfectivo;
    final m = r.pagoMetodo?.trim();
    final efectivo = m == PagoMetodo.efectivo;
    final credito = m == PagoMetodo.creditoSistema;

    if (credito) {
      switch (pe) {
        case PagoRevisionEstado.pendiente:
          return 'Pendiente de solicitud de crédito del aliado';
        case PagoRevisionEstado.enRevision:
          return 'Solicitud de crédito en revisión';
        case PagoRevisionEstado.aprobado:
          return 'Pago con crédito del sistema aprobado';
        case PagoRevisionEstado.rechazado:
          return 'Solicitud de crédito rechazada (aliado puede reintentar)';
        default:
          return pe;
      }
    }

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
}

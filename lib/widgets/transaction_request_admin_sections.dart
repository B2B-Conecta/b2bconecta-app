import 'package:flutter/material.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Contacto B2B del aliado y del importador en un pedido.
class TransactionRequestPartiesContactSection extends StatelessWidget {
  const TransactionRequestPartiesContactSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contacto',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _PartyCard(
          icon: Icons.storefront_outlined,
          title: 'Aliado',
          businessName: request.aliadoBusinessName,
          rif: request.aliadoRif,
          phone: request.aliadoPhone,
        ),
        const SizedBox(height: 10),
        _PartyCard(
          icon: Icons.local_shipping_outlined,
          title: 'Importador',
          businessName: request.ownerBusinessName,
          rif: request.ownerRif,
          phone: request.ownerPhone,
        ),
      ],
    );
  }
}

/// Solo el aliado (vista importador en pedidos).
class TransactionRequestAliadoContactSection extends StatelessWidget {
  const TransactionRequestAliadoContactSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos del aliado',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _PartyCard(
          icon: Icons.storefront_outlined,
          title: 'Aliado',
          businessName: request.aliadoBusinessName,
          rif: request.aliadoRif,
          phone: request.aliadoPhone,
        ),
      ],
    );
  }
}

/// Solo importador (vista aliado en pedidos).
class TransactionRequestImporterContactSection extends StatelessWidget {
  const TransactionRequestImporterContactSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos del importador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _PartyCard(
          icon: Icons.local_shipping_outlined,
          title: 'Importador',
          businessName: request.ownerBusinessName,
          rif: request.ownerRif,
          phone: request.ownerPhone,
        ),
      ],
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.icon,
    required this.title,
    required this.businessName,
    required this.rif,
    required this.phone,
  });

  final IconData icon;
  final String title;
  final String? businessName;
  final String? rif;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.brandBlue),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              businessName?.trim().isNotEmpty == true
                  ? businessName!
                  : '—',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (rif != null && rif!.isNotEmpty)
              Text('RIF: $rif', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
            if (phone != null && phone!.isNotEmpty)
              Text('Tel: $phone', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}

/// Fechas por etapa del ciclo de envío.
class TransactionRequestLifecycleSection extends StatelessWidget {
  const TransactionRequestLifecycleSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ciclo del envío',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (r.status == TransactionRequestStatus.rechazado) ...[
          _TimelineRow(
            label: 'Solicitud registrada',
            value: formatEsShortDateTime(r.createdAt),
            isDone: r.createdAt != null,
          ),
          _TimelineRow(
            label: 'Rechazado (MotoLink)',
            value: formatEsShortDateTime(r.atRechazado),
            isDone: r.atRechazado != null,
            highlight: true,
          ),
        ] else ...[
          _TimelineRow(
            label: 'Solicitud registrada',
            value: formatEsShortDateTime(r.createdAt),
            isDone: r.createdAt != null,
          ),
          _TimelineRow(
            label: 'Aprobado por MotoLink',
            value: formatEsShortDateTime(r.atAprobadoAdmin),
            isDone: r.atAprobadoAdmin != null,
            mutedIfEmpty: r.status == TransactionRequestStatus.pendiente,
          ),
          _TimelineRow(
            label: 'En preparación (importador)',
            value: _prepValue(r),
            isDone: r.atEnPreparacion != null,
          ),
          _TimelineRow(
            label: 'Factura MotoLink al aliado',
            value: _facturaAliadoTimeline(r),
            isDone: r.hasFacturaAliado,
          ),
          _TimelineRow(
            label: 'Comprobante de pago',
            value: _comprobantePagoTimeline(r),
            isDone: r.hasComprobantePago,
          ),
          _TimelineRow(
            label: 'Pago aprobado (MotoLink)',
            value: formatEsShortDateTime(r.pagoAprobadoAt),
            isDone: r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado,
          ),
          _TimelineRow(
            label: 'En tránsito (MotoLink)',
            value: _transitoValue(r),
            isDone: r.atEnTransito != null,
          ),
          _TimelineRow(
            label: 'Entregado',
            value: formatEsShortDateTime(r.atEntregado),
            isDone: r.atEntregado != null,
            highlight: r.status == TransactionRequestStatus.entregado,
          ),
        ],
      ],
    );
  }

  static String _prepValue(TransactionRequestModel r) {
    final d = formatEsShortDateTime(r.atEnPreparacion);
    if (!r.hasProveedorFactura) return d;
    final fn = r.proveedorFacturaFileName?.trim();
    final extra = (fn != null && fn.isNotEmpty)
        ? '\nFactura digital: $fn'
        : '\nFactura digital enviada';
    final at = formatEsShortDateTime(r.proveedorFacturaSubmittedAt);
    final tail = at != '—' ? ' ($at)' : '';
    return '$d$extra$tail';
  }

  static String _transitoValue(TransactionRequestModel r) {
    final d = formatEsShortDateTime(r.atEnTransito);
    final eta = r.transitEtaResumenEs;
    if (eta == null) return d;
    return '$d\nEntrega estimada al aliado: $eta';
  }

  static String _facturaAliadoTimeline(TransactionRequestModel r) {
    if (!r.hasFacturaAliado) return '—';
    final fn = r.facturaAliadoFileName?.trim();
    final t = formatEsShortDateTime(r.facturaAliadoSubmittedAt);
    if (fn != null && fn.isNotEmpty) return '$fn\n$t';
    return t;
  }

  static String _comprobantePagoTimeline(TransactionRequestModel r) {
    final pr = r.pagoEstadoRevision?.trim();
    if (pr == PagoRevisionEstado.aprobado && !r.hasComprobantePago) {
      return 'Aprobado (ver fecha arriba)';
    }
    if (!r.hasComprobantePago) {
      if (r.hasFacturaAliado &&
          (pr == null ||
              pr.isEmpty ||
              pr == PagoRevisionEstado.pendiente ||
              pr == PagoRevisionEstado.rechazado)) {
        return 'Pendiente de envío por el aliado';
      }
      return '—';
    }
    final met = r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
        ? PagoMetodo.labelEs(r.pagoMetodo!)
        : 'Método —';
    return '$met · ${formatEsShortDateTime(r.comprobantePagoSubmittedAt)}';
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.value,
    required this.isDone,
    this.mutedIfEmpty = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool isDone;
  final bool mutedIfEmpty;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final empty = value == '—';
    final color = highlight
        ? Colors.green.shade800
        : (empty && mutedIfEmpty)
            ? Colors.grey.shade500
            : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isDone ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              size: 16,
              color: isDone ? Colors.green.shade700 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: empty ? Colors.grey.shade600 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

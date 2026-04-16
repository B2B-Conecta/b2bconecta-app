import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

Future<void> _launchSignedOrderDoc(
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

/// Enlaces firmados a facturas y comprobantes (MotoLink / admin): referencia durante y después del ciclo.
class TransactionRequestEvidenceDocumentsSection extends StatelessWidget {
  const TransactionRequestEvidenceDocumentsSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final chips = <Widget>[];

    if (r.hasProveedorFactura && r.proveedorFacturaStoragePath != null) {
      final path = r.proveedorFacturaStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForOrderInvoice(path),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(
            r.proveedorFacturaFileName?.trim().isNotEmpty == true
                ? 'Factura proveedor · ${r.proveedorFacturaFileName}'
                : 'Factura proveedor',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (r.hasFacturaAliado && r.facturaAliadoStoragePath != null) {
      final path = r.facturaAliadoStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForFacturaAliado(path),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(
            r.facturaAliadoFileName?.trim().isNotEmpty == true
                ? 'Factura MotoLink · ${r.facturaAliadoFileName}'
                : 'Factura MotoLink al aliado',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (r.hasComprobantePago && r.comprobantePagoStoragePath != null) {
      final path = r.comprobantePagoStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForComprobantePago(path),
          ),
          icon: const Icon(Icons.account_balance_outlined, size: 18),
          label: Text(
            r.comprobantePagoFileName?.trim().isNotEmpty == true
                ? 'Comprobante de pago · ${r.comprobantePagoFileName}'
                : 'Comprobante de pago',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    if (r.hasEfectivoRespaldo && r.efectivoRespaldoStoragePath != null) {
      final path = r.efectivoRespaldoStoragePath!.trim();
      chips.add(
        OutlinedButton.icon(
          onPressed: () => _launchSignedOrderDoc(
            context,
            () => SupabaseService.createSignedUrlForEfectivoRespaldo(path),
          ),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: Text(
            r.efectivoRespaldoFileName?.trim().isNotEmpty == true
                ? 'Respaldo efectivo · ${r.efectivoRespaldoFileName}'
                : 'Respaldo cobro en efectivo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documentación y evidencia',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Archivos del pedido (conservados al cerrar). Abrir con enlace temporal.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
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
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceTinted.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (r.status == TransactionRequestStatus.rechazado) ...[
                  _TimelineRow(
                    label: 'Solicitud registrada',
                    value: formatEsShortDateTime(r.createdAt),
                    isDone: r.createdAt != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
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
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Aprobado por MotoLink',
                    value: formatEsShortDateTime(r.atAprobadoAdmin),
                    isDone: r.atAprobadoAdmin != null,
                    mutedIfEmpty: r.status == TransactionRequestStatus.pendiente,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'En preparación (importador)',
                    value: _prepValue(r),
                    isDone: r.atEnPreparacion != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Factura MotoLink al aliado',
                    value: _facturaAliadoTimeline(r),
                    isDone: r.hasFacturaAliado,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Comprobante de pago',
                    value: _comprobantePagoTimeline(r),
                    isDone: _comprobantePagoHecho(r),
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Respaldo cobro en efectivo',
                    value: _efectivoRespaldoTimeline(r),
                    isDone: r.hasEfectivoRespaldo,
                    mutedIfEmpty: true,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Pago aprobado (MotoLink)',
                    value: formatEsShortDateTime(r.pagoAprobadoAt),
                    isDone:
                        r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'En tránsito (MotoLink)',
                    value: _transitoValue(r),
                    isDone: r.atEnTransito != null,
                  ),
                  Divider(height: 16, thickness: 0.5, color: Colors.grey.shade300),
                  _TimelineRow(
                    label: 'Entregado',
                    value: _entregadoTimeline(r),
                    isDone: r.atEntregado != null,
                    highlight: r.status == TransactionRequestStatus.entregado,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static bool _comprobantePagoHecho(TransactionRequestModel r) {
    if (r.hasComprobantePago) return true;
    final m = r.pagoMetodo?.trim();
    final sinArchivo =
        m == PagoMetodo.efectivo || m == PagoMetodo.creditoSistema;
    final aprobado =
        r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado;
    return sinArchivo && aprobado;
  }

  static String _entregadoTimeline(TransactionRequestModel r) {
    final d = formatEsShortDateTime(r.atEntregado);
    if (r.atEntregado == null) return '—';
    return '$d\nRecepción confirmada por el aliado en su taller';
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
    final metodo = r.pagoMetodo?.trim();
    final credito = metodo == PagoMetodo.creditoSistema;
    if (pr == PagoRevisionEstado.aprobado &&
        metodo == PagoMetodo.efectivo &&
        !r.hasComprobantePago) {
      return 'Pago en efectivo · sin comprobante bancario · '
          '${formatEsShortDateTime(r.pagoAprobadoAt)}';
    }
    if (pr == PagoRevisionEstado.aprobado &&
        credito &&
        !r.hasComprobantePago) {
      return 'Pago con crédito del sistema MotoLink · '
          '${formatEsShortDateTime(r.pagoAprobadoAt)}';
    }
    if (pr == PagoRevisionEstado.aprobado && !r.hasComprobantePago) {
      return 'Aprobado · ${formatEsShortDateTime(r.pagoAprobadoAt)}';
    }
    if (!r.hasComprobantePago) {
      if (credito && r.hasFacturaAliado) {
        if (pr == null ||
            pr.isEmpty ||
            pr == PagoRevisionEstado.pendiente) {
          return 'Pendiente: aliado debe solicitar pago con crédito';
        }
        if (pr == PagoRevisionEstado.enRevision) {
          return 'Solicitud de crédito en revisión por MotoLink';
        }
        if (pr == PagoRevisionEstado.rechazado) {
          return 'Solicitud rechazada · aliado puede reintentar';
        }
      }
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
    final fn = r.comprobantePagoFileName?.trim();
    final nameLine =
        fn != null && fn.isNotEmpty ? '$fn · ' : '';
    return '$nameLine$met · ${formatEsShortDateTime(r.comprobantePagoSubmittedAt)}';
  }

  static String _efectivoRespaldoTimeline(TransactionRequestModel r) {
    if (r.pagoMetodo?.trim() != PagoMetodo.efectivo) return '—';
    if (!r.hasEfectivoRespaldo) {
      final pagoAprobado =
          r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado;
      if (pagoAprobado || r.status == TransactionRequestStatus.enTransito) {
        return 'Pendiente por registrar (transportista o MotoLink)';
      }
      return '—';
    }
    final fn = r.efectivoRespaldoFileName?.trim();
    final t = formatEsShortDateTime(r.efectivoRespaldoSubmittedAt);
    if (fn != null && fn.isNotEmpty) return '$fn\n$t';
    return t;
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            isDone ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: isDone ? Colors.green.shade700 : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: empty ? Colors.grey.shade600 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

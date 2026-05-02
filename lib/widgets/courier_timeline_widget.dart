import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

String _enPreparacionSubtitle(
  TransactionRequestModel r, {
  AppHomeRole? viewerRole,
}) {
  if (viewerRole == AppHomeRole.importador) {
    final p = r.resumenProveedoresLineaTimeline;
    if (p != null && p.isNotEmpty) {
      return 'Preparación en su almacén · $p';
    }
    return 'Preparación en su almacén (pedido del aliado vía MotoLink)';
  }
  if (r.isMasterOrder && r.totalSubOrdersCount > 0) {
    final done = r.subOrdersEnPreparacionOrMoreCount;
    final total = r.totalSubOrdersCount;
    final names = r.resumenImportadoresEnPreparacionOrMore;
    if (done >= total) {
      if (names != null && names.isNotEmpty) {
        return 'Importadores: $done/$total marcaron En preparación · $names';
      }
      return 'Importadores: $done/$total marcaron En preparación';
    }
    if (names != null && names.isNotEmpty) {
      return 'Importadores: $done/$total marcaron En preparación · $names · faltan ${total - done}';
    }
    return 'Importadores: $done/$total marcaron En preparación · faltan ${total - done}';
  }
  final p = r.resumenProveedoresLineaTimeline;
  if (p != null && p.isNotEmpty) {
    return 'Importador: $p';
  }
  return 'Proveedor alistando mercancía';
}

String _enCaminoRecogidaSubtitle(TransactionRequestModel r) {
  if (r.status != TransactionRequestStatus.enTransito) {
    return 'En tránsito hacia el aliado';
  }
  if (r.isMasterOrder && r.subOrders.isNotEmpty) {
    final done = r.subOrdersRecogidasAlmacenCount;
    final total = r.subOrders.length;
    if (done >= total) {
      return 'Carga retirada en $total almacén(es) · ruta hacia el aliado';
    }
    if (done > 0) {
      return 'Retiro en almacén: $done/$total · pendiente confirmar en otros almacenes si aplica';
    }
    return 'Confirme en la app al retirar la carga en cada almacén importador';
  }
  if (r.transportistaRecogioAlmacenSimple) {
    return 'Mercancía retirada del importador · en ruta hacia el aliado';
  }
  return 'Confirme en la app al retirar la carga en el almacén del importador';
}

String _listoParaDespachoSubtitle(TransactionRequestModel r) {
  if (r.isMasterOrder && r.totalSubOrdersCount > 0) {
    final done = r.subOrdersListoOrMoreCount;
    final total = r.totalSubOrdersCount;
    final names = r.resumenImportadoresListoOrMore;
    if (done >= total) {
      if (names != null && names.isNotEmpty) {
        return 'Importadores: $done/$total listos para recolección · $names';
      }
      return 'Importadores: $done/$total listos para recolección';
    }
    if (names != null && names.isNotEmpty) {
      return 'Importadores: $done/$total listos para recolección · $names · faltan ${total - done}';
    }
    return 'Importadores: $done/$total listos para recolección · faltan ${total - done}';
  }
  return 'Listo para recolección (importador)';
}

/// Línea de tiempo visual estilo courier (FedEx/DHL) para el ciclo logístico del pedido.
class CourierTimelineWidget extends StatelessWidget {
  const CourierTimelineWidget({
    super.key,
    required this.request,
    this.compact = false,
    this.viewerRole,
  });

  final TransactionRequestModel request;
  final bool compact;

  /// Ajusta copy del paso «En preparación» (p. ej. importador prepara en su almacén).
  final AppHomeRole? viewerRole;

  Future<void> _openMaps(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de mapa no válido.')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    if (r.status == TransactionRequestStatus.rechazado) {
      return _rejectedCard(r);
    }

    final steps = <_CourierStep>[
      _CourierStep(
        icon: Icons.inventory_2_outlined,
        title: 'Recibido',
        subtitle: r.atAprobadoAdmin != null
            ? 'Validado por MotoLink'
            : 'Pendiente de validación MotoLink',
        at: r.atAprobadoAdmin ?? r.createdAt,
        done: r.atAprobadoAdmin != null,
        current: r.status == TransactionRequestStatus.pendiente,
      ),
      _CourierStep(
        icon: Icons.precision_manufacturing_outlined,
        title: 'En preparación',
        subtitle: _enPreparacionSubtitle(r, viewerRole: viewerRole),
        at: r.atEnPreparacion,
        done: r.atEnPreparacion != null,
        current: r.status == TransactionRequestStatus.enPreparacion,
      ),
      _CourierStep(
        icon: Icons.fact_check_outlined,
        title: 'Listo para despacho',
        subtitle: _listoParaDespachoSubtitle(r),
        at: r.atPedidoListo,
        done: r.atPedidoListo != null,
        current: r.status == TransactionRequestStatus.pedidoListo,
      ),
      _CourierStep(
        icon: Icons.local_shipping_outlined,
        title: 'En camino',
        subtitle: _enCaminoRecogidaSubtitle(r),
        at: r.atEnTransito,
        done: r.atEnTransito != null,
        current: r.status == TransactionRequestStatus.enTransito,
        trailing: r.status == TransactionRequestStatus.enTransito &&
                r.hasAdminRutaMapsUrl &&
                viewerRole != AppHomeRole.transportista
            ? TextButton.icon(
                onPressed: () => _openMaps(context, r.adminRutaMapsUrl!),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Ruta en Maps'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              )
            : null,
      ),
      _CourierStep(
        icon: Icons.home_work_outlined,
        title: 'Entregado',
        subtitle: 'Cierre en taller del aliado',
        at: r.atEntregado,
        done: r.atEntregado != null,
        current: r.status == TransactionRequestStatus.entregado,
      ),
    ];

    final headingSize = compact ? 12.5 : 13.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seguimiento del envío',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: headingSize,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14, compact ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressBar(steps: steps, compact: compact),
                SizedBox(height: compact ? 10 : 14),
                ...List.generate(steps.length, (i) {
                  final s = steps[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (i > 0) Divider(height: compact ? 12 : 16, color: Colors.grey.shade200),
                      _StepRow(
                        step: s,
                        compact: compact,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rejectedCard(TransactionRequestModel r) {
    final cancel = r.canceladoPorAliado;
    final m = r.aliadoCancelacionMotivo;
    final mAnula = r.motolinkAnulacionMotivo;
    final anulM = r.anuladoPorMotolink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seguimiento del envío',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        anulM
                            ? 'Pedido anulado por MotoLink · '
                                '${formatEsShortDateTime(r.atRechazado ?? r.updatedAt)}'
                            : (cancel
                                ? 'Solicitud cancelada · '
                                    '${formatEsShortDateTime(r.atRechazado ?? r.updatedAt)}'
                                : 'Pedido rechazado · '
                                    '${formatEsShortDateTime(r.atRechazado ?? r.updatedAt)}'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (anulM && mAnula != null && mAnula.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Motivo (MotoLink): $mAnula',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: Colors.red.shade900,
                    ),
                  ),
                ] else if (cancel && m != null && m.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Motivo registrado: $m',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CourierStep {
  const _CourierStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.done,
    required this.current,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime? at;
  final bool done;
  final bool current;
  final Widget? trailing;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.steps, required this.compact});

  final List<_CourierStep> steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final doneCount = steps.where((s) => s.done).length;
    final progress = steps.isEmpty ? 0.0 : doneCount / steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: compact ? 5 : 7,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.brand,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: steps.map((s) {
            final color = s.done
                ? AppColors.brand
                : (s.current ? AppColors.brandBlue : Colors.grey.shade400);
            return Icon(s.icon, size: compact ? 18 : 22, color: color);
          }).toList(),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.compact});

  final _CourierStep step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = step;
    final color = s.done
        ? AppColors.brand
        : (s.current ? AppColors.brandBlue : Colors.grey.shade400);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Icon(s.icon, size: compact ? 16 : 18, color: color),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12 : 13,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                s.subtitle,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: Colors.grey.shade700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.at != null ? formatEsShortDateTime(s.at) : '—',
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: s.done ? Colors.grey.shade800 : Colors.grey.shade500,
                ),
              ),
              if (s.trailing != null) ...[
                const SizedBox(height: 4),
                s.trailing!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

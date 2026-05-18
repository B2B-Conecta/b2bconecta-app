import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// «Recibido» se cierra al tomar el pedido en operación (en preparación o posterior).
bool _recibidoDoneMotoconecta(TransactionRequestModel r) {
  return r.atEnPreparacion != null ||
      r.status == TransactionRequestStatus.enPreparacion ||
      r.status == TransactionRequestStatus.pedidoListo ||
      r.status == TransactionRequestStatus.enTransito ||
      r.status == TransactionRequestStatus.enviado ||
      r.status == TransactionRequestStatus.entregado;
}

String _recibidoSubtitle(TransactionRequestModel r, {AppHomeRole? viewerRole}) {
  if (_recibidoDoneMotoconecta(r)) {
    if (viewerRole == AppHomeRole.importador) {
      return 'Importador confirmó el pedido al iniciar la preparación';
    }
    return 'El importador tomó el pedido y está en preparación.';
  }
  if (viewerRole == AppHomeRole.importador) {
    return 'Pedido nuevo en su bandeja · marque «En preparación» cuando confirme stock';
  }
  return 'Solicitud enviada · el importador confirmará y preparará el pedido.';
}

DateTime? _recibidoAt(TransactionRequestModel r) {
  if (_recibidoDoneMotoconecta(r)) {
    return r.atEnPreparacion ?? r.createdAt;
  }
  return r.createdAt;
}

bool _recibidoDone(TransactionRequestModel r) {
  return _recibidoDoneMotoconecta(r);
}

/// MotoConecta sin columnas `at_*` populadas: decide pasos completados según [TransactionRequestModel.status].
int _motoconectaTimelineRank(String status) {
  switch (status) {
    case TransactionRequestStatus.pendiente:
      return 0;
    case TransactionRequestStatus.enPreparacion:
      return 1;
    case TransactionRequestStatus.pedidoListo:
      return 2;
    case TransactionRequestStatus.enTransito:
    case TransactionRequestStatus.enviado:
      return 3;
    case TransactionRequestStatus.entregado:
      return 4;
    default:
      return 0;
  }
}

bool _pasoPreparacionHecho(TransactionRequestModel r) {
  if (r.atEnPreparacion != null) return true;
  return _motoconectaTimelineRank(r.status) >= 2;
}

bool _pasoListoHecho(TransactionRequestModel r) {
  if (r.atPedidoListo != null) return true;
  return _motoconectaTimelineRank(r.status) >= 3;
}

bool _pasoEnCaminoHecho(TransactionRequestModel r) {
  if (r.atEnTransito != null) return true;
  return _motoconectaTimelineRank(r.status) >= 4;
}

bool _pasoEntregadoHecho(TransactionRequestModel r) {
  if (r.atEntregado != null) return true;
  return r.status == TransactionRequestStatus.entregado;
}

/// Barra superior: avance por fase actual (en preparación ≈ 40 %), no solo pasos con `done`.
double _timelineBarProgress(TransactionRequestModel r) {
  if (r.status == TransactionRequestStatus.rechazado) return 0;
  final rank = _motoconectaTimelineRank(r.status);
  return (rank.clamp(0, 4) + 1) / 5.0;
}

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
  final enRuta = r.status == TransactionRequestStatus.enTransito ||
      r.status == TransactionRequestStatus.enviado;
  if (!enRuta) {
    return 'Avance cuando el importador marque «En tránsito» en Pedidos.';
  }
  if (r.isMasterOrder && r.subOrders.isNotEmpty) {
    final done = r.subOrdersListoOrMoreCount;
    final total = r.subOrders.length;
    if (done >= total) {
      return 'Importadores en despacho · en camino hacia su taller';
    }
    return 'Importadores: $done/$total en tránsito · faltan ${total - done}';
  }
  return 'El importador despachó la mercancía hacia su taller';
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
  return 'Listo para despacho; adjunte factura si aún no lo hizo antes de marcar en tránsito.';
}

/// Línea de tiempo visual estilo courier (FedEx/DHL) para el ciclo logístico del pedido.
class CourierTimelineWidget extends StatelessWidget {
  const CourierTimelineWidget({
    super.key,
    required this.request,
    this.compact = false,
    this.viewerRole,
    /// En listados con varias líneas, mostrar el título solo en la primera instancia del widget.
    this.showHeading = true,
  });

  final TransactionRequestModel request;
  final bool compact;

  /// Ajusta copy del paso «En preparación» (p. ej. importador prepara en su almacén).
  final AppHomeRole? viewerRole;

  /// Si es false, no se muestra el rótulo «Seguimiento del envío» (evita duplicados en el mismo panel).
  final bool showHeading;

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
      return _rejectedCard(r, showHeading: showHeading);
    }

    final steps = <_CourierStep>[
      _CourierStep(
        icon: Icons.inventory_2_outlined,
        title: 'Recibido',
        subtitle: _recibidoSubtitle(r, viewerRole: viewerRole),
        at: _recibidoAt(r),
        done: _recibidoDone(r),
        current: r.status == TransactionRequestStatus.pendiente,
      ),
      _CourierStep(
        icon: Icons.precision_manufacturing_outlined,
        title: 'En preparación',
        subtitle: _enPreparacionSubtitle(r, viewerRole: viewerRole),
        at: r.atEnPreparacion,
        done: _pasoPreparacionHecho(r),
        current: r.status == TransactionRequestStatus.enPreparacion,
      ),
      _CourierStep(
        icon: Icons.fact_check_outlined,
        title: 'Listo para despacho',
        subtitle: _listoParaDespachoSubtitle(r),
        at: r.atPedidoListo,
        done: _pasoListoHecho(r),
        current: r.status == TransactionRequestStatus.pedidoListo,
      ),
      _CourierStep(
        icon: Icons.local_shipping_outlined,
        title: 'En camino',
        subtitle: _enCaminoRecogidaSubtitle(r),
        at: r.atEnTransito,
        done: _pasoEnCaminoHecho(r),
        current: r.status == TransactionRequestStatus.enTransito ||
            r.status == TransactionRequestStatus.enviado,
        trailing: r.status == TransactionRequestStatus.enTransito &&
                r.hasAdminRutaMapsUrl
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
        done: _pasoEntregadoHecho(r),
        current: r.status == TransactionRequestStatus.entregado,
      ),
    ];

    final barProgress = _timelineBarProgress(r);

    final headingSize = compact ? 12.5 : 13.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'Seguimiento del envío',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: headingSize,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
        ],
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
                _ProgressBar(
                  steps: steps,
                  compact: compact,
                  progressValue: barProgress,
                ),
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

  Widget _rejectedCard(TransactionRequestModel r, {required bool showHeading}) {
    final cancel = r.canceladoPorAliado;
    final m = r.aliadoCancelacionMotivo;
    final mAnula = r.motolinkAnulacionMotivo;
    final anulM = r.anuladoPorMotolink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          const Text(
            'Seguimiento del envío',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
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
  const _ProgressBar({
    required this.steps,
    required this.compact,
    required this.progressValue,
  });

  final List<_CourierStep> steps;
  final bool compact;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    final progress = progressValue.clamp(0.0, 1.0);

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 12 : 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (s.done)
                    Icon(
                      Icons.check_circle,
                      size: compact ? 17 : 19,
                      color: AppColors.brand,
                    ),
                ],
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

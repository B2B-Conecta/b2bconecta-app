import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/admin_order_panel_utils.dart';
import 'admin_checkout_group_master_header.dart';
import 'courier_timeline_widget.dart';
import 'moroso_order_visual.dart';
import 'order_card_collapsible_layout.dart';
import 'order_commission_summary.dart';
import 'importer_aliado_solicitud_section.dart';
import 'transaction_request_admin_sections.dart';

/// Ficha compacta admin: una línea o carrito completo (`checkout_group_id`).
class AdminExpandableOrderCard extends StatelessWidget {
  const AdminExpandableOrderCard({
    super.key,
    required this.request,
    this.checkoutGroupLines,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.expandedFooter,
    this.onRequestMutated,
  });

  final TransactionRequestModel request;
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  final Widget? expandedFooter;
  final VoidCallback? onRequestMutated;

  @override
  Widget build(BuildContext context) {
    final lines = (checkoutGroupLines != null && checkoutGroupLines!.isNotEmpty)
        ? checkoutGroupLines!
        : <TransactionRequestModel>[request];
    final isCheckoutGroup = lines.length > 1;
    final r = request;
    final groupMoroso = adminCheckoutGroupEsMoroso(lines);
    final importerCount = isCheckoutGroup
        ? lines.map((e) => e.ownerId.trim()).where((s) => s.isNotEmpty).toSet().length
        : 0;

    final titulo = isCheckoutGroup
        ? (expanded
            ? 'Carrito · ${lines.length} líneas'
                '${importerCount > 1 ? ' · $importerCount importadores' : ''}'
            : adminCheckoutGroupTitle(lines))
        : r.tituloFichaPrincipalPedido;
    final resumen = isCheckoutGroup
        ? adminCheckoutGroupResumenLinea(lines)
        : '${r.totalUnidadesAliado} uds · Total (aliado) '
            '${r.precioTotal.toStringAsFixed(2)} REF';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  titulo,
                                  maxLines: expanded ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              OrderStatusHeaderChips(
                                statusLabel: statusLabel,
                                showMoroso: groupMoroso,
                              ),
                            ],
                          ),
                          if (!expanded) ...[
                            if (isCheckoutGroup) ...[
                              const SizedBox(height: 4),
                              Text(
                                adminCheckoutGroupTitle(lines),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Carrito · ${lines.length} líneas'
                                '${importerCount > 1 ? ' · $importerCount importadores' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandBlue.withOpacity(0.9),
                                ),
                              ),
                            ] else if (r.productSku != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'SKU: ${r.productSku}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              resumen,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.destinoEntregaLineaCompactaEs,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.25,
                              ),
                            ),
                          ],
                          if (!expanded &&
                              r.status ==
                                  TransactionRequestStatus.pedidoListo) ...[
                            const SizedBox(height: 6),
                            OrderCardCompactNoticeChip(
                              label: 'Listo para recolección',
                              icon: Icons.notifications_active_outlined,
                              color: Colors.teal.shade900,
                            ),
                          ],
                          if (!expanded &&
                              !isCheckoutGroup &&
                              lines.every((x) => x.pedidoEntregadoYPagado)) ...[
                            const SizedBox(height: 6),
                            OrderCardCompactNoticeChip(
                              label: 'Entregado y pagado',
                              icon: Icons.check_circle_outline,
                              color: Colors.green.shade800,
                            ),
                          ] else if (!expanded && groupMoroso) ...[
                            const SizedBox(height: 8),
                            MorosoOrderCardNotice(
                              request: adminCheckoutGroupMorosoRef(lines),
                              expanded: false,
                              riskWarningChild: lines.any(
                                (x) => x.pagoPendienteRiesgoCuentaTresDiasHabiles,
                              )
                                  ? _RiesgoMorosoBanner()
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cerrar'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  if (isCheckoutGroup)
                    AdminCheckoutGroupMasterHeader(lines: lines)
                  else ...[
                    OrderCardCollapsibleSection(
                      title: 'Partes del pedido',
                      subtitle:
                          TransactionRequestPartiesContactSection.partiesSubtitle(
                        r,
                      ),
                      infoMessage:
                          'Aliado solicitante e importador proveedor del pedido.',
                      child: TransactionRequestPartiesContactSection(
                        request: r,
                        embedded: true,
                      ),
                    ),
                    const SizedBox(height: kOrderCardSectionGap),
                    OrderCardCollapsibleSection(
                      title: 'Entrega',
                      subtitle: r.destinoEntregaLineaCompactaEs,
                      child: TransactionRequestDestinoEntregaSection(
                        request: r,
                        hideSectionTitle: true,
                      ),
                    ),
                    const SizedBox(height: kOrderCardSectionGap),
                    OrderCardCollapsibleSection(
                      title: 'Productos',
                      subtitle: orderCardProductosSubtitle(
                        [r],
                        viewer: PedidoDesgloseViewer.importador,
                      ),
                      initiallyExpanded: true,
                      child: TransactionRequestProductosDesgloseSection(
                        lines: [r],
                        compact: true,
                        viewer: PedidoDesgloseViewer.importador,
                        hideSectionTitle: true,
                        showPrecioHelp: false,
                      ),
                    ),
                    if (orderCardCommissionSubtitle([r]) != null) ...[
                      const SizedBox(height: kOrderCardSectionGap),
                      OrderCardCollapsibleSection(
                        title: 'Comisión MotoLink',
                        subtitle: orderCardCommissionSubtitle([r]),
                        infoMessage:
                            'Comisión devengada o estimada según el estado del pedido.',
                        child: OrderCommissionSummary(
                          lines: orderLinesEligibleForCommission([r]),
                          suppressOuterTitle: true,
                        ),
                      ),
                    ],
                    if (r.aliadoExperienceSubmittedAt != null) ...[
                      const SizedBox(height: kOrderCardSectionGap),
                      OrderCardCollapsibleSection(
                        title: 'Valoración del aliado',
                        subtitle: r.aliadoExperienceStars != null
                            ? '${r.aliadoExperienceStars}/5 post-entrega'
                            : 'Comentario registrado',
                        child: TransactionRequestAliadoExperienceAdminSection(
                          request: r,
                          hideSectionTitle: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: kOrderCardSectionGap),
                    OrderCardCollapsibleSection(
                      title: 'Seguimiento',
                      subtitle: orderCardTimelineSubtitle(r),
                      initiallyExpanded:
                          orderCardTimelineInitiallyExpanded(r),
                      child: CourierTimelineWidget(
                        request: r,
                        compact: true,
                        viewerRole: AppHomeRole.administrador,
                        showHeading: false,
                      ),
                    ),
                  ],
                  if (expandedFooter != null) ...[
                    const SizedBox(height: 12),
                    expandedFooter!,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiesgoMorosoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        '>3 días hábiles sin pago: puede aplicarse restricción de cuenta.',
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Colors.red.shade900,
        ),
      ),
    );
  }
}

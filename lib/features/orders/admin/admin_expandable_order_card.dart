import 'package:motolink_pro_app/features/orders/shared/order_summary_header.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_eligibility.dart';
import 'admin_checkout_group_master_header.dart';
import 'package:motolink_pro_app/features/orders/shared/courier_timeline_widget.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_aliado_solicitud_section.dart';
import 'transaction_request_admin_sections.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';

/// Ficha compacta admin: una línea o carrito completo (`checkout_group_id`).
class AdminExpandableOrderCard extends StatelessWidget {
  const AdminExpandableOrderCard({
    super.key,
    required this.request,
    this.checkoutGroupLines,
    required this.expanded,
    this.highlighted = false,
    required this.onToggle,
    required this.statusLabel,
    this.expandedFooter,
    this.onRequestMutated,
  });

  final TransactionRequestModel request;
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;

  /// Fila elegida en el master-detail de escritorio.
  final bool highlighted;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      color: highlighted ? AppColors.brandBlueContainer : null,
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.brandAccent.withOpacity(0.7),
                width: 1.5,
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderSummaryHeader(
            lines: lines,
            viewerRole: AppHomeRole.administrador,
            expanded: expanded,
            onToggle: onToggle,
            statusLabel: statusLabel,
            onCancel: null,
            cancelBusy: false,
            chatAction: OrderChatIconButton(
              relatedOrderIds: lines.map((e) => e.id).toList(),
              onOpen: () {
                showOrderChatSheet(
                  context: context,
                  transactionRequestId: lines.first.id,
                  mergedThreadRequestIds:
                      isCheckoutGroup ? lines.map((e) => e.id).toList() : null,
                  orderLines: lines,
                  allowReplyAsAliado: false,
                  allowReplyAsAdmin: true,
                  title: 'Chat del pedido',
                  onThreadChanged: onRequestMutated,
                );
              },
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
                  const SizedBox(height: kOrderCardSectionGap),
                  if (isCheckoutGroup)
                    AdminCheckoutGroupMasterHeader(
                      lines: lines,
                      onMutated: onRequestMutated,
                    )
                  else ...[
                    OrderCardCollapsibleSection(
                      title: 'Partes del pedido',
                      subtitle: TransactionRequestPartiesContactSection
                          .partiesSubtitle(
                        r,
                      ),
                      infoMessage:
                          'Tienda minorista solicitante e importador proveedor del pedido.',
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
                      initiallyExpanded:
                          orderCardProductsInitiallyExpanded(r.status),
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
                        title: 'Comisión B2B Conecta',
                        subtitle: orderCardCommissionSubtitle([r]),
                        infoMessage:
                            'Comisión devengada o estimada según el estado del pedido.',
                        child: OrderCommissionSummary(
                          lines: orderLinesEligibleForCommission([r]),
                          suppressOuterTitle: true,
                        ),
                      ),
                    ],
                    if (r.aliadoExperienceSubmittedAt != null ||
                        lineaElegibleValoracionAliado(r)) ...[
                      const SizedBox(height: kOrderCardSectionGap),
                      OrderCardCollapsibleSection(
                        title: 'Valoración de la tienda minorista',
                        subtitle: r.aliadoExperienceStars != null
                            ? '${r.aliadoExperienceStars}/5 post-entrega'
                            : (r.aliadoExperienceSubmittedAt != null
                                ? 'Comentario registrado'
                                : 'Pendiente — admin puede registrar'),
                        child: TransactionRequestAliadoExperienceAdminSection(
                          request: r,
                          hideSectionTitle: true,
                          onMutated: onRequestMutated,
                        ),
                      ),
                    ],
                    if (lineaElegibleValoracionImportador(r) ||
                        r.aliadoExperienceSubmittedAt != null) ...[
                      const SizedBox(height: kOrderCardSectionGap),
                      OrderCardCollapsibleSection(
                        title: 'Valoración del mayorista',
                        subtitle: 'A la tienda minorista de este pedido',
                        child: TransactionRequestImporterRatingAdminSection(
                          request: r,
                          onMutated: onRequestMutated,
                        ),
                      ),
                    ],
                    const SizedBox(height: kOrderCardSectionGap),
                    OrderCardCollapsibleSection(
                      title: 'Seguimiento',
                      subtitle: orderCardTimelineSubtitle(r),
                      initiallyExpanded: orderCardTimelineInitiallyExpanded(r),
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

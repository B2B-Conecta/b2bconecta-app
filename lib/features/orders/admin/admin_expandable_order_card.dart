import 'package:motolink_pro_app/features/orders/shared/order_summary_header.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_eligibility.dart';
import 'admin_checkout_group_master_header.dart';
import 'package:motolink_pro_app/features/orders/shared/courier_timeline_widget.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_aliado_solicitud_section.dart';
import 'package:motolink_pro_app/features/orders/shared/order_delivery_stepper.dart';
import 'package:motolink_pro_app/features/orders/shared/order_detail_layout.dart';
import 'admin_recalc_tasa_bcv_button.dart';
import 'transaction_request_admin_sections.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';

/// Alias de producto del detalle de pedido admin (`/admin/orders/detail`).
typedef OrderDetailModule = AdminExpandableOrderCard;

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
    this.workspaceDetail = false,
  });

  final TransactionRequestModel request;
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;

  /// Fila elegida en el master-detail de escritorio.
  final bool highlighted;

  /// Detalle a pantalla completa vía [OrderWorkspace] (sin accordion).
  final bool workspaceDetail;
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
    final showBody = workspaceDetail || expanded;

    if (workspaceDetail) {
      return _buildWorkspaceDetail(
        context,
        lines: lines,
        isCheckoutGroup: isCheckoutGroup,
        r: r,
      );
    }

    final theme = B2BThemeExtension.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      color: highlighted ? theme.brandContainer : theme.surfaceCard,
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.brand.withOpacity(0.7),
                width: 1.5,
              ),
            )
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.borderSubtle),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderSummaryHeader(
            lines: lines,
            viewerRole: AppHomeRole.administrador,
            expanded: showBody,
            onToggle: onToggle,
            statusLabel: statusLabel,
            showToggle: true,
            detailSummary: false,
            onCancel: null,
            cancelBusy: false,
            chatAction: _chatButton(
              context,
              lines: lines,
              isCheckoutGroup: isCheckoutGroup,
              showLabel: false,
            ),
          ),
          if (showBody) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: kOrderCardSectionGap),
                  AdminRecalcTasaBcvButton(
                    lines: lines,
                    onDone: onRequestMutated,
                  ),
                  if (isCheckoutGroup)
                    AdminCheckoutGroupMasterHeader(
                      lines: lines,
                      onMutated: onRequestMutated,
                    )
                  else
                    ..._legacyAccordionSections(r),
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

  Widget _buildWorkspaceDetail(
    BuildContext context, {
    required List<TransactionRequestModel> lines,
    required bool isCheckoutGroup,
    required TransactionRequestModel r,
  }) {
    final theme = B2BThemeExtension.of(context);
    // Columna izq (~60%): timeline → pagos/gestión → productos.
    final tracking = OrderDetailSection(
      title: 'Seguimiento',
      icon: Icons.local_shipping_outlined,
      tonal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderDeliveryStepper(lines: lines),
          const SizedBox(height: 4),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: theme.borderSubtle),
            child: ExpansionTile(
              key: PageStorageKey('admin-history-${r.id}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 2),
              initiallyExpanded: false,
              title: Text(
                'Historial del envío',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CourierTimelineWidget(
                      request: line,
                      compact: true,
                      viewerRole: AppHomeRole.administrador,
                      showHeading: lines.length > 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final payments = OrderDetailSection(
      title: 'Pagos y gestión',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Estado del pago, comprobantes y acciones administrativas.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          AdminRecalcTasaBcvButton(
            lines: lines,
            onDone: onRequestMutated,
          ),
          if (expandedFooter != null) ...[
            const SizedBox(height: 8),
            expandedFooter!,
          ],
        ],
      ),
    );
    final products = OrderDetailSection(
      title: 'Productos / partidas',
      icon: Icons.shopping_bag_outlined,
      child: TransactionRequestProductosDesgloseSection(
        lines: lines,
        compact: false,
        viewer: PedidoDesgloseViewer.importador,
        hideSectionTitle: true,
        showPrecioHelp: false,
      ),
    );
    // Columna der (~40%): entrega, partes, comisión, valoraciones.
    final delivery = OrderDetailSection(
      title: 'Datos de entrega',
      icon: Icons.location_on_outlined,
      flat: true,
      child: TransactionRequestDestinoEntregaSection(
        request: lines.first,
        hideSectionTitle: true,
      ),
    );
    final parties = OrderDetailSection(
      title: 'Partes del pedido',
      icon: Icons.groups_outlined,
      flat: true,
      child: TransactionRequestPartiesContactSection(
        request: lines.first,
        embedded: true,
      ),
    );
    final commission = orderCardCommissionSubtitle(lines) == null
        ? null
        : OrderDetailSection(
            title: 'Comisión B2B',
            icon: Icons.receipt_long_outlined,
            child: OrderCommissionSummary(
              lines: orderLinesEligibleForCommission(lines),
              suppressOuterTitle: true,
            ),
          );
    final ratings = <Widget>[
      if (lines.any((l) =>
          l.aliadoExperienceSubmittedAt != null ||
          lineaElegibleValoracionAliado(l)))
        OrderDetailSection(
          title: 'Valoración tienda',
          icon: Icons.star_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in lines.where((l) =>
                  l.aliadoExperienceSubmittedAt != null ||
                  lineaElegibleValoracionAliado(l)))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionRequestAliadoExperienceAdminSection(
                    request: line,
                    hideSectionTitle: true,
                    onMutated: onRequestMutated,
                  ),
                ),
            ],
          ),
        ),
      if (lines.any((l) =>
          lineaElegibleValoracionImportador(l) ||
          l.aliadoExperienceSubmittedAt != null))
        OrderDetailSection(
          title: 'Valoración mayorista',
          icon: Icons.rate_review_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in lines.where((l) =>
                  lineaElegibleValoracionImportador(l) ||
                  l.aliadoExperienceSubmittedAt != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionRequestImporterRatingAdminSection(
                    request: line,
                    onMutated: onRequestMutated,
                  ),
                ),
            ],
          ),
        ),
    ];

    final primary = <Widget>[
      tracking,
      payments,
      products,
    ];
    final secondary = <Widget>[
      delivery,
      parties,
      if (commission != null) commission,
      ...ratings,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderSummaryHeader(
          lines: lines,
          viewerRole: AppHomeRole.administrador,
          expanded: true,
          onToggle: onToggle,
          statusLabel: statusLabel,
          showToggle: false,
          detailSummary: true,
          showRoutineGuidance: false,
          actionsInHeader: true,
          onCancel: null,
          cancelBusy: false,
          chatAction: _chatButton(
            context,
            lines: lines,
            isCheckoutGroup: isCheckoutGroup,
            showLabel: false,
          ),
        ),
        const SizedBox(height: 12),
        OrderDetailColumns(
          primary: primary,
          secondary: secondary,
          mobileOrder: [
            tracking,
            payments,
            products,
            delivery,
            parties,
            if (commission != null) commission,
            ...ratings,
          ],
        ),
      ],
    );
  }

  List<Widget> _legacyAccordionSections(TransactionRequestModel r) {
    return [
      OrderCardCollapsibleSection(
        title: 'Partes del pedido',
        subtitle: TransactionRequestPartiesContactSection.partiesSubtitle(r),
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
        initiallyExpanded: orderCardProductsInitiallyExpanded(r.status),
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
    ];
  }

  Widget _chatButton(
    BuildContext context, {
    required List<TransactionRequestModel> lines,
    required bool isCheckoutGroup,
    required bool showLabel,
  }) {
    return OrderChatIconButton(
      showLabel: showLabel,
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
    );
  }
}

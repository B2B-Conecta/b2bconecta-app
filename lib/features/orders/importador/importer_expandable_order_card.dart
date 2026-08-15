import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/orders/shared/courier_timeline_widget.dart';
import 'importer_aliado_solicitud_section.dart';
import 'importer_order_date_badge.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'package:motolink_pro_app/features/orders/shared/moroso_order_visual.dart';
import 'package:motolink_pro_app/features/orders/shared/order_motolink_thread_section.dart';
import 'package:motolink_pro_app/features/kyc/importer_kyc_approved_aliados_panel.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'package:motolink_pro_app/features/orders/admin/transaction_request_admin_sections.dart';

/// Ficha de pedido importador: cabecera clara, fecha visible y detalle simplificado.
class ImporterExpandableOrderCard extends StatelessWidget {
  const ImporterExpandableOrderCard({
    super.key,
    required this.request,
    this.checkoutGroupLines,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.operationalHeadline,
    this.nextStatus,
    this.nextActionLabel,
    this.onAdvance,
    this.canCancelByImporter = false,
    this.cancelBusy = false,
    this.onCancelByImporter,
    this.canNotifyQtyAdjustment = false,
    this.onNotifyQtyAdjustment,
    this.qtyAdjustmentDisabledHint,
    this.expandedFooter,
    this.onThreadChanged,
    this.ratingBar,
  });

  final TransactionRequestModel request;
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;
  final String? operationalHeadline;
  final String? nextStatus;
  final String? nextActionLabel;
  final VoidCallback? onAdvance;
  final bool canCancelByImporter;
  final bool cancelBusy;
  final VoidCallback? onCancelByImporter;
  final bool canNotifyQtyAdjustment;
  final VoidCallback? onNotifyQtyAdjustment;
  final String? qtyAdjustmentDisabledHint;
  final Widget? expandedFooter;
  final VoidCallback? onThreadChanged;
  final Widget? ratingBar;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final lines = (checkoutGroupLines != null && checkoutGroupLines!.length > 1)
        ? checkoutGroupLines!
        : <TransactionRequestModel>[r];
    final isCheckoutGroup = lines.length > 1;

    final uid = SupabaseService.currentUserId;
    final lineas = r.orderItemsParaVistaImportador(uid);
    final titulo = isCheckoutGroup
        ? tituloCheckoutGrupoImportador(lines, uid)
        : (lineas.isNotEmpty
            ? r.tituloPedidoImportador(lineas)
            : r.etiquetaProductoImportador(uid));
    final promoChip = importerPromoChipForLines(lines);

    final destinoTxt = isCheckoutGroup
        ? lines.first.destinoEntregaLineaCompactaEs
        : r.destinoEntregaLineaCompactaEs;
    final aliadoTxt = orderCardPartySubtitle(
      businessName: lines.first.aliadoBusinessName,
      ciudad: lines.first.aliadoCiudad,
      estado: lines.first.aliadoEstado,
    );
    final totalRef = lines.fold<double>(0, (a, x) => a + x.precioTotal);

    final fechaLabel = isCheckoutGroup
        ? ImporterOrderDate.etiquetaGrupo(lines)
        : ImporterOrderDate.etiquetaFecha(r);
    final fechaActiva = isCheckoutGroup
        ? lines.any(ImporterOrderDate.isAbierto)
        : ImporterOrderDate.isAbierto(r);

    final anyEntregadoPago = isCheckoutGroup
        ? lines.any((x) => x.pedidoEntregadoYPagado)
        : r.pedidoEntregadoYPagado;
    final anyPagoPendienteTrasEntrega =
        isCheckoutGroup ? lines.any((x) => x.esPedidoMoroso) : r.esPedidoMoroso;
    final anyPagoRiesgo = isCheckoutGroup
        ? lines.any((x) => x.pagoPendienteRiesgoCuentaTresDiasHabiles)
        : r.pagoPendienteRiesgoCuentaTresDiasHabiles;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: expanded
                ? AppColors.surfaceTinted.withOpacity(0.55)
                : Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ImporterOrderDateBadge(
                          label: fechaLabel,
                          isActive: fechaActiva,
                        ),
                        const Spacer(),
                        OrderStatusHeaderChips(
                          statusLabel: statusLabel,
                          showMoroso: anyPagoPendienteTrasEntrega,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      titulo,
                      maxLines: expanded ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            aliadoTxt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${formatRefAmount(totalRef)} REF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!expanded) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              destinoTxt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (promoChip != null) ...[
                      const SizedBox(height: 8),
                      promoChip,
                    ],
                    if (operationalHeadline != null &&
                        operationalHeadline!.isNotEmpty &&
                        operationalHeadline != '—') ...[
                      const SizedBox(height: 8),
                      Text(
                        operationalHeadline!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: r.status == TransactionRequestStatus.entregado
                              ? Colors.green.shade800
                              : AppColors.brandBlue,
                        ),
                      ),
                    ],
                    if (r.hasTransitEta &&
                        (r.status == TransactionRequestStatus.enTransito ||
                            r.status == TransactionRequestStatus.enviado)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ETA al taller: ${r.transitEtaResumenEs}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                    if (!expanded && anyEntregadoPago) ...[
                      const SizedBox(height: 8),
                      OrderCardCompactNoticeChip(
                        label: 'Entregado y pagado',
                        icon: Icons.check_circle_outline,
                        color: Colors.green.shade800,
                      ),
                    ] else if (anyPagoPendienteTrasEntrega && !expanded) ...[
                      const SizedBox(height: 8),
                      MorosoOrderCardNotice(
                        request: isCheckoutGroup
                            ? lines.firstWhere(
                                (x) => x.esPedidoMoroso,
                                orElse: () => r,
                              )
                            : r,
                        expanded: false,
                        riskWarningChild: null,
                      ),
                    ] else if (!expanded &&
                        lines.any((l) => l.qtyAdjustmentPendienteAliado)) ...[
                      const SizedBox(height: 8),
                      OrderCardCompactNoticeChip(
                        label: 'Ajuste de cantidad pendiente',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.amber.shade900,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (ratingBar != null) ratingBar!,
          if (nextStatus != null &&
              nextActionLabel != null &&
              onAdvance != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAdvance,
                  child: Text(nextActionLabel!),
                ),
              ),
            ),
          if (canCancelByImporter && onCancelByImporter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: OutlinedButton.icon(
                onPressed: cancelBusy ? null : onCancelByImporter,
                icon: cancelBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 20),
                label: Text(cancelBusy ? 'Cancelando…' : 'Cancelar pedido'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
              ),
            ),
          if (canNotifyQtyAdjustment || qtyAdjustmentDisabledHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: onNotifyQtyAdjustment,
                    icon: const Icon(Icons.inventory_2_outlined, size: 19),
                    label: const Text('Proponer ajuste de cantidad'),
                  ),
                  if (qtyAdjustmentDisabledHint != null &&
                      onNotifyQtyAdjustment == null) ...[
                    const SizedBox(height: 4),
                    Text(
                      qtyAdjustmentDisabledHint!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailSummaryStrip(
                          destino: destinoTxt,
                          totalRef: totalRef,
                          partidas: lines.length,
                          unidades:
                              lines.fold<int>(0, (a, x) => a + x.cantidad),
                        ),
                        if (anyEntregadoPago) ...[
                          const SizedBox(height: 10),
                          OrderCardCompactNoticeChip(
                            label: isCheckoutGroup
                                ? 'Entregado y pagado (línea validada)'
                                : 'Entregado y pagado',
                            icon: Icons.check_circle_outline,
                            color: Colors.green.shade800,
                          ),
                        ],
                        if (lines.any((l) => l.qtyAdjustmentPendienteAliado)) ...[
                          const SizedBox(height: 10),
                          _InfoBanner(
                            color: Colors.amber,
                            text: isCheckoutGroup
                                ? 'Cantidad pendiente de respuesta del aliado.'
                                : 'Cantidad pendiente: el aliado debe responder antes de «En preparación».',
                          ),
                        ],
                        if (anyPagoPendienteTrasEntrega) ...[
                          const SizedBox(height: 10),
                          MorosoOrderCardNotice(
                            request: isCheckoutGroup
                                ? lines.firstWhere(
                                    (x) => x.esPedidoMoroso,
                                    orElse: () => r,
                                  )
                                : r,
                            expanded: true,
                            riskWarningChild: anyPagoRiesgo
                                ? const _InfoBanner(
                                    color: Colors.red,
                                    text:
                                        '>3 días hábiles sin pago aprobado: posible restricción de nuevos pedidos.',
                                  )
                                : null,
                          ),
                        ],
                        const SizedBox(height: 12),
                        OrderCardCollapsibleSection(
                          title: 'Aliado y entrega',
                          subtitle: '$aliadoTxt · $destinoTxt',
                          initiallyExpanded: true,
                          trailingActions: [
                            if (TransactionRequestAliadoContactSection
                                .kycAprobadoPara(lines.first))
                              IconButton(
                                onPressed: () => showImporterAliadoKycDetailSheet(
                                  context,
                                  aliado:
                                      TransactionRequestAliadoContactSection
                                          .kycModelPara(lines.first),
                                ),
                                icon: const Icon(
                                  Icons.verified_user_outlined,
                                  size: 18,
                                ),
                                tooltip: 'Expediente KYC',
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TransactionRequestAliadoContactSection(
                                request: lines.first,
                                embedded: true,
                              ),
                              const SizedBox(height: 10),
                              TransactionRequestDestinoEntregaSection(
                                request: lines.first,
                                hideSectionTitle: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kOrderCardSectionGap),
                        OrderCardCollapsibleSection(
                          title: 'Productos',
                          subtitle: orderCardProductosSubtitle(
                            lines,
                            viewer: PedidoDesgloseViewer.importador,
                          ),
                          initiallyExpanded: true,
                          child: TransactionRequestProductosDesgloseSection(
                            lines: lines,
                            compact: true,
                            viewer: PedidoDesgloseViewer.importador,
                            hideSectionTitle: true,
                            showPrecioHelp: false,
                          ),
                        ),
                        if (orderCardCommissionSubtitle(lines) != null) ...[
                          const SizedBox(height: kOrderCardSectionGap),
                          OrderCardCollapsibleSection(
                            title: 'Comisión B2B Conecta',
                            subtitle: orderCardCommissionSubtitle(lines),
                            child: OrderCommissionSummary(
                              lines: orderLinesEligibleForCommission(lines),
                              suppressOuterTitle: true,
                            ),
                          ),
                        ],
                        const SizedBox(height: kOrderCardSectionGap),
                        OrderCardCollapsibleSection(
                          title: 'Seguimiento',
                          subtitle: orderCardTimelineSubtitle(
                            isCheckoutGroup ? lines.first : r,
                          ),
                          initiallyExpanded: orderCardTimelineInitiallyExpanded(
                            isCheckoutGroup ? lines.first : r,
                          ),
                          child: _SeguimientoBody(
                            lines: lines,
                            isCheckoutGroup: isCheckoutGroup,
                            uid: uid,
                            single: r,
                          ),
                        ),
                        const SizedBox(height: kOrderCardSectionGap),
                        OrderCardCollapsibleSection(
                          title: 'Mensajes',
                          subtitle: 'Chat con el aliado',
                          child: OrderMotolinkThreadSection(
                            key: ValueKey<String>(
                              isCheckoutGroup
                                  ? 'trm-imp-merge-${lines.map((e) => e.id).join("-")}'
                                  : 'trm-imp-${r.id}',
                            ),
                            transactionRequestId: lines.first.id,
                            mergedThreadRequestIds: isCheckoutGroup
                                ? lines.map((e) => e.id).toList()
                                : null,
                            allowReplyAsAliado: false,
                            allowReplyAsAdmin: false,
                            allowReplyAsImportador: lines.any(
                              (l) =>
                                  l.status !=
                                      TransactionRequestStatus.entregado &&
                                  l.status !=
                                      TransactionRequestStatus.rechazado,
                            ),
                            onThreadChanged: onThreadChanged,
                            suppressBuiltinTitle: true,
                            suppressInlineHelp: true,
                          ),
                        ),
                        if (expandedFooter != null) ...[
                          const SizedBox(height: 12),
                          expandedFooter!,
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onToggle,
                            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                            label: const Text('Ocultar detalle'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DetailSummaryStrip extends StatelessWidget {
  const _DetailSummaryStrip({
    required this.destino,
    required this.totalRef,
    required this.partidas,
    required this.unidades,
  });

  final String destino;
  final double totalRef;
  final int partidas;
  final int unidades;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            partidas == 1 ? '1 partida · $unidades uds' : '$partidas partidas · $unidades uds',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatRefAmount(totalRef)} REF',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destino,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.color, required this.text});

  final MaterialColor color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: color.shade900,
        ),
      ),
    );
  }
}

class _SeguimientoBody extends StatelessWidget {
  const _SeguimientoBody({
    required this.lines,
    required this.isCheckoutGroup,
    required this.uid,
    required this.single,
  });

  final List<TransactionRequestModel> lines;
  final bool isCheckoutGroup;
  final String? uid;
  final TransactionRequestModel single;

  @override
  Widget build(BuildContext context) {
    if (isCheckoutGroup) {
      if (checkoutGroupMismoEstadoEnvio(lines)) {
        return CourierTimelineWidget(
          request: lines.first,
          compact: true,
          viewerRole: AppHomeRole.importador,
          showHeading: false,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var li = 0; li < lines.length; li++) ...[
            if (li > 0) const Divider(height: 16),
            Text(
              lines[li].etiquetaGestionLineaImportador(uid),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            CourierTimelineWidget(
              request: lines[li],
              compact: true,
              viewerRole: AppHomeRole.importador,
              showHeading: false,
            ),
          ],
        ],
      );
    }
    return CourierTimelineWidget(
      request: single,
      compact: true,
      viewerRole: AppHomeRole.importador,
      showHeading: false,
    );
  }
}

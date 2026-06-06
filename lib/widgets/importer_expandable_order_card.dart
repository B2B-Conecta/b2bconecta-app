import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'courier_timeline_widget.dart';
import 'importer_aliado_solicitud_section.dart';
import 'importer_promo_widgets.dart';
import 'moroso_order_visual.dart';
import 'order_motolink_thread_section.dart';
import 'importer_kyc_approved_aliados_panel.dart';
import 'order_card_collapsible_layout.dart';
import 'order_commission_summary.dart';
import 'transaction_request_admin_sections.dart';

/// Ficha compacta para importador: resumen, acción rápida, detalle con aliado y fechas.
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
    this.expandedFooter,
    this.onThreadChanged,
    this.ratingBar,
  });

  final TransactionRequestModel request;

  /// Mismo carrito del aliado: varias filas con el mismo `checkout_group_id`.
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
    final showHeadline = operationalHeadline != null &&
        operationalHeadline!.isNotEmpty &&
        operationalHeadline != '—';
    final promoChip = importerPromoChipForLines(lines);

    final destinoTxt = isCheckoutGroup
        ? lines.first.destinoEntregaLineaCompactaEs
        : r.destinoEntregaLineaCompactaEs;

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
      clipBehavior: Clip.antiAlias,
      child: Column(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeadline) ...[
                            Text(
                              operationalHeadline!,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: r.status ==
                                        TransactionRequestStatus.entregado
                                    ? Colors.green.shade800
                                    : AppColors.brandBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (promoChip != null) ...[
                            promoChip,
                            const SizedBox(height: 6),
                          ],
                          if (r.hasTransitEta &&
                              (r.status ==
                                      TransactionRequestStatus.enTransito ||
                                  r.status ==
                                      TransactionRequestStatus.enviado)) ...[
                            Text(
                              'ETA al taller: ${r.transitEtaResumenEs}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  titulo,
                                  maxLines: expanded ? 4 : 2,
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
                                showMoroso: anyPagoPendienteTrasEntrega,
                              ),
                            ],
                          ),
                          if (isCheckoutGroup)
                            ImporterCheckoutBundleSolicitudSection(
                              lines: lines,
                              compact: true,
                              embedInOrderCard: true,
                              productDetailRows: false,
                            )
                          else
                            ImporterAliadoSolicitudSection(
                              request: r,
                              compact: true,
                              embedInOrderCard: true,
                              productDetailRows: false,
                            ),
                          const SizedBox(height: 4),
                          if (!expanded)
                            Text(
                              destinoTxt,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.25,
                              ),
                            ),
                          if (!expanded && anyEntregadoPago) ...[
                            const SizedBox(height: 6),
                            OrderCardCompactNoticeChip(
                              label: 'Entregado y pagado',
                              icon: Icons.check_circle_outline,
                              color: Colors.green.shade800,
                            ),
                          ] else if (anyPagoPendienteTrasEntrega) ...[
                            const SizedBox(height: 8),
                            MorosoOrderCardNotice(
                              request: isCheckoutGroup
                                  ? lines.firstWhere(
                                      (x) => x.esPedidoMoroso,
                                      orElse: () => r,
                                    )
                                  : r,
                              expanded: expanded,
                              riskWarningChild: anyPagoRiesgo
                                  ? Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        '>3 días hábiles sin pago aprobado: posible restricción de nuevos pedidos.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.3,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade900,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ] else if (!expanded &&
                              lines.any((l) => l.qtyAdjustmentPendienteAliado)) ...[
                            const SizedBox(height: 6),
                            OrderCardCompactNoticeChip(
                              label: 'Ajuste de cantidad pendiente',
                              icon: Icons.inventory_2_outlined,
                              color: Colors.amber.shade900,
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
          if (ratingBar != null) ratingBar!,
          if (nextStatus != null &&
              nextActionLabel != null &&
              onAdvance != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAdvance,
                      child: Text(nextActionLabel!),
                    ),
                  ),
                ],
              ),
            ),
          if (canCancelByImporter && onCancelByImporter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
          if (canNotifyQtyAdjustment && onNotifyQtyAdjustment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: OutlinedButton.icon(
                onPressed: onNotifyQtyAdjustment,
                icon: const Icon(Icons.inventory_2_outlined, size: 19),
                label: const Text('Proponer ajuste de cantidad'),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (anyEntregadoPago) ...[
                          OrderCardCompactNoticeChip(
                            label: isCheckoutGroup
                                ? 'Entregado y pagado (línea validada)'
                                : 'Entregado y pagado',
                            icon: Icons.check_circle_outline,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(height: kOrderCardSectionGap),
                        ],
                        if (lines.any((l) => l.qtyAdjustmentPendienteAliado)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text(
                              isCheckoutGroup
                                  ? 'Propuesta de cantidad pendiente de respuesta del aliado.'
                                  : 'Propuesta de cantidad pendiente: el aliado debe responder '
                                      'antes de marcar «En preparación».',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(height: kOrderCardSectionGap),
                        ],
                        OrderCardCollapsibleSection(
                          title: 'Aliado',
                          subtitle: orderCardPartySubtitle(
                            businessName: lines.first.aliadoBusinessName,
                            ciudad: lines.first.aliadoCiudad,
                            estado: lines.first.aliadoEstado,
                          ),
                          infoMessage:
                              'Datos fiscales del taller. Use el expediente KYC para evaluar crédito.',
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
                          child: TransactionRequestAliadoContactSection(
                            request: lines.first,
                            embedded: true,
                          ),
                        ),
                        const SizedBox(height: kOrderCardSectionGap),
                        OrderCardCollapsibleSection(
                          title: 'Entrega',
                          subtitle: lines.first.destinoEntregaLineaCompactaEs,
                          child: TransactionRequestDestinoEntregaSection(
                            request: lines.first,
                            hideSectionTitle: true,
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
                          infoMessage:
                              'Precios en REF = oferta MotoLink al aliado (alistamiento).',
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
                            title: 'Comisión MotoLink',
                            subtitle: orderCardCommissionSubtitle(lines),
                            infoMessage:
                                'Comisión devengada o estimada según el estado del pedido.',
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isCheckoutGroup) ...[
                                if (checkoutGroupMismoEstadoEnvio(lines))
                                  CourierTimelineWidget(
                                    request: lines.first,
                                    compact: true,
                                    viewerRole: AppHomeRole.importador,
                                    showHeading: false,
                                  )
                                else
                                  for (var li = 0; li < lines.length; li++) ...[
                                    if (li > 0) const Divider(height: 16),
                                    Text(
                                      lines[li]
                                          .etiquetaGestionLineaImportador(uid),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    CourierTimelineWidget(
                                      request: lines[li],
                                      compact: true,
                                      viewerRole: AppHomeRole.importador,
                                      showHeading: false,
                                    ),
                                  ],
                              ] else ...[
                                Text(
                                  lines.first
                                      .etiquetaGestionLineaImportador(uid),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                CourierTimelineWidget(
                                  request: r,
                                  compact: true,
                                  viewerRole: AppHomeRole.importador,
                                  showHeading: false,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: kOrderCardSectionGap),
                        OrderCardCollapsibleSection(
                          title: 'Mensajes',
                          subtitle: 'Hilo con el aliado y supervisión MotoLink',
                          infoMessage: OrderSectionHelp.chatPedido,
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

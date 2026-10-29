import 'package:motolink_pro_app/features/orders/shared/order_summary_header.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/payments/aliado_multi_importer_payment.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_orders_panel_layout.dart';
import 'aliado_multi_importer_order_tabs.dart';
import 'package:motolink_pro_app/features/orders/shared/courier_timeline_widget.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_aliado_solicitud_section.dart';
import 'aliado_transit_eta_banner.dart';
import 'package:motolink_pro_app/features/orders/shared/moroso_order_visual.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/orders/admin/transaction_request_admin_sections.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';

/// Ficha compacta para aliado: resumen y detalle con importador y ciclo del envío.
class AliadoExpandableOrderCard extends StatelessWidget {
  const AliadoExpandableOrderCard({
    super.key,
    required this.request,
    this.checkoutGroupLines,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
    this.onCancelarSolicitudPendiente,
    this.cancelarSolicitudPendienteBusy = false,
    this.expandedLeading,
    this.expandedFooter,
    this.multiImporterPanelBuilder,
    this.ratingBar,
    this.onChatChanged,
  });

  final TransactionRequestModel request;

  /// Varias filas del mismo carrito (mismo `checkout_group_id`). Si es una sola fila, dejar null.
  final List<TransactionRequestModel>? checkoutGroupLines;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;

  /// Contenido al inicio de la ficha expandida (p. ej. confirmar recepción).
  final Widget? expandedLeading;

  /// Solo aplica mientras [TransactionRequestModel.status] es pendiente.
  final VoidCallback? onCancelarSolicitudPendiente;
  final bool cancelarSolicitudPendienteBusy;
  final Widget? expandedFooter;

  /// CTA de valoración, visible dentro del pedido abierto.
  final Widget? ratingBar;

  /// Tras enviar o recibir un mensaje desde el chat.
  final VoidCallback? onChatChanged;

  /// Carrito multi-importador: factura, pago y mensajes por proveedor (pestañas).
  final Widget Function(
    BuildContext context,
    List<TransactionRequestModel> chunk,
    int importerIndex,
    int importerTotal,
  )? multiImporterPanelBuilder;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final density = B2bOrderCardDensity.of(width);
    final lines = (checkoutGroupLines != null && checkoutGroupLines!.isNotEmpty)
        ? checkoutGroupLines!
        : <TransactionRequestModel>[request];
    final isCheckoutGroup = lines.length > 1;
    final r = request;
    final distinctImporterIds =
        lines.map((e) => e.ownerId.trim()).where((s) => s.isNotEmpty).toSet();

    /// Mismo almacén en todas las líneas: un solo bloque de contacto B2B.
    final consolidarDatosImportador =
        isCheckoutGroup && distinctImporterIds.length <= 1;
    final useMultiImporterTabs =
        isCheckoutGroup && multiImporterPanelBuilder != null;
    final porImportador = useMultiImporterTabs
        ? groupCheckoutLinesByImportador(lines)
        : const <List<TransactionRequestModel>>[];
    return B2bOrderCardDensityScope(
      density: density,
      child: Card(
        margin: EdgeInsets.only(bottom: density.cardMarginBottom),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrderSummaryHeader(
              lines: lines,
              viewerRole: AppHomeRole.aliado,
              expanded: expanded,
              onToggle: onToggle,
              statusLabel: statusLabel,
              onCancel: onCancelarSolicitudPendiente != null &&
                      lines.every(
                          (l) => l.aliadoPuedeCancelarHastaFacturaProveedor)
                  ? onCancelarSolicitudPendiente
                  : null,
              cancelBusy: cancelarSolicitudPendienteBusy,
              chatAction: OrderChatIconButton(
                relatedOrderIds: lines.map((e) => e.id).toList(),
                onOpen: () {
                  final counterpart = lines.first.ownerBusinessName?.trim();
                  showOrderChatSheet(
                    context: context,
                    transactionRequestId: lines.first.id,
                    mergedThreadRequestIds: isCheckoutGroup
                        ? lines.map((e) => e.id).toList()
                        : null,
                    orderLines: lines,
                    allowReplyAsAliado: orderLinesAllowChatReply(lines),
                    allowReplyAsAdmin: false,
                    deliveryGrace: orderLinesChatDeliveryGrace(lines),
                    title: (counterpart != null && counterpart.isNotEmpty)
                        ? 'Chat · $counterpart'
                        : 'Chat del pedido',
                    onThreadChanged: onChatChanged,
                  );
                },
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? B2bOrdersPanelLayout.expandedContent(
                      context,
                      Builder(
                        builder: (ctx) {
                          final sectionGap = B2bOrdersPanelLayout.sectionGap(
                            MediaQuery.sizeOf(ctx).width,
                          );
                          return Padding(
                            padding: density.cardExpandedPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: sectionGap),
                                if (expandedLeading != null) expandedLeading!,
                                if (!useMultiImporterTabs &&
                                    expandedFooter != null) ...[
                                  SizedBox(height: sectionGap),
                                  expandedFooter!,
                                ],
                                if (lines.any((x) => x.esPedidoMoroso)) ...[
                                  const SizedBox(height: 8),
                                  MorosoOrderCardNotice(
                                    request: lines.firstWhere(
                                      (x) => x.esPedidoMoroso,
                                      orElse: () => lines.first,
                                    ),
                                    expanded: true,
                                    aliadoViewer: true,
                                  ),
                                ],
                                if (isCheckoutGroup) ...[
                                  if (useMultiImporterTabs) ...[
                                    AliadoPedidoMaestroHeader(
                                      allLines: lines,
                                      porImportador: porImportador,
                                    ),
                                    SizedBox(height: sectionGap),
                                  ],
                                  OrderCardCollapsibleSection(
                                    title: 'Entrega',
                                    subtitle: lines
                                        .first.destinoEntregaLineaCompactaEs,
                                    child:
                                        TransactionRequestDestinoEntregaSection(
                                      request: lines.first,
                                      hideSectionTitle: true,
                                    ),
                                  ),
                                  if (!useMultiImporterTabs) ...[
                                    SizedBox(height: sectionGap),
                                    if (consolidarDatosImportador)
                                      OrderCardCollapsibleSection(
                                        title: 'Importador',
                                        subtitle: orderCardPartySubtitle(
                                          businessName:
                                              lines.first.ownerBusinessName,
                                          ciudad: lines.first.ownerCiudad,
                                          estado: lines.first.ownerEstado,
                                        ),
                                        child:
                                            TransactionRequestImporterContactSection(
                                          request: lines.first,
                                          embedded: true,
                                        ),
                                      ),
                                    if (consolidarDatosImportador)
                                      SizedBox(height: sectionGap),
                                    OrderCardCollapsibleSection(
                                      title: 'Productos',
                                      subtitle: orderCardProductosSubtitle(
                                        lines,
                                        viewer: PedidoDesgloseViewer.aliado,
                                      ),
                                      initiallyExpanded:
                                          orderCardProductsInitiallyExpanded(
                                        lines.first.status,
                                      ),
                                      child:
                                          TransactionRequestProductosDesgloseSection(
                                        lines: lines,
                                        compact: true,
                                        viewer: PedidoDesgloseViewer.aliado,
                                        showPrecioHelp: false,
                                        showImporterGroupHeaders: true,
                                        hideSectionTitle: true,
                                      ),
                                    ),
                                    SizedBox(height: sectionGap),
                                    OrderCardCollapsibleSection(
                                      title: 'Seguimiento',
                                      subtitle: orderCardTimelineSubtitle(
                                        lines.first,
                                        aliadoViewer: true,
                                      ),
                                      initiallyExpanded:
                                          orderCardTimelineInitiallyExpanded(
                                        lines.first,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (checkoutGroupMismoEstadoEnvio(
                                              lines)) ...[
                                            ..._checkoutGroupEtaBanners(lines),
                                            CourierTimelineWidget(
                                              request: lines.first,
                                              compact: true,
                                              viewerRole: AppHomeRole.aliado,
                                              showHeading: false,
                                              embedded: true,
                                            ),
                                            ..._postTimelineBloquesAliado(
                                              lines: lines,
                                              consolidarDatosImportador:
                                                  consolidarDatosImportador,
                                            ),
                                          ] else
                                            ..._postTimelineBloquesAliado(
                                              lines: lines,
                                              consolidarDatosImportador:
                                                  consolidarDatosImportador,
                                              timelinePorLinea: true,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    SizedBox(height: sectionGap),
                                    AliadoMultiImporterOrderTabs(
                                      allLines: lines,
                                      porImportador: porImportador,
                                      importerPanelBuilder:
                                          multiImporterPanelBuilder!,
                                    ),
                                  ],
                                ] else ...[
                                  OrderCardCollapsibleSection(
                                    title: 'Importador',
                                    subtitle: orderCardPartySubtitle(
                                      businessName: r.ownerBusinessName,
                                      ciudad: r.ownerCiudad,
                                      estado: r.ownerEstado,
                                    ),
                                    child:
                                        TransactionRequestImporterContactSection(
                                      request: r,
                                      embedded: true,
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  OrderCardCollapsibleSection(
                                    title: 'Entrega',
                                    subtitle: r.destinoEntregaLineaCompactaEs,
                                    child:
                                        TransactionRequestDestinoEntregaSection(
                                      request: r,
                                      hideSectionTitle: true,
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  OrderCardCollapsibleSection(
                                    title: 'Productos',
                                    subtitle: orderCardProductosSubtitle(
                                      [r],
                                      viewer: PedidoDesgloseViewer.aliado,
                                    ),
                                    initiallyExpanded:
                                        orderCardProductsInitiallyExpanded(
                                      r.status,
                                    ),
                                    child:
                                        TransactionRequestProductosDesgloseSection(
                                      lines: <TransactionRequestModel>[r],
                                      compact: true,
                                      viewer: PedidoDesgloseViewer.aliado,
                                      showPrecioHelp: false,
                                      hideSectionTitle: true,
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  OrderCardCollapsibleSection(
                                    title: 'Seguimiento',
                                    subtitle: orderCardTimelineSubtitle(
                                      r,
                                      aliadoViewer: true,
                                    ),
                                    initiallyExpanded:
                                        orderCardTimelineInitiallyExpanded(r),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AliadoTransitEtaBanner(request: r),
                                        const SizedBox(height: 8),
                                        CourierTimelineWidget(
                                          request: r,
                                          compact: true,
                                          viewerRole: AppHomeRole.aliado,
                                          showHeading: false,
                                          embedded: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (expanded && ratingBar != null) ratingBar!,
          ],
        ),
      ),
    );
  }
}

/// Tras el timeline: contacto por importador (si no está unificado arriba) y bloques de recogida por línea en tránsito.
/// En carrito multi-importador los productos están en cada pestaña de proveedor.
List<Widget> _postTimelineBloquesAliado({
  required List<TransactionRequestModel> lines,
  required bool consolidarDatosImportador,
  bool timelinePorLinea = false,
}) {
  final out = <Widget>[];
  if (timelinePorLinea) {
    for (var i = 0; i < lines.length; i++) {
      if (out.isNotEmpty) {
        out.add(Divider(height: 1, color: AppColors.borderSubtle));
        out.add(const SizedBox(height: 12));
      }
      if (!consolidarDatosImportador) {
        out.add(TransactionRequestImporterContactSection(
          request: lines[i],
          embedded: true,
        ));
        out.add(const SizedBox(height: 12));
      }
      out.add(AliadoTransitEtaBanner(request: lines[i]));
      out.add(const SizedBox(height: 8));
      out.add(
        CourierTimelineWidget(
          request: lines[i],
          compact: true,
          viewerRole: AppHomeRole.aliado,
          showHeading: false,
          embedded: true,
        ),
      );
    }
  } else {
    if (!consolidarDatosImportador) {
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) {
          out.add(Divider(height: 1, color: AppColors.borderSubtle));
          out.add(const SizedBox(height: 12));
        }
        out.add(TransactionRequestImporterContactSection(
          request: lines[i],
          embedded: true,
        ));
      }
      if (lines.isNotEmpty) {
        out.add(const SizedBox(height: 12));
      }
    }
  }
  return out;
}

class _MultiImporterPagoResumenChip extends StatelessWidget {
  const _MultiImporterPagoResumenChip({required this.lines});

  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final porImp = groupCheckoutLinesByImportador(lines);
    final n = porImp.length;
    if (n < 2) return const SizedBox.shrink();
    final ok = importadoresConPagoConfirmado(porImp);
    final color = ok == n ? Colors.green.shade700 : AppColors.brandBlue;

    return Chip(
      avatar: Icon(
        ok == n ? Icons.check_circle : Icons.payments_outlined,
        size: 16,
        color: color,
      ),
      label: Text(
        '$n pagos · $ok confirmado${ok == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.35)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _lineaPrecioResumenAliado(TransactionRequestModel r) {
  final buf = StringBuffer(
      '${formatRefAmount(r.precioTotal)} ${r.amountCurrencyLabel}');
  if (r.tieneDescuentoDivisasAplicadoEnPedido) {
    buf.write(' (antes ${formatRefAmount(r.refBaseTotalForPago)})');
  }
  if (r.precioTotalBsUi != null) {
    buf.write(' · ~${formatVesAmount(r.precioTotalBsUi!)} Bs');
  }
  return buf.toString();
}

class _DescuentoDivisasFichaChip extends StatelessWidget {
  const _DescuentoDivisasFichaChip({required this.request});

  final TransactionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final metodo = r.pagoMetodo?.trim();
    if (metodo == null || metodo.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(Icons.savings_outlined,
            size: 16, color: Colors.green.shade800),
        label: Text(
          'Descuento divisas · ${PagoMetodo.labelEs(metodo)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.green.shade900,
          ),
        ),
        backgroundColor: Colors.green.shade50,
        side: BorderSide(color: Colors.green.shade200),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

String _checkoutGroupResumen(List<TransactionRequestModel> lines) {
  if (lines.isEmpty) return '';
  final uds = lines.fold<int>(0, (a, r) => a + r.cantidad);
  final totalRef = lines.fold<double>(0, (a, r) => a + r.precioTotal);
  final imp = lines.length;
  final buf = StringBuffer(
    '$imp ${imp == 1 ? "importador" : "importadores"} · $uds uds · '
    '${formatRefAmount(totalRef)} ${orderAmountCurrency(lines)}',
  );
  final bsVals =
      lines.map((r) => r.precioTotalBsUi).whereType<double>().toList();
  if (bsVals.length == lines.length && bsVals.isNotEmpty) {
    final sumBs = bsVals.fold<double>(0, (a, b) => a + b);
    buf.write(' · ~${formatVesAmount(sumBs)} Bs');
  }
  if (lines.any(
    (r) => r.hasAppliedVolumeDiscount,
  )) {
    buf.write(' · descuentos volumen en ficha');
  }
  return buf.toString();
}

List<Widget> _checkoutGroupEtaChips(List<TransactionRequestModel> lines) {
  final porImp = groupCheckoutLinesByImportador(lines);
  final chips = <Widget>[];
  for (final chunk in porImp) {
    if (chunk.isEmpty) continue;
    final ref = chunk.first;
    if (!AliadoTransitEtaBanner.shouldShow(ref)) continue;
    final name = ref.ownerBusinessName?.trim();
    chips.add(
      AliadoTransitEtaChip(
        request: ref,
        importerName: name,
      ),
    );
  }
  if (chips.isEmpty) return const [];
  return [
    Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    ),
  ];
}

/// Banners ETA por proveedor (carrito expandido, mismo estado o varios).
List<Widget> _checkoutGroupEtaBanners(List<TransactionRequestModel> lines) {
  final porImp = groupCheckoutLinesByImportador(lines);
  final out = <Widget>[];
  for (final chunk in porImp) {
    if (chunk.isEmpty) continue;
    final ref = chunk.first;
    if (!AliadoTransitEtaBanner.shouldShow(ref)) continue;
    if (out.isNotEmpty) out.add(const SizedBox(height: 8));
    out.add(
      AliadoTransitEtaBanner(
        request: ref,
        importerName: ref.ownerBusinessName,
      ),
    );
  }
  if (out.isEmpty) return const [];
  return [
    ...out,
    const SizedBox(height: 12),
  ];
}

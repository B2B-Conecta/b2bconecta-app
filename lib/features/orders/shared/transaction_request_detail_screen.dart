import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/logistics/pickup_location_mode.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'courier_timeline_widget.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_transit_eta_banner.dart';
import 'package:motolink_pro_app/features/logistics/importer_confirm_pickup_section.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_aliado_solicitud_section.dart';
import 'aliado_order_grouping.dart';
import 'order_flow_copy/order_actions_flow_copy.dart';
import 'order_flow_copy/order_vocab.dart';
import 'order_pickup_flow_copy.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_eligibility.dart';
import 'order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'package:motolink_pro_app/features/orders/admin/transaction_request_admin_sections.dart';

class TransactionRequestDetailScreen extends StatefulWidget {
  const TransactionRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.homeRole,
  });

  final String requestId;
  final AppHomeRole homeRole;

  @override
  State<TransactionRequestDetailScreen> createState() =>
      _TransactionRequestDetailScreenState();
}

enum _NoteCardTone { info, warning, danger }

class _DetailLoad {
  const _DetailLoad({
    required this.primary,
    required this.lines,
  });

  final TransactionRequestModel primary;
  final List<TransactionRequestModel> lines;
}

class _TransactionRequestDetailScreenState
    extends State<TransactionRequestDetailScreen> {
  late Future<_DetailLoad?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<_DetailLoad?> _loadDetail() async {
    final lines =
        await SupabaseService.fetchCheckoutGroupLinesForTransactionRequest(
      widget.requestId,
    );
    if (lines.isEmpty) return null;
    TransactionRequestModel primary;
    try {
      primary = lines.firstWhere((e) => e.id == widget.requestId);
    } catch (_) {
      primary = lines.first;
    }
    return _DetailLoad(primary: primary, lines: lines);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle del pedido',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<_DetailLoad?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }
          if (snapshot.hasError) {
            return _stateText(
                'No se pudo cargar el pedido.\n${snapshot.error}');
          }
          final data = snapshot.data;
          if (data == null) {
            return _stateText(
              'No encontramos este pedido o no tienes permisos para verlo.',
            );
          }
          final r = data.primary;
          final lines = data.lines;
          final isGroup = lines.length > 1;
          final anyEntregadoPagado = lines.any((x) => x.pedidoEntregadoYPagado);
          final anyPagoPendienteTrasEntrega =
              lines.any((x) => x.pagoMotolinkPendienteTrasEntrega);
          final anyPagoRiesgo = lines.any(
            (x) => x.pagoPendienteRiesgoCuentaTresDiasHabiles,
          );
          final anyPedidoListo = lines.any(_mostrarBannerPedidoListo);
          final isAliadoOrAdmin = widget.homeRole == AppHomeRole.aliado ||
              widget.homeRole == AppHomeRole.administrador;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              if (isAliadoOrAdmin) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (anyEntregadoPagado)
                      OrderCardCompactNoticeChip(
                        label: 'Entregado y pagado',
                        icon: Icons.check_circle_outline,
                        color: Colors.green.shade800,
                      ),
                    if (anyPagoPendienteTrasEntrega)
                      OrderCardCompactNoticeChip(
                        label: 'Pago pendiente',
                        icon: Icons.payments_outlined,
                        color: Colors.deepOrange.shade800,
                      ),
                    if (anyPagoRiesgo)
                      OrderCardCompactNoticeChip(
                        label: 'Riesgo de restricción',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red.shade800,
                      ),
                    if (anyPedidoListo)
                      OrderCardCompactNoticeChip(
                        label: 'Listo para recolección',
                        icon: Icons.notifications_active_outlined,
                        color: Colors.teal.shade900,
                      ),
                  ],
                ),
                if (anyEntregadoPagado ||
                    anyPagoPendienteTrasEntrega ||
                    anyPagoRiesgo ||
                    anyPedidoListo)
                  const SizedBox(height: 12),
              ] else ...[
                if (anyEntregadoPagado) ...[
                  _pagoCompletadoBanner(),
                  const SizedBox(height: 12),
                ] else if (anyPagoPendienteTrasEntrega) ...[
                  _pagoPendienteBanner(),
                  if (anyPagoRiesgo) ...[
                    const SizedBox(height: 10),
                    _pagoAtrasoCuentaBanner(),
                  ],
                  const SizedBox(height: 12),
                ],
                if (anyPedidoListo) ...[
                  if (lines.any((x) => x.hasPickupConfirmed))
                    PickupLocationDisplaySection(
                      request: lines.firstWhere(
                        (x) => x.hasPickupConfirmed,
                        orElse: () => r,
                      ),
                    )
                  else
                    _pedidoListoPickupBanner(),
                  const SizedBox(height: 12),
                ],
              ],
              if (lines.any(
                (x) =>
                    x.canceladoPorAliado &&
                    (x.aliadoCancelacionMotivo?.trim().isNotEmpty ?? false),
              )) ...[
                _noteCard(
                  lines
                      .firstWhere(
                        (x) =>
                            x.canceladoPorAliado &&
                            (x.aliadoCancelacionMotivo?.trim().isNotEmpty ??
                                false),
                      )
                      .aliadoCancelacionMotivo!
                      .trim(),
                  title: 'Pedido cancelado por el aliado',
                  tone: _NoteCardTone.warning,
                ),
                const SizedBox(height: 12),
              ],
              if (lines.any(
                (x) =>
                    x.canceladoPorImportador &&
                    (x.importadorCancelacionMotivo?.trim().isNotEmpty ?? false),
              )) ...[
                _noteCard(
                  lines
                      .firstWhere(
                        (x) =>
                            x.canceladoPorImportador &&
                            (x.importadorCancelacionMotivo?.trim().isNotEmpty ??
                                false),
                      )
                      .importadorCancelacionMotivo!
                      .trim(),
                  title: OrderActionsFlowCopy.pedidoCanceladoPorImportador,
                  tone: _NoteCardTone.warning,
                ),
                const SizedBox(height: 12),
              ],
              if (lines.any(
                (x) =>
                    x.anuladoPorMotolink &&
                    (x.motolinkAnulacionMotivo?.trim().isNotEmpty ?? false),
              )) ...[
                _noteCard(
                  lines
                      .firstWhere(
                        (x) =>
                            x.anuladoPorMotolink &&
                            (x.motolinkAnulacionMotivo?.trim().isNotEmpty ??
                                false),
                      )
                      .motolinkAnulacionMotivo!
                      .trim(),
                  title: 'Pedido anulado por B2B Conecta',
                  tone: _NoteCardTone.danger,
                ),
                const SizedBox(height: 12),
              ],
              _summaryCardCompact(r, lines),
              if (isAliadoOrAdmin) ...[
                const SizedBox(height: kOrderCardSectionGap),
                ..._detailCollapsibleSections(r, lines),
              ] else ...[
                if (widget.homeRole == AppHomeRole.importador) ...[
                  const SizedBox(height: 12),
                  isGroup
                      ? ImporterCheckoutBundleSolicitudSection(
                          lines: lines,
                          compact: false,
                        )
                      : ImporterAliadoSolicitudSection(
                          request: r, compact: false),
                ],
                const SizedBox(height: 12),
                _contactByRole(r),
                const SizedBox(height: 12),
                _masInformacionSection(context, r, lines),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _pagoPendienteBanner() {
    return Material(
      color: Colors.deepOrange.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.payments_outlined, color: Colors.deepOrange.shade800),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                OrderActionsFlowCopy.pagoPendienteBanner,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _mostrarBannerPedidoListo(TransactionRequestModel r) {
    if (r.status != TransactionRequestStatus.pedidoListo) return false;
    return widget.homeRole == AppHomeRole.administrador;
  }

  bool _showPickupSection(TransactionRequestModel r) {
    if (r.status == TransactionRequestStatus.pedidoListo) return true;
    return r.hasPickupConfirmed;
  }

  Widget _pedidoListoPickupBanner() {
    return Material(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_active_outlined,
                color: Colors.teal.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                OrderPickupFlowCopy.detalleListoEsperando,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagoCompletadoBanner() {
    return Material(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pedido entregado y pagado: B2B Conecta validó el pago.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagoAtrasoCuentaBanner() {
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Han pasado 3 o más días hábiles sin completar el pago. B2B Conecta puede restringir la cuenta '
                'del aliado para pedidos futuros si no se regulariza.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateText(String t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  /// Resumen breve: lo esencial para ubicar el pedido y el estado.
  Widget _summaryCardCompact(
    TransactionRequestModel r,
    List<TransactionRequestModel> lines,
  ) {
    final uid = SupabaseService.currentUserId;
    final isGroup = lines.length > 1;
    final partidas = r.orderItemsParaVistaImportador(uid);
    final String title;
    if (widget.homeRole == AppHomeRole.importador) {
      title = isGroup
          ? tituloCheckoutGrupoImportador(lines, uid)
          : (partidas.isNotEmpty
              ? r.tituloPedidoImportador(partidas)
              : r.etiquetaProductoImportador(uid));
    } else if (isGroup) {
      title = tituloCheckoutGrupoAliado(lines);
    } else {
      title = r.tituloFichaPrincipalPedido;
    }
    final totalRef = isGroup
        ? lines.fold<double>(0, (a, e) => a + e.precioTotal)
        : r.precioTotal;
    final statusSet = lines.map((e) => e.status).toSet();
    final estadoChip = isGroup && statusSet.length > 1
        ? 'Varios estados'
        : (r.esPedidoMoroso
            ? '${r.statusLabelEs(aliadoViewer: widget.homeRole == AppHomeRole.aliado)} · ${OrderVocab.chipPagoPendiente}'
            : r.statusLabelEs(
                aliadoViewer: widget.homeRole == AppHomeRole.aliado));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Estado: $estadoChip'),
                _chip('Total REF: ${totalRef.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isGroup
                  ? 'Carrito · ${lines.length} línea(s) · ref. ${r.id.substring(0, 8)}…'
                  : 'Ref. pedido: ${r.id.substring(0, 8)}…',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _detailCollapsibleSections(
    TransactionRequestModel r,
    List<TransactionRequestModel> lines,
  ) {
    final isGroup = lines.length > 1;
    final isAliado = widget.homeRole == AppHomeRole.aliado;
    final isAdmin = widget.homeRole == AppHomeRole.administrador;
    final aliadoViewer = isAliado;
    final refLine = lines.first;
    final hasNota = r.notasAdmin != null && r.notasAdmin!.trim().isNotEmpty;
    TransactionRequestModel? expLine;
    for (final x in lines) {
      if (x.aliadoExperienceSubmittedAt != null) {
        expLine = x;
        break;
      }
    }
    if (expLine == null && isAdmin) {
      for (final x in lines) {
        if (lineaElegibleValoracionAliado(x) ||
            lineaElegibleValoracionImportador(x)) {
          expLine = x;
          break;
        }
      }
    }

    final out = <Widget>[
      if (isAliado) ...[
        OrderCardCollapsibleSection(
          title: 'Productos',
          subtitle: orderCardProductosSubtitle(
            lines,
            viewer: PedidoDesgloseViewer.aliado,
          ),
          initiallyExpanded: true,
          child: TransactionRequestProductosDesgloseSection(
            lines: lines,
            compact: true,
            viewer: PedidoDesgloseViewer.aliado,
            showPrecioHelp: false,
            hideSectionTitle: true,
            showImporterGroupHeaders: isGroup,
          ),
        ),
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Importador',
          subtitle: orderCardPartySubtitle(
            businessName: r.ownerBusinessName,
            ciudad: r.ownerCiudad,
            estado: r.ownerEstado,
          ),
          child: TransactionRequestImporterContactSection(
            request: r,
            embedded: true,
          ),
        ),
      ],
      if (isAdmin) ...[
        OrderCardCollapsibleSection(
          title: 'Partes del pedido',
          subtitle: TransactionRequestPartiesContactSection.partiesSubtitle(r),
          infoMessage: 'Aliado e importador involucrados en el pedido.',
          child: TransactionRequestPartiesContactSection(
            request: r,
            embedded: true,
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
            showImporterGroupHeaders: isGroup,
          ),
        ),
        if (orderCardCommissionSubtitle(lines) != null) ...[
          const SizedBox(height: kOrderCardSectionGap),
          OrderCardCollapsibleSection(
            title: 'Comisión B2B Conecta',
            subtitle: orderCardCommissionSubtitle(lines),
            infoMessage:
                'Comisión devengada o estimada según el estado del pedido.',
            child: OrderCommissionSummary(
              lines: orderLinesEligibleForCommission(lines),
              suppressOuterTitle: true,
            ),
          ),
        ],
        if (expLine != null) ...[
          const SizedBox(height: kOrderCardSectionGap),
          OrderCardCollapsibleSection(
            title: 'Valoración del aliado',
            subtitle: expLine.aliadoExperienceStars != null
                ? '${expLine.aliadoExperienceStars}/5 post-entrega'
                : (expLine.aliadoExperienceSubmittedAt != null
                    ? 'Comentario registrado'
                    : 'Pendiente — admin puede registrar'),
            child: TransactionRequestAliadoExperienceAdminSection(
              request: expLine,
              hideSectionTitle: true,
              onMutated: () => setState(() {
                _future = _loadDetail();
              }),
            ),
          ),
          if (lineaElegibleValoracionImportador(expLine)) ...[
            const SizedBox(height: kOrderCardSectionGap),
            OrderCardCollapsibleSection(
              title: 'Valoración del mayorista',
              subtitle: 'Al aliado de este pedido',
              child: TransactionRequestImporterRatingAdminSection(
                request: expLine,
                onMutated: () => setState(() {
                  _future = _loadDetail();
                }),
              ),
            ),
          ],
        ],
      ],
      if (_showPickupSection(refLine)) ...[
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: OrderPickupFlowCopy.recoleccionTitulo,
          subtitle: refLine.hasPickupConfirmed
              ? PickupLocationMode.labelEs(refLine.pickupLocationMode)
              : OrderPickupFlowCopy.recoleccionPendienteGenerico,
          infoMessage: OrderSectionHelp.puntoRecoleccion,
          initiallyExpanded: refLine.hasPickupConfirmed,
          child: PickupLocationDisplaySection(request: refLine),
        ),
      ],
      const SizedBox(height: kOrderCardSectionGap),
      OrderCardCollapsibleSection(
        title: 'Entrega',
        subtitle: refLine.destinoEntregaLineaCompactaEs,
        child: TransactionRequestDestinoEntregaSection(
          request: refLine,
          hideSectionTitle: true,
        ),
      ),
      const SizedBox(height: kOrderCardSectionGap),
      OrderCardCollapsibleSection(
        title: 'Seguimiento',
        subtitle: orderCardTimelineSubtitle(
          refLine,
          aliadoViewer: aliadoViewer,
        ),
        initiallyExpanded: orderCardTimelineInitiallyExpanded(refLine),
        child: _detailTimelineBlock(lines, aliadoViewer: aliadoViewer),
      ),
      const SizedBox(height: kOrderCardSectionGap),
      OrderCardCollapsibleSection(
        title: 'Referencias',
        subtitle: 'ID · ${r.id.substring(0, 8)}…',
        child: _summaryReferenceBlock(r),
      ),
      if (hasNota) ...[
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Nota de B2B Conecta',
          subtitle: 'Instrucción interna del pedido',
          child: _noteCard(
            r.notasAdmin!.trim(),
            title: 'Nota de B2B Conecta',
            tone: _NoteCardTone.info,
          ),
        ),
      ],
    ];
    return out;
  }

  Widget _detailTimelineBlock(
    List<TransactionRequestModel> lines, {
    required bool aliadoViewer,
  }) {
    final isGroup = lines.length > 1;
    final r = lines.first;
    if (isGroup && checkoutGroupMismoEstadoEnvio(lines)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._detailEtaBanners(lines),
          CourierTimelineWidget(
            request: lines.first,
            compact: true,
            viewerRole: widget.homeRole,
            showHeading: false,
          ),
          if (lines.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _flowItemsCaption(lines),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      );
    }
    if (isGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(
              _timelineLineLabelForDetail(lines[i]),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            if (AliadoTransitEtaBanner.shouldShow(lines[i])) ...[
              const SizedBox(height: 6),
              AliadoTransitEtaBanner(
                request: lines[i],
                importerName: lines[i].ownerBusinessName,
              ),
            ],
            const SizedBox(height: 6),
            CourierTimelineWidget(
              request: lines[i],
              compact: true,
              viewerRole: widget.homeRole,
              showHeading: false,
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (AliadoTransitEtaBanner.shouldShow(r)) ...[
          AliadoTransitEtaBanner(request: r),
          const SizedBox(height: 8),
        ],
        CourierTimelineWidget(
          request: r,
          compact: true,
          viewerRole: widget.homeRole,
          showHeading: false,
        ),
      ],
    );
  }

  Widget _masInformacionSection(
    BuildContext context,
    TransactionRequestModel r,
    List<TransactionRequestModel> lines,
  ) {
    final hasNota = r.notasAdmin != null && r.notasAdmin!.trim().isNotEmpty;
    final isGroup = lines.length > 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Badge(
            isLabelVisible: hasNota,
            smallSize: 7,
            backgroundColor: AppColors.brand,
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.brandBlue,
            ),
          ),
          title: Text(
            'Más información',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            'Referencias, entrega, historial y notas',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            _summaryReferenceBlock(r),
            const SizedBox(height: 14),
            if (_showPickupSection(r)) ...[
              PickupLocationDisplaySection(request: r),
              const SizedBox(height: 14),
            ],
            TransactionRequestDestinoEntregaSection(
              request: r,
            ),
            const SizedBox(height: 14),
            if (isGroup && checkoutGroupMismoEstadoEnvio(lines)) ...[
              ..._detailEtaBanners(lines),
              CourierTimelineWidget(
                request: lines.first,
                viewerRole: widget.homeRole,
              ),
              if (lines.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _flowItemsCaption(lines),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ] else if (isGroup) ...[
              Text(
                'Seguimiento del envío',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Text(
                  _timelineLineLabelForDetail(lines[i]),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (AliadoTransitEtaBanner.shouldShow(lines[i])) ...[
                  const SizedBox(height: 6),
                  AliadoTransitEtaBanner(
                    request: lines[i],
                    importerName: lines[i].ownerBusinessName,
                  ),
                ],
                const SizedBox(height: 6),
                CourierTimelineWidget(
                  request: lines[i],
                  viewerRole: widget.homeRole,
                  showHeading: false,
                ),
              ],
            ] else ...[
              if (AliadoTransitEtaBanner.shouldShow(r)) ...[
                AliadoTransitEtaBanner(request: r),
                const SizedBox(height: 12),
              ],
              CourierTimelineWidget(
                request: r,
                viewerRole: widget.homeRole,
              ),
            ],
            if (hasNota) ...[
              const SizedBox(height: 14),
              _noteCard(
                r.notasAdmin!.trim(),
                title: 'Nota de B2B Conecta',
                tone: _NoteCardTone.info,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _flowItemsCaption(List<TransactionRequestModel> lines) {
    final uid = SupabaseService.currentUserId;
    switch (widget.homeRole) {
      case AppHomeRole.importador:
        return 'Ítems en este flujo: ${tituloCheckoutGrupoImportador(lines, uid)}';
      case AppHomeRole.aliado:
        return 'Ítems en este flujo: ${tituloCheckoutGrupoAliado(lines)}';
      case AppHomeRole.administrador:
        return 'Ítems en este flujo: ${tituloCheckoutGrupoAliado(lines)}';
    }
  }

  String _timelineLineLabelForDetail(TransactionRequestModel line) {
    final uid = SupabaseService.currentUserId;
    switch (widget.homeRole) {
      case AppHomeRole.importador:
        return line.etiquetaGestionLineaImportador(uid);
      case AppHomeRole.aliado:
        return line.etiquetaGestionLineaAliado();
      case AppHomeRole.administrador:
        final imp = line.ownerBusinessName?.trim();
        final p = line.productName?.trim();
        if (p != null && p.isNotEmpty && imp != null && imp.isNotEmpty) {
          if (p.contains(imp)) return p;
          return '$p · $imp';
        }
        return p ?? imp ?? line.id.substring(0, 8);
    }
  }

  Widget _summaryReferenceBlock(TransactionRequestModel r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Referencias',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          r.id,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            height: 1.35,
          ),
        ),
        if (r.productSku != null && r.productSku!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'SKU: ${r.productSku}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip('Cantidad: ${r.cantidad}'),
            if (r.precioTotalBsUi != null)
              _chip(
                'Referencia en Bs: ${formatVesAmount(r.precioTotalBsUi!)}',
              ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.brandBlue,
          ),
        ),
      ),
    );
  }

  Widget _contactByRole(TransactionRequestModel r) {
    switch (widget.homeRole) {
      case AppHomeRole.aliado:
        return TransactionRequestImporterContactSection(
          request: r,
          embedded: false,
        );
      case AppHomeRole.importador:
        return TransactionRequestAliadoContactSection(request: r);
      case AppHomeRole.administrador:
        return TransactionRequestPartiesContactSection(request: r);
    }
  }

  Widget _noteCard(
    String note, {
    required String title,
    _NoteCardTone tone = _NoteCardTone.info,
  }) {
    late Color bg;
    late Color border;
    late Color titleColor;
    switch (tone) {
      case _NoteCardTone.info:
        bg = AppColors.brandBlueContainer;
        border = AppColors.brandAccent.withOpacity(0.35);
        titleColor = AppColors.brandBlue;
      case _NoteCardTone.warning:
        bg = Colors.amber.shade50;
        border = Colors.amber.shade300;
        titleColor = Colors.amber.shade900;
      case _NoteCardTone.danger:
        bg = Colors.red.shade50;
        border = Colors.red.shade200;
        titleColor = Colors.red.shade900;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(height: 1.35)),
          ],
        ),
      ),
    );
  }
}

List<Widget> _detailEtaBanners(List<TransactionRequestModel> lines) {
  final out = <Widget>[];
  for (final chunk in groupCheckoutLinesByImportador(lines)) {
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

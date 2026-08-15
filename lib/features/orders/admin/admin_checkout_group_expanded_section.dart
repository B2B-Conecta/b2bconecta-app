import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/admin_order_panel_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'admin_order_pre_transit_section.dart';
import 'package:motolink_pro_app/features/payments/admin_pago_revision_section.dart';
import 'package:motolink_pro_app/features/orders/shared/courier_timeline_widget.dart';
import 'package:motolink_pro_app/features/payments/efectivo_respaldo_registrar.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_aliado_solicitud_section.dart';
import 'package:motolink_pro_app/features/orders/shared/moroso_order_visual.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/orders/shared/order_motolink_thread_section.dart';
import 'transaction_request_admin_sections.dart';

/// Detalle admin de carrito: un proveedor a la vez (timeline, pago, chat único).
class AdminCheckoutGroupExpandedSection extends StatefulWidget {
  const AdminCheckoutGroupExpandedSection({
    super.key,
    required this.lines,
    required this.onRefresh,
    this.onMarcarEnTransito,
    this.onAnularMotolink,
    this.anularBusyId,
    this.morosidadFooter,
  });

  final List<TransactionRequestModel> lines;
  final VoidCallback onRefresh;
  final void Function(TransactionRequestModel line)? onMarcarEnTransito;
  final void Function(TransactionRequestModel line)? onAnularMotolink;
  final String? anularBusyId;
  final Widget? morosidadFooter;

  @override
  State<AdminCheckoutGroupExpandedSection> createState() =>
      _AdminCheckoutGroupExpandedSectionState();
}

class _AdminCheckoutGroupExpandedSectionState
    extends State<AdminCheckoutGroupExpandedSection> {
  int _selectedImporter = 0;

  @override
  Widget build(BuildContext context) {
    final chunks = groupCheckoutLinesByImportador(widget.lines);
    if (chunks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'No se encontraron líneas del carrito.',
          style: TextStyle(fontSize: 12, color: AppColors.brandAccent),
        ),
      );
    }

    final idx = _selectedImporter.clamp(0, chunks.length - 1);
    final chunk = chunks[idx];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (adminCheckoutGroupEsMoroso(widget.lines)) ...[
          MorosoOrderDetailNotice(
            request: adminCheckoutGroupMorosoRef(widget.lines),
            compact: true,
          ),
          const SizedBox(height: 10),
        ],
        Text(
          chunks.length > 1
              ? 'Avance por proveedor'
              : 'Proveedor',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (chunks.length > 1)
          _AdminImporterChipRow(
            chunks: chunks,
            selectedIndex: idx,
            onSelected: (i) => setState(() => _selectedImporter = i),
          ),
        if (chunks.length > 1) const SizedBox(height: 10),
        _AdminImporterOperationsPanel(
          key: ValueKey<String>(chunk.map((e) => e.id).join('-')),
          chunk: chunk,
          allLines: widget.lines,
          index: idx + 1,
          total: chunks.length,
          showImporterCommission: true,
          onRefresh: widget.onRefresh,
          onMarcarEnTransito: widget.onMarcarEnTransito,
          onAnularMotolink: widget.onAnularMotolink,
          anularBusyId: widget.anularBusyId,
        ),
        if (widget.morosidadFooter != null) ...[
          const SizedBox(height: 12),
          widget.morosidadFooter!,
        ],
      ],
    );
  }
}

class _AdminImporterChipRow extends StatelessWidget {
  const _AdminImporterChipRow({
    required this.chunks,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<List<TransactionRequestModel>> chunks;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(chunks.length, (i) {
          final chunk = chunks[i];
          final name =
              chunk.first.ownerBusinessName?.trim() ?? 'Importador ${i + 1}';
          final selected = i == selectedIndex;
          final status = adminLineStatusChipLabel(chunk.first);
          final moroso = chunk.any((r) => r.esPedidoMoroso);

          return Padding(
            padding: EdgeInsets.only(right: i < chunks.length - 1 ? 8 : 0),
            child: Material(
              color: selected
                  ? AppColors.brandBlue.withOpacity(0.18)
                  : AppColors.surfaceTinted,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.brandBlue : AppColors.borderSubtle,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chunks.length > 1 ? 'Proveedor ${i + 1}' : name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppColors.brandBlue
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (moroso)
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.deepOrange.shade700,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AdminImporterOperationsPanel extends StatelessWidget {
  const _AdminImporterOperationsPanel({
    super.key,
    required this.chunk,
    required this.allLines,
    required this.index,
    required this.total,
    required this.showImporterCommission,
    required this.onRefresh,
    this.onMarcarEnTransito,
    this.onAnularMotolink,
    this.anularBusyId,
  });

  final List<TransactionRequestModel> chunk;
  final List<TransactionRequestModel> allLines;
  final int index;
  final int total;
  final bool showImporterCommission;
  final VoidCallback onRefresh;
  final void Function(TransactionRequestModel line)? onMarcarEnTransito;
  final void Function(TransactionRequestModel line)? onAnularMotolink;
  final String? anularBusyId;

  @override
  Widget build(BuildContext context) {
    final anchor = chunk.first;
    final impName = anchor.ownerBusinessName ?? 'Importador';

    final commissionSubtitle = showImporterCommission
        ? orderCardCommissionSubtitle(chunk)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Proveedor $index de $total · $impName',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        OrderCardCollapsibleSection(
          title: 'Importador',
          subtitle: orderCardPartySubtitle(
            businessName: anchor.ownerBusinessName,
            ciudad: anchor.ownerCiudad,
            estado: anchor.ownerEstado,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TransactionRequestImporterContactSection(
                request: anchor,
                embedded: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in chunk)
                    OrderStatusHeaderChips(
                      statusLabel: adminLineStatusChipLabel(r),
                      showMoroso: r.esPedidoMoroso,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Productos',
          subtitle: orderCardProductosSubtitle(
            chunk,
            viewer: PedidoDesgloseViewer.importador,
          ),
          initiallyExpanded: true,
          child: TransactionRequestProductosDesgloseSection(
            lines: chunk,
            compact: true,
            viewer: PedidoDesgloseViewer.importador,
            showImporterGroupHeaders: false,
            hideSectionTitle: true,
          ),
        ),
        if (commissionSubtitle != null) ...[
          const SizedBox(height: kOrderCardSectionGap),
          OrderCardCollapsibleSection(
            title: 'Comisión B2B Conecta',
            subtitle: commissionSubtitle,
            infoMessage:
                'Comisión devengada o estimada según el estado del pedido.',
            child: AdminCheckoutGroupCommissionSummary(
              lines: allLines,
              importerChunk: chunk,
              suppressOuterTitle: true,
            ),
          ),
        ],
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Seguimiento',
          subtitle: orderCardTimelineSubtitle(anchor),
          initiallyExpanded: orderCardTimelineInitiallyExpanded(anchor),
          child: CourierTimelineWidget(
            request: anchor,
            compact: true,
            viewerRole: AppHomeRole.administrador,
            showHeading: false,
          ),
        ),
        const SizedBox(height: kOrderCardSectionGap),
        if (onAnularMotolink != null &&
                chunk.any((r) => r.motolinkPuedeAnularComoAdmin)) ...[
              const SizedBox(height: 8),
              for (final r in chunk.where((x) => x.motolinkPuedeAnularComoAdmin))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton.icon(
                    onPressed: anularBusyId != null
                        ? null
                        : () => onAnularMotolink!(r),
                    icon: Icon(
                      Icons.gpp_bad_outlined,
                      size: 18,
                      color: Colors.red.shade800,
                    ),
                    label: Text(
                      anularBusyId == r.id
                          ? 'Anulando…'
                          : 'Anular línea · ${r.productName ?? r.id.substring(0, 8)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade800,
                    ),
                  ),
                ),
            ],
            if (chunk.any(
              (r) =>
                  r.status == TransactionRequestStatus.enTransito ||
                  r.status == TransactionRequestStatus.entregado,
            )) ...[
              const SizedBox(height: 8),
              for (final r in chunk.where(
                (x) =>
                    x.status == TransactionRequestStatus.enTransito ||
                    x.status == TransactionRequestStatus.entregado,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EfectivoRespaldoRegistrar(
                    request: r,
                    onRegistered: onRefresh,
                  ),
                ),
            ],
            if (chunk.any(
              (r) =>
                  r.status == TransactionRequestStatus.enPreparacion ||
                  r.status == TransactionRequestStatus.pedidoListo,
            )) ...[
              AdminOrderPreTransitSection(
                request: chunk.firstWhere(
                  (r) =>
                      r.status == TransactionRequestStatus.enPreparacion ||
                      r.status == TransactionRequestStatus.pedidoListo,
                  orElse: () => anchor,
                ),
                onRefresh: onRefresh,
                onMarcarEnTransito: () {
                  final line = chunk.firstWhere(
                    (r) =>
                        r.status == TransactionRequestStatus.enPreparacion ||
                        r.status == TransactionRequestStatus.pedidoListo,
                    orElse: () => anchor,
                  );
                  onMarcarEnTransito?.call(line);
                },
              ),
            ],
            if (chunk.any(
              (r) =>
                  r.hasProveedorFactura &&
                  (r.status == TransactionRequestStatus.enTransito ||
                      r.status == TransactionRequestStatus.entregado),
            )) ...[
              const SizedBox(height: 8),
              for (final r in chunk.where(
                (x) =>
                    x.hasProveedorFactura &&
                    (x.status == TransactionRequestStatus.enTransito ||
                        x.status == TransactionRequestStatus.entregado),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdminPagoRevisionSection(
                    request: r,
                    onRefresh: onRefresh,
                    includeSectionTitle: chunk.length > 1,
                    highlightEntregadoPagado:
                        r.status == TransactionRequestStatus.entregado &&
                        r.pagoEstadoRevisionEfectivo ==
                            PagoRevisionEstado.aprobado,
                  ),
                ),
            ],
        OrderCardCollapsibleSection(
          title: 'Mensajes',
          subtitle: 'Hilo con aliado, importador y B2B Conecta',
          infoMessage: OrderSectionHelp.chatPedido,
          child: OrderMotolinkThreadSection(
            key: ValueKey<String>(
              'trm-admin-grp-${anchor.ownerId}-${chunk.map((e) => e.id).join("-")}',
            ),
            transactionRequestId: anchor.id,
            mergedThreadRequestIds:
                chunk.length > 1 ? chunk.map((e) => e.id).toList() : null,
            allowReplyAsAliado: false,
            allowReplyAsAdmin: true,
            onThreadChanged: onRefresh,
            suppressBuiltinTitle: true,
            suppressInlineHelp: true,
          ),
        ),
      ],
    );
  }
}

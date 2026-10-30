import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'aliado_order_grouping.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';
import 'order_list_row.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';
export 'order_list_entry.dart';
export 'order_list_row.dart' show OrderStatusTag;

/// Full-width list and dedicated detail, preserving the mounted list on return.
class OrderWorkspace extends StatelessWidget {
  const OrderWorkspace(
      {super.key,
      required this.groups,
      required this.selectedKey,
      required this.onSelect,
      required this.onClose,
      required this.controls,
      required this.detailBuilder,
      required this.onRefresh,
      required this.resetKey,
      required this.onClearFilters,
      this.loading = false,
      this.viewerRole = AppHomeRole.aliado,
      this.groupKey,
      this.emptyMessage});
  final List<List<TransactionRequestModel>> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;
  final Widget controls;
  final Widget Function(List<TransactionRequestModel>) detailBuilder;
  final Future<void> Function() onRefresh;
  final Object resetKey;
  final VoidCallback onClearFilters;
  final bool loading;
  final AppHomeRole viewerRole;

  /// Clave de fila; por defecto [checkoutGroupExpandKey].
  final String Function(List<TransactionRequestModel>)? groupKey;

  /// Mensaje cuando la lista está vacía (p. ej. alcance sin resultados).
  final String? emptyMessage;

  String _keyOf(List<TransactionRequestModel> g) =>
      (groupKey ?? checkoutGroupExpandKey)(g);

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final selected =
            groups.where((g) => _keyOf(g) == selectedKey).firstOrNull;
        final detailOpen = selected != null;
        return ScrollCompactLayout(
            enabled: viewerRole == AppHomeRole.aliado,
            resetKey: (selectedKey, resetKey),
            collapseHeadingWhenCompact: !detailOpen,
            builder: (context, compact) => PopScope<Object?>(
                  canPop: !detailOpen,
                  onPopInvokedWithResult: (didPop, result) {
                    if (!didPop && detailOpen) onClose();
                  },
                  child: ColoredBox(
                      color: OrderListColors.of(context).background,
                      child: AnimatedPadding(
                        duration: ScrollCompactLayout.motionDuration(context),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.fromLTRB(
                            constraints.maxWidth >= 700 ? 20 : 12,
                            compact
                                ? 4
                                : (constraints.maxWidth >= 700 ? 20 : 12),
                            constraints.maxWidth >= 700 ? 20 : 12,
                            detailOpen ? 20 : 4),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (loading)
                                const LinearProgressIndicator(minHeight: 2),
                              if (!detailOpen) ...[
                                controls,
                                SizedBox(height: compact ? 4 : 12)
                              ],
                              Expanded(
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    Flexible(
                                        flex: detailOpen ? 0 : 1,
                                        fit: detailOpen
                                            ? FlexFit.loose
                                            : FlexFit.tight,
                                        child: Offstage(
                                            offstage: detailOpen,
                                            child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    maxWidth:
                                                        constraints.maxWidth),
                                                child: _surface(context,
                                                    LayoutBuilder(builder:
                                                        (context,
                                                            listConstraints) {
                                                  final table = listConstraints
                                                              .maxWidth >=
                                                          900 &&
                                                      MediaQuery.textScalerOf(
                                                                  context)
                                                              .scale(14) <
                                                          20;
                                                  return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        if (table)
                                                          OrderListColumnsHeader(
                                                            partyLabel: switch (
                                                                viewerRole) {
                                                              AppHomeRole
                                                                    .aliado =>
                                                                'Proveedor',
                                                              AppHomeRole
                                                                    .importador =>
                                                                'Tienda',
                                                              AppHomeRole
                                                                    .administrador =>
                                                                'Partes',
                                                            },
                                                          ),
                                                        Expanded(
                                                            child: groups
                                                                    .isEmpty
                                                                ? _OrdersEmpty(
                                                                    onClear:
                                                                        onClearFilters,
                                                                    message:
                                                                        emptyMessage,
                                                                  )
                                                                : PagedItems<
                                                                    List<
                                                                        TransactionRequestModel>>(
                                                                    items:
                                                                        groups,
                                                                    itemKey:
                                                                        _keyOf,
                                                                    pagerAtBottom:
                                                                        true,
                                                                    pageBarBottomPadding:
                                                                        0,
                                                                    separator:
                                                                        8,
                                                                    pageBarBuilder: (bar) =>
                                                                        _pageFooter(
                                                                            context,
                                                                            bar),
                                                                    resetKey:
                                                                        resetKey,
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        top: 8,
                                                                        bottom:
                                                                            8),
                                                                    onRefresh:
                                                                        onRefresh,
                                                                    itemBuilder: (g) => OrderListRow(
                                                                        entry: OrderListEntry(
                                                                            g,
                                                                            viewerRole:
                                                                                viewerRole),
                                                                        table:
                                                                            table,
                                                                        selected:
                                                                            _keyOf(g) ==
                                                                                selectedKey,
                                                                        onOpen: () =>
                                                                            onSelect(_keyOf(g))),
                                                                  )),
                                                      ]);
                                                }))))),
                                    if (selected != null) ...[
                                      Expanded(
                                          flex: 1,
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                AnimatedPadding(
                                                    duration:
                                                        ScrollCompactLayout
                                                            .motionDuration(
                                                                context),
                                                    curve: Curves.easeOutCubic,
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                            16,
                                                            compact ? 0 : 8,
                                                            8,
                                                            compact ? 0 : 8),
                                                    child: Row(children: [
                                                      IconButton(
                                                          onPressed: onClose,
                                                          tooltip:
                                                              'Volver a pedidos',
                                                          icon: const Icon(Icons
                                                              .arrow_back)),
                                                      Expanded(
                                                          child: Text(
                                                              'Pedido ${OrderListEntry(selected, viewerRole: viewerRole).reference}',
                                                              style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: AppColors
                                                                      .textPrimary))),
                                                    ])),
                                                SizedBox(
                                                    height: compact ? 0 : 12),
                                                Expanded(
                                                    child: SingleChildScrollView(
                                                        key: ValueKey(
                                                            'order-detail-${_keyOf(selected)}'),
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 20),
                                                        child: detailBuilder(
                                                            selected))),
                                              ])),
                                    ],
                                  ])),
                            ]),
                      )),
                ));
      });

  Widget _surface(BuildContext context, Widget child) =>
      ColoredBox(color: OrderListColors.of(context).background, child: child);

  Widget _pageFooter(BuildContext context, Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        decoration: BoxDecoration(
          color: OrderListColors.of(context).background,
          border: Border(
              top: BorderSide(color: OrderListColors.of(context).border)),
        ),
        child: child,
      );
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.onClear, this.message});
  final VoidCallback onClear;
  final String? message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 32, color: AppColors.textSecondary),
            SizedBox(height: compact ? 4 : 12),
            Text(
              message ?? 'No encontramos pedidos con estos filtros.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: onClear, child: const Text('Ver todos los pedidos')),
          ])));
}

/// Shipping progress only; payment is negotiated independently of delivery.
class OrderFulfilmentProgress extends StatelessWidget {
  const OrderFulfilmentProgress(
      {super.key,
      required this.lines,
      this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16)});
  final List<TransactionRequestModel> lines;
  final EdgeInsetsGeometry padding;
  static int phase(String status) => orderShippingPhase(status);
  @override
  Widget build(BuildContext context) {
    final phases =
        lines.map((l) => phase(l.status)).where((p) => p >= 0).toList();
    if (phases.isEmpty) return const SizedBox.shrink();
    final current = phases.reduce((a, b) => a < b ? a : b);
    final done =
        lines.every((l) => l.status == TransactionRequestStatus.entregado);
    const labels = ['Confirmación', 'Preparación', 'En camino', 'Entrega'];
    return Padding(
        padding: padding,
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 390 ||
                  MediaQuery.textScalerOf(context).scale(12) > 16
              ? 2
              : 4;
          return Wrap(runSpacing: 12, children: [
            for (var i = 0; i < labels.length; i++)
              SizedBox(
                  width: constraints.maxWidth / columns,
                  child: Row(children: [
                    Icon(
                        i < current || done
                            ? Icons.check_circle
                            : i == current
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                        size: 18,
                        color: i <= current
                            ? Theme.of(context).colorScheme.primary
                            : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(labels[i],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: i == current
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: i <= current
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary))),
                  ]))
          ]);
        }));
  }
}

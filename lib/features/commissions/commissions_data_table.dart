import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_fiscal.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_model.dart';

/// Etiqueta operativa de estado para la tabla de liquidaciones.
String commissionsSettlementStatusChipLabel(CommissionSettlementModel s) {
  if (s.isAnulado) return 'Anulado';
  if (s.isBorrador) return 'Borrador';
  if (s.pagoEnRevision) return 'En revisión';
  if (s.isPagado) return 'Liquidado';
  if (s.isEmitido) return 'Pendiente';
  return CommissionSettlementModel.statusLabelEs(s.status);
}

/// Tabla corporativa de cortes / liquidaciones (`CommissionsModule`).
class CommissionsDataTable extends StatefulWidget {
  const CommissionsDataTable({
    super.key,
    required this.rows,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusFilter,
    required this.onSearchChanged,
    required this.expandedIds,
    required this.onToggleExpand,
    required this.detailBuilder,
    required this.onRowAction,
    this.busy = false,
    this.tasaBcv,
    this.onOpenAdvancedFilters,
    this.activeFilterCount = 0,
    this.onClearFilters,
    this.resetKey,
  });

  final List<CommissionSettlementModel> rows;
  final TextEditingController searchController;
  /// `null` = Todas · `pagado` · `emitido` (pendientes).
  final String? statusFilter;
  final ValueChanged<String?> onStatusFilter;
  final ValueChanged<String> onSearchChanged;
  final Set<String> expandedIds;
  final ValueChanged<String> onToggleExpand;
  final Widget Function(CommissionSettlementModel settlement) detailBuilder;
  final void Function(CommissionSettlementModel settlement, String actionId)
      onRowAction;
  final bool busy;
  final double? tasaBcv;
  final VoidCallback? onOpenAdvancedFilters;
  final int activeFilterCount;
  final VoidCallback? onClearFilters;
  final Object? resetKey;

  @override
  State<CommissionsDataTable> createState() => _CommissionsDataTableState();
}

class _CommissionsDataTableState extends State<CommissionsDataTable> {
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;
  Object? _lastReset;

  @override
  void didUpdateWidget(covariant CommissionsDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != _lastReset) {
      _lastReset = widget.resetKey;
      _pageIndex = 0;
    }
    if (oldWidget.rows.length != widget.rows.length) {
      final maxPage = widget.rows.isEmpty
          ? 0
          : ((widget.rows.length - 1) / _pageSize).floor();
      if (_pageIndex > maxPage) _pageIndex = maxPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final page = sliceListPage(
      items: widget.rows,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final statusPills = [
      B2bDataTableFilterPill(
        label: 'Todas',
        selected: widget.statusFilter == null,
        onTap: () {
          _pageIndex = 0;
          widget.onStatusFilter(null);
        },
      ),
      B2bDataTableFilterPill(
        label: 'Liquidadas',
        selected: widget.statusFilter == 'pagado',
        onTap: () {
          _pageIndex = 0;
          widget.onStatusFilter('pagado');
        },
      ),
      B2bDataTableFilterPill(
        label: 'Pendientes',
        selected: widget.statusFilter == 'emitido',
        onTap: () {
          _pageIndex = 0;
          widget.onStatusFilter('emitido');
        },
      ),
    ];

    return B2bDataTableShell(
      padding: const EdgeInsets.all(12),
      toolbar: B2bDataTableToolbar(
        searchController: widget.searchController,
        searchHint: 'Buscar lote, referencia o importador…',
        onSearchChanged: (q) {
          _pageIndex = 0;
          widget.onSearchChanged(q);
        },
        filters: mobile ? const [] : statusPills,
        trailing: [
          if (mobile)
            OutlinedButton.icon(
              onPressed: () => _openMobileFilters(context, theme),
              icon: LucideIcon(
                LucideGlyph.slidersHorizontal,
                size: 16,
                color: theme.brand,
              ),
              label: Text(
                widget.statusFilter == null && widget.activeFilterCount == 0
                    ? 'Filtrar'
                    : 'Filtrar (${(widget.statusFilter == null ? 0 : 1) + widget.activeFilterCount})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.brand,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.brand,
                side: BorderSide(color: theme.borderSubtle),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            )
          else if (widget.onOpenAdvancedFilters != null)
            IconButton(
              tooltip: 'Más filtros',
              onPressed: widget.onOpenAdvancedFilters,
              icon: Badge(
                isLabelVisible: widget.activeFilterCount > 0,
                label: Text('${widget.activeFilterCount}'),
                backgroundColor: theme.brand,
                child: LucideIcon(
                  LucideGlyph.slidersHorizontal,
                  size: 18,
                  color: theme.textSecondary,
                ),
              ),
            ),
        ],
      ),
      header: mobile
          ? null
          : const B2bDataTableHeader(
              cells: [
                B2bDataTableHeaderCell(label: 'Lote / Ref.', flex: 3),
                B2bDataTableHeaderCell(label: 'Periodo', flex: 3),
                B2bDataTableHeaderCell(label: 'Importador', flex: 3),
                B2bDataTableHeaderCell(label: 'Monto', flex: 2),
                B2bDataTableHeaderCell(label: 'Estado', flex: 2),
              ],
            ),
      empty: widget.rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Column(
                children: [
                  LucideIcon(
                    LucideGlyph.searchX,
                    size: 28,
                    color: theme.textMuted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ningún corte coincide con la búsqueda o los filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  ),
                  if (widget.onClearFilters != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onClearFilters,
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                ],
              ),
            )
          : null,
      rows: [
        for (var i = 0; i < page.length; i++) ...[
          B2bDataTableZebraRow(
            zebra: i.isOdd,
            isLast: i == page.length - 1 &&
                !widget.expandedIds.contains(page[i].id),
            padding: EdgeInsets.zero,
            onTap: () => widget.onToggleExpand(page[i].id),
            child: _SettlementTableRow(
              settlement: page[i],
              tasaBcv: widget.tasaBcv,
              busy: widget.busy,
              expanded: widget.expandedIds.contains(page[i].id),
              compact: mobile,
              onAction: (id) => widget.onRowAction(page[i], id),
            ),
          ),
          if (widget.expandedIds.contains(page[i].id))
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.surfaceSubtle,
                border: Border(
                  bottom: BorderSide(color: theme.borderSubtle),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: widget.detailBuilder(page[i]),
            ),
        ],
      ],
      footer: ListPageBar(
        total: widget.rows.length,
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        alwaysShow: widget.rows.isNotEmpty,
        entityLabel: 'cortes',
        onPageIndex: (i) => setState(() => _pageIndex = i),
        onPageSize: (size) => setState(() {
          _pageSize = size;
          _pageIndex = 0;
        }),
      ),
    );
  }

  Future<void> _openMobileFilters(
    BuildContext context,
    B2BThemeExtension theme,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.dialogSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Filtrar cortes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Estado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    B2bDataTableFilterPill(
                      label: 'Todas',
                      selected: widget.statusFilter == null,
                      onTap: () {
                        setState(() => _pageIndex = 0);
                        widget.onStatusFilter(null);
                        Navigator.of(ctx).pop();
                      },
                    ),
                    B2bDataTableFilterPill(
                      label: 'Liquidadas',
                      selected: widget.statusFilter == 'pagado',
                      onTap: () {
                        setState(() => _pageIndex = 0);
                        widget.onStatusFilter('pagado');
                        Navigator.of(ctx).pop();
                      },
                    ),
                    B2bDataTableFilterPill(
                      label: 'Pendientes',
                      selected: widget.statusFilter == 'emitido',
                      onTap: () {
                        setState(() => _pageIndex = 0);
                        widget.onStatusFilter('emitido');
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
                if (widget.onOpenAdvancedFilters != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.onOpenAdvancedFilters!();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brand,
                      foregroundColor: theme.surfaceCard,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Más filtros…'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Listo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettlementTableRow extends StatelessWidget {
  const _SettlementTableRow({
    required this.settlement,
    required this.onAction,
    required this.expanded,
    this.tasaBcv,
    this.busy = false,
    this.compact = false,
  });

  final CommissionSettlementModel settlement;
  final ValueChanged<String> onAction;
  final bool expanded;
  final double? tasaBcv;
  final bool busy;
  final bool compact;

  List<B2bDataRowAction> get _actions {
    final s = settlement;
    final out = <B2bDataRowAction>[
      const B2bDataRowAction(
        id: 'toggle',
        label: 'Ver detalle',
        glyph: LucideGlyph.eye,
      ),
    ];
    if ((s.isEmitido || s.isPagado) && s.tieneFacturaPdf) {
      out.add(
        const B2bDataRowAction(
          id: 'pdf',
          label: 'Descargar PDF',
          glyph: LucideGlyph.download,
        ),
      );
      out.add(
        const B2bDataRowAction(
          id: 'regen_pdf',
          label: 'Regenerar PDF',
          glyph: LucideGlyph.refreshCw,
        ),
      );
    } else if ((s.isEmitido || s.isPagado) && !s.tieneFacturaPdf) {
      out.add(
        const B2bDataRowAction(
          id: 'gen_pdf',
          label: 'Generar PDF',
          glyph: LucideGlyph.fileText,
        ),
      );
    }
    if (!s.isBorrador && !s.isAnulado) {
      out.add(
        const B2bDataRowAction(
          id: 'csv',
          label: 'Copiar CSV',
          glyph: LucideGlyph.copy,
        ),
      );
    }
    if (s.canAnular) {
      out.add(
        const B2bDataRowAction(
          id: 'anular',
          label: 'Anular corte',
          glyph: LucideGlyph.trash2,
          destructive: true,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final s = settlement;
    final ref = s.invoiceReference?.trim() ?? '';
    final name = s.importadorBusinessName?.trim();
    final status = commissionsSettlementStatusChipLabel(s);
    final rate = tasaBcv;
    final bs = rate != null && rate > 0 ? s.totalCobroUsd * rate : null;

    final chevron = LucideIcon(
      expanded ? LucideGlyph.chevronDown : LucideGlyph.chevronRight,
      size: 14,
      color: theme.textMuted,
    );
    final actions = B2bDataRowActionsMenu(
      busy: busy,
      actions: _actions,
      onSelected: onAction,
    );
    final amountCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REF ${formatRefAmount(s.totalCobroUsd)}',
          style: TextStyle(
            fontSize: compact ? 14 : 13,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        Text(
          bs == null ? 'Bs —' : formatBsLabel(bs),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.textMuted,
          ),
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                chevron,
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ref.isNotEmpty ? ref : 'Sin referencia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
                _StatusChip(label: status, settlement: s),
                actions,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (name == null || name.isEmpty) ? 'Importador' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.periodLabelEs,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            amountCol,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                chevron,
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ref.isNotEmpty ? ref : 'Sin referencia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              s.periodLabelEs,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              (name == null || name.isEmpty) ? 'Importador' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
          ),
          Expanded(flex: 2, child: amountCol),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusChip(label: status, settlement: s),
            ),
          ),
          SizedBox(width: 48, child: actions),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.settlement});

  final String label;
  final CommissionSettlementModel settlement;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final s = settlement;
    final Color bg;
    final Color fg;
    if (s.isPagado) {
      bg = theme.successBg;
      fg = theme.successFg;
    } else if (s.pagoEnRevision) {
      bg = theme.brandContainer;
      fg = theme.brand;
    } else if (s.isAnulado) {
      bg = theme.surfaceSubtle;
      fg = theme.textMuted;
    } else if (s.isEmitido) {
      bg = theme.brandContainer;
      fg = theme.brand;
    } else {
      bg = theme.surfaceSubtle;
      fg = theme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import 'commission_collected_income_period.dart';
import 'commission_collected_income_report.dart';
import 'commission_settlement_document_type.dart';

/// Reporte de comisión cobrada (paid_at, America/Caracas) para admin e importador.
class CommissionCollectedIncomeCard extends StatefulWidget {
  const CommissionCollectedIncomeCard({
    super.key,
    required this.isAdmin,
    this.onOpenSettlement,
    this.onFilterImportador,
    this.onFilterDocumentType,
    this.tasaBcv,
  });

  final bool isAdmin;
  final ValueChanged<String>? onOpenSettlement;
  final ValueChanged<String>? onFilterImportador;
  final ValueChanged<CommissionSettlementDocumentType>? onFilterDocumentType;
  final double? tasaBcv;

  @override
  State<CommissionCollectedIncomeCard> createState() =>
      _CommissionCollectedIncomeCardState();
}

class _CommissionCollectedIncomeCardState
    extends State<CommissionCollectedIncomeCard> {
  CommissionCollectedIncomePreset _preset =
      CommissionCollectedIncomePreset.thisMonth;
  DateTime? _customFrom;
  DateTime? _customTo;
  CommissionCollectedIncomeReport? _report;
  bool _loading = true;
  String? _error;
  bool _invalidRange = false;
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  CommissionCollectedIncomePeriod get _period =>
      CommissionCollectedIncomePeriod.fromPreset(
        _preset,
        customFrom: _customFrom,
        customTo: _customTo,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final period = _period;
    if (period.isInvalidRange) {
      setState(() {
        _invalidRange = true;
        _loading = false;
        _error = null;
        _report = null;
      });
      return;
    }
    setState(() {
      _invalidRange = false;
      _loading = true;
      _error = null;
      _pageIndex = 0;
    });
    try {
      final report = await SupabaseService.fetchCollectedCommissionReport(
        from: period.from,
        to: period.to,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final now = CommissionCollectedIncomePeriod.dateOnlyCaracas();
    final from = await showAppDatePicker(
      context: context,
      initialDate: _customFrom ?? _period.from,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Desde',
    );
    if (from == null || !mounted) return;
    final to = await showAppDatePicker(
      context: context,
      initialDate: _customTo ?? from,
      firstDate: from,
      lastDate: now,
      helpText: 'Hasta',
    );
    if (to == null || !mounted) return;
    setState(() {
      _preset = CommissionCollectedIncomePreset.custom;
      _customFrom = DateTime(from.year, from.month, from.day);
      _customTo = DateTime(to.year, to.month, to.day);
    });
    await _load();
  }

  void _selectPreset(CommissionCollectedIncomePreset preset) {
    if (preset == CommissionCollectedIncomePreset.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _preset = preset);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final report = _report;
    final settlements = report?.settlements ?? const [];
    final page = sliceListPage(
      items: settlements,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );

    Widget? emptyBody;
    if (_invalidRange) {
      emptyBody = _message(
        theme,
        'La fecha inicial no puede ser posterior a la final.',
        error: true,
      );
    } else if (_loading) {
      emptyBody = Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: theme.brand)),
      );
    } else if (_error != null) {
      emptyBody = Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          children: [
            Text(
              'No se pudo cargar el reporte.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    } else if (report == null || report.isEmpty) {
      emptyBody = _message(
        theme,
        'No hay comisión cobrada en este período (${_period.labelEs}).',
      );
    }

    return B2bDataTableShell(
      padding: const EdgeInsets.all(12),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAdmin
                          ? 'Ingresos cobrados'
                          : 'Comisión cobrada',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Solo cortes pagados · America/Caracas',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (report != null && !report.isEmpty) ...[
                const SizedBox(width: 12),
                _TotalBadge(
                  usd: report.totalCollectedUsd,
                  tasaBcv: widget.tasaBcv,
                  ops: report.operationCount,
                  variationPct:
                      report.canShowVariation ? report.variationPct : null,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in CommissionCollectedIncomePreset.values)
                B2bDataTableFilterPill(
                  label: switch (preset) {
                    CommissionCollectedIncomePreset.today => 'Hoy',
                    CommissionCollectedIncomePreset.last7Days => '7 días',
                    CommissionCollectedIncomePreset.thisMonth => 'Este mes',
                    CommissionCollectedIncomePreset.previousMonth =>
                      'Mes anterior',
                    CommissionCollectedIncomePreset.custom => 'Rango',
                  },
                  selected: _preset == preset,
                  onTap: () => _selectPreset(preset),
                ),
            ],
          ),
        ],
      ),
      header: const B2bDataTableHeader(
        cells: [
          B2bDataTableHeaderCell(label: 'Corte / Ref.', flex: 3),
          B2bDataTableHeaderCell(label: 'Importador', flex: 3),
          B2bDataTableHeaderCell(label: 'Cobrado', flex: 2),
          B2bDataTableHeaderCell(label: 'Ops.', flex: 1),
          B2bDataTableHeaderCell(label: 'Fecha', flex: 2),
        ],
        showTrailingSlot: false,
      ),
      empty: emptyBody,
      rows: [
        for (var i = 0; i < page.length; i++)
          B2bDataTableZebraRow(
            zebra: i.isOdd,
            isLast: i == page.length - 1,
            onTap: () =>
                widget.onOpenSettlement?.call(page[i].settlementId),
            child: _IncomeSettlementRow(
              row: page[i],
              tasaBcv: widget.tasaBcv,
              onFilterImportador: widget.isAdmin
                  ? widget.onFilterImportador
                  : null,
            ),
          ),
      ],
      footer: ListPageBar(
        total: settlements.length,
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        alwaysShow: settlements.isNotEmpty,
        entityLabel: 'cobros',
        onPageIndex: (i) => setState(() => _pageIndex = i),
        onPageSize: (size) => setState(() {
          _pageSize = size;
          _pageIndex = 0;
        }),
      ),
    );
  }

  Widget _message(B2BThemeExtension theme, String text, {bool error = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: error
                ? Theme.of(context).colorScheme.error
                : theme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({
    required this.usd,
    required this.ops,
    this.tasaBcv,
    this.variationPct,
  });

  final double usd;
  final int ops;
  final double? tasaBcv;
  final double? variationPct;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final rate = tasaBcv;
    final bs = rate != null && rate > 0 ? usd * rate : null;
    final variation = variationPct;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.brandContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'REF ${formatRefAmount(usd)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          Text(
            bs == null ? '$ops op.' : '${formatBsLabel(bs)} · $ops op.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
          if (variation != null)
            Text(
              '${variation >= 0 ? '+' : ''}${variation.toStringAsFixed(1)} % vs ant.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: variation >= 0 ? theme.successFg : theme.brand,
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomeSettlementRow extends StatelessWidget {
  const _IncomeSettlementRow({
    required this.row,
    this.tasaBcv,
    this.onFilterImportador,
  });

  final CommissionCollectedIncomeSettlementRow row;
  final double? tasaBcv;
  final ValueChanged<String>? onFilterImportador;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final ref = (row.invoiceReference?.trim().isNotEmpty == true)
        ? row.invoiceReference!.trim()
        : row.settlementId.substring(0, 8);
    final rate = tasaBcv;
    final bs = rate != null && rate > 0 ? row.totalCollectedUsd * rate : null;
    final doc = CommissionSettlementDocumentType.effective(row.documentType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  doc.labelEs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: onFilterImportador == null
                  ? null
                  : () => onFilterImportador!(row.importadorId),
              child: Text(
                row.businessName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                  decoration: onFilterImportador == null
                      ? null
                      : TextDecoration.underline,
                  decorationColor: theme.brand.withOpacity(0.35),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REF ${formatRefAmount(row.totalCollectedUsd)}',
                  style: TextStyle(
                    fontSize: 13,
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
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${row.operationCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.paidAt == null ? '—' : formatEsShortDateTime(row.paidAt),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ),
          LucideIcon(
            LucideGlyph.chevronRight,
            size: 14,
            color: theme.textMuted,
          ),
        ],
      ),
    );
  }
}

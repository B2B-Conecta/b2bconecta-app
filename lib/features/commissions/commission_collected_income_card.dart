import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';

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
  });

  final bool isAdmin;
  final ValueChanged<String>? onOpenSettlement;
  final ValueChanged<String>? onFilterImportador;
  final ValueChanged<CommissionSettlementDocumentType>? onFilterDocumentType;

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
    final from = await showDatePicker(
      context: context,
      initialDate: _customFrom ?? _period.from,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Fecha inicial',
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _customTo ?? from,
      firstDate: from,
      lastDate: now,
      helpText: 'Fecha final',
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isAdmin
                  ? 'Ingresos cobrados de la plataforma'
                  : 'Comisión cobrada a su organización',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo cortes pagados · fecha de cobro (America/Caracas)',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _presetChip('Hoy', CommissionCollectedIncomePreset.today),
                _presetChip(
                  'Últimos 7 días',
                  CommissionCollectedIncomePreset.last7Days,
                ),
                _presetChip(
                  'Este mes',
                  CommissionCollectedIncomePreset.thisMonth,
                ),
                _presetChip(
                  'Mes anterior',
                  CommissionCollectedIncomePreset.previousMonth,
                ),
                _presetChip(
                  'Rango',
                  CommissionCollectedIncomePreset.custom,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_invalidRange)
              Text(
                'La fecha inicial no puede ser posterior a la final.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No se pudo cargar el reporte.',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              )
            else
              _body(),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, CommissionCollectedIncomePreset preset) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _preset == preset,
      onSelected: (_) => _selectPreset(preset),
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.brandBlue.withOpacity(0.2),
      checkmarkColor: AppColors.brandBlue,
    );
  }

  Widget _body() {
    final report = _report;
    if (report == null) return const SizedBox.shrink();
    final period = _period;

    if (report.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Período: ${period.labelEs}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay comisión cobrada en este período.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    final variation = report.canShowVariation ? report.variationPct! : null;
    final variationLabel = variation == null
        ? null
        : '${variation >= 0 ? '+' : ''}${variation.toStringAsFixed(1)} % vs período anterior';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: report.settlements.isEmpty
              ? null
              : () {
                  final id = report.settlements.first.settlementId;
                  if (id.isNotEmpty) widget.onOpenSettlement?.call(id);
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'USD ${report.totalCollectedUsd.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Período: ${period.labelEs}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '${report.operationCount} operación(es) · '
                '${report.settlementCount} corte(s) cobrado(s)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (variationLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  variationLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (variation ?? 0) >= 0
                        ? AppColors.successGreen
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (report.series.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _grainTitle(report.grain),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...report.series.map(
            (b) => _line(
              _bucketLabel(report.grain, b.bucket),
              b.totalCollectedUsd,
              b.operationCount,
            ),
          ),
        ],
        if (widget.isAdmin && report.byImportador.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Por importador',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...report.byImportador.map(
            (r) => InkWell(
              onTap: () => widget.onFilterImportador?.call(r.importadorId),
              child: _line(
                r.businessName,
                r.totalCollectedUsd,
                r.operationCount,
              ),
            ),
          ),
        ],
        if (report.byDocumentType.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Por tipo de documento',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...report.byDocumentType.map(
            (r) => InkWell(
              onTap: () => widget.onFilterDocumentType?.call(
                CommissionSettlementDocumentType.effective(r.documentType),
              ),
              child: _line(r.labelEs, r.totalCollectedUsd, r.operationCount),
            ),
          ),
        ],
        if (report.settlements.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Cortes cobrados',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ...report.settlements.map((s) {
            final ref = (s.invoiceReference?.trim().isNotEmpty == true)
                ? s.invoiceReference!.trim()
                : s.settlementId.substring(0, 8);
            final paid = s.paidAt == null
                ? ''
                : ' · ${formatEsShortDateTime(s.paidAt)}';
            return InkWell(
              onTap: () => widget.onOpenSettlement?.call(s.settlementId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$ref · ${s.businessName}$paid',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'USD ${s.totalCollectedUsd.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _line(String label, double usd, int ops) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label · $ops op.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            'USD ${usd.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _grainTitle(String grain) {
    switch (grain) {
      case 'week':
        return 'Desglose semanal';
      case 'month':
        return 'Desglose mensual';
      default:
        return 'Desglose diario';
    }
  }

  String _bucketLabel(String grain, DateTime bucket) {
    final d =
        '${bucket.day.toString().padLeft(2, '0')}/${bucket.month.toString().padLeft(2, '0')}/${bucket.year}';
    if (grain == 'month') {
      return '${bucket.month.toString().padLeft(2, '0')}/${bucket.year}';
    }
    return d;
  }
}

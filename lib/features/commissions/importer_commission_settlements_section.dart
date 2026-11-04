import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'commission_collected_income_card.dart';
import 'commission_settlement_model.dart';
import 'importer_commission_volume_context.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'commission_volume_tier_banner.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'commission_settlement_fiscal.dart';
import 'commission_week_utils.dart';
import 'commission_settlement_lines_section.dart';
import 'importer_commission_pago_section.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';

enum _ImporterSettlementStatusFilter {
  todos,
  borrador,
  pendientePago,
  pagado,
}

/// Importador: cortes de comisión B2B Conecta, filtros por semana y estado de pago.
class ImporterCommissionSettlementsSection extends StatefulWidget {
  const ImporterCommissionSettlementsSection({super.key, this.grouped = false});
  final bool grouped;

  @override
  State<ImporterCommissionSettlementsSection> createState() =>
      _ImporterCommissionSettlementsSectionState();
}

class _ImporterCommissionSettlementsSectionState
    extends State<ImporterCommissionSettlementsSection> {
  List<CommissionSettlementModel> _rows = [];
  ImporterCommissionVolumeContext? _volumeContext;
  bool _loading = true;
  String? _error;
  bool _sectionExpanded = false;
  final _groupController = ExpansionTileController();
  final Set<String> _expandedSettlementIds = {};
  int _incomeCardEpoch = 0;
  String? _weekFilterKey;
  _ImporterSettlementStatusFilter _statusFilter =
      _ImporterSettlementStatusFilter.todos;

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerImporterCommissionSettlementDeepLink(
      _onCommissionNotificationDeepLink,
    );
    _applyPendingCommissionFilter(notify: false);
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterCommissionSettlementDeepLink(null);
    super.dispose();
  }

  void _applyPendingCommissionFilter({bool notify = true}) {
    if (!MainShellTabController.consumeImporterCommissionPreferPendiente()) {
      return;
    }
    void apply() {
      _sectionExpanded = true;
      _statusFilter = _ImporterSettlementStatusFilter.pendientePago;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _onCommissionNotificationDeepLink() {
    _applyPendingCommissionFilter();
    if (widget.grouped) _groupController.expand();
    final id = MainShellTabController.consumePendingCommissionSettlementId();
    if (id == null) return;
    setState(() {
      _sectionExpanded = true;
      _expandedSettlementIds.add(id);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.fetchCommissionSettlements(limit: 48),
        SupabaseService.fetchImporterCommissionVolumeContext(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<CommissionSettlementModel>;
        _volumeContext = results[1] as ImporterCommissionVolumeContext?;
        _loading = false;
        _incomeCardEpoch++;
      });
      final pending =
          MainShellTabController.peekPendingCommissionSettlementId();
      if (pending != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _onCommissionNotificationDeepLink();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> get _weekKeys {
    final keys = <String>{};
    for (final s in _rows) {
      keys.add(CommissionWeekUtils.weekKey(s.periodStart));
    }
    final list = keys.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  String _weekChipLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return key;
    final d = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final end = CommissionWeekUtils.sundayOfWeekStarting(d);
    return CommissionWeekUtils.periodLabelEs(d, end);
  }

  bool _matchesStatusFilter(CommissionSettlementModel s) {
    switch (_statusFilter) {
      case _ImporterSettlementStatusFilter.todos:
        return true;
      case _ImporterSettlementStatusFilter.borrador:
        return s.isBorrador;
      case _ImporterSettlementStatusFilter.pendientePago:
        return s.isEmitido;
      case _ImporterSettlementStatusFilter.pagado:
        return s.isPagado;
    }
  }

  List<CommissionSettlementModel> get _filtered {
    return _rows.where((s) {
      if (_weekFilterKey != null &&
          CommissionWeekUtils.weekKey(s.periodStart) != _weekFilterKey) {
        return false;
      }
      return _matchesStatusFilter(s);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pagado':
        return AppColors.successGreen;
      case 'emitido':
        return Theme.of(context).brightness == Brightness.dark
            ? AppColors.warningAmberOnDark
            : AppColors.warningAmber;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _filterBar() {
    final weeks = _weekKeys;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: weeks.contains(_weekFilterKey) ? _weekFilterKey : '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Período',
              prefixIcon: Icon(Icons.date_range_outlined, size: 20),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem(
                  value: '', child: Text('Todas las semanas')),
              for (final week in weeks)
                DropdownMenuItem(
                    value: week,
                    child: Text(_weekChipLabel(week),
                        style: const TextStyle(fontSize: 12))),
            ],
            onChanged: (value) =>
                setState(() => _weekFilterKey = value == '' ? null : value),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _statusChip('Todos', _ImporterSettlementStatusFilter.todos),
              _statusChip('Borrador', _ImporterSettlementStatusFilter.borrador),
              _statusChip(
                'Pago pendiente',
                _ImporterSettlementStatusFilter.pendientePago,
              ),
              _statusChip('Pagado', _ImporterSettlementStatusFilter.pagado),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, _ImporterSettlementStatusFilter value) {
    final sel = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        showCheckmark: false,
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: sel,
        onSelected: (_) => setState(() => _statusFilter = value),
        visualDensity: VisualDensity.compact,
        selectedColor: value == _ImporterSettlementStatusFilter.pendientePago
            ? AppColors.brandBlueContainer
            : AppColors.brandBlue.withOpacity(0.2),
      ),
    );
  }

  Widget _settlementSummary(CommissionSettlementModel s, bool expanded) {
    final color = _statusColor(s.status);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.periodLabelEs,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withOpacity(.09),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(CommissionSettlementModel.statusLabelEs(s.status),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color))),
            Text('USD ${s.totalCobroUsd.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ]),
      const SizedBox(height: 5),
      Text(
          expanded
              ? (s.isBorrador ? 'Total estimado' : 'Total del corte')
              : (s.isBorrador
                  ? 'Total estimado · ver desglose'
                  : 'Total del corte · ver desglose'),
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
    ]);
  }

  Widget _amountRow(String label, double amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(label,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text('USD ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
      );

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommissionCollectedIncomeCard(
          key: ValueKey('imp-income-$_incomeCardEpoch'),
          isAdmin: false,
          onOpenSettlement: (id) {
            setState(() {
              _sectionExpanded = true;
              _expandedSettlementIds.add(id);
            });
          },
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            key: ValueKey('commission-section-$_sectionExpanded'),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            initiallyExpanded: _sectionExpanded,
            onExpansionChanged: (v) => setState(() => _sectionExpanded = v),
            title: const Text(
              'Cortes de comisión B2B Conecta',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Text(
              _loading
                  ? 'Cargando…'
                  : '${_rows.length} ${_rows.length == 1 ? 'corte' : 'cortes'}',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              if (_volumeContext != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: CommissionVolumeTierBanner(
                    volumeContext: _volumeContext!,
                    compact: true,
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              else ...[
                if (_rows.isNotEmpty) _filterBar(),
                if (_rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Aún no hay cortes de cuenta. B2B Conecta consolidará las comisiones '
                      'devengadas en cortes semanales y emitirá la factura correspondiente.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'Ningún corte coincide con los filtros seleccionados.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...filtered.map((s) {
                    final expanded = _expandedSettlementIds.contains(s.id);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: AppColors.card,
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          key: ValueKey('cs-${s.id}-$expanded'),
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          initiallyExpanded: expanded,
                          onExpansionChanged: (v) {
                            setState(() {
                              if (v) {
                                _expandedSettlementIds.add(s.id);
                              } else {
                                _expandedSettlementIds.remove(s.id);
                              }
                            });
                          },
                          title: _settlementSummary(s, expanded),
                          subtitle: expanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.isBorrador
                                          ? 'Documento por emitir'
                                          : s.documentTypeEffective
                                              .importerDocumentLabelEs,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _statusColor(s.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (s.invoiceReference != null &&
                                        s.invoiceReference!.isNotEmpty)
                                      Text(
                                        'Factura: ${s.invoiceReference}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    if (s.pagoEstadoLabelEs.isNotEmpty)
                                      Text(
                                        s.pagoEstadoLabelEs,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    if (s.paidAt != null)
                                      Text(
                                        'Pagado: ${formatEsShortDateTime(s.paidAt)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                  ],
                                )
                              : null,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Divider(color: AppColors.borderSubtle),
                                  _amountRow('Base de comisión',
                                      s.baseImponibleComisionUsd),
                                  _amountRow(
                                      s.isDeliveryNote
                                          ? 'IVA no aplicado'
                                          : 'IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %',
                                      s.ivaComisionUsd),
                                  const SizedBox(height: 14),
                                  CommissionSettlementLinesSection(
                                    settlementId: s.id,
                                    initiallyCollapsed: true,
                                  ),
                                  const SizedBox(height: 10),
                                  ImporterCommissionPagoSection(
                                    settlement: s,
                                    onChanged: _load,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
              if (!_loading && _error == null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    if (!widget.grouped) return content;
    return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
            controller: _groupController,
            initiallyExpanded: _sectionExpanded,
            maintainState: true,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('Comisiones',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Cobros confirmados y cortes de cuenta',
                style: TextStyle(fontSize: 12)),
            childrenPadding: const EdgeInsets.all(12),
            children: [content]));
  }
}

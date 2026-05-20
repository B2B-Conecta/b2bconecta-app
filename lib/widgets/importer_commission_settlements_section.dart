import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/commission_settlement_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/commission_settlement_fiscal.dart';
import '../utils/commission_week_utils.dart';
import 'commission_settlement_lines_section.dart';
import 'importer_commission_pago_section.dart';
import 'main_shell_tab.dart';

enum _ImporterSettlementStatusFilter {
  todos,
  borrador,
  pendientePago,
  pagado,
}

/// Importador: cortes de comisión MotoLink, filtros por semana y estado de pago.
class ImporterCommissionSettlementsSection extends StatefulWidget {
  const ImporterCommissionSettlementsSection({super.key});

  @override
  State<ImporterCommissionSettlementsSection> createState() =>
      _ImporterCommissionSettlementsSectionState();
}

class _ImporterCommissionSettlementsSectionState
    extends State<ImporterCommissionSettlementsSection> {
  List<CommissionSettlementModel> _rows = [];
  bool _loading = true;
  String? _error;
  bool _sectionExpanded = false;
  final Set<String> _expandedSettlementIds = {};
  String? _weekFilterKey;
  _ImporterSettlementStatusFilter _statusFilter =
      _ImporterSettlementStatusFilter.todos;

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerImporterCommissionSettlementDeepLink(
      _onCommissionNotificationDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterCommissionSettlementDeepLink(null);
    super.dispose();
  }

  void _onCommissionNotificationDeepLink() {
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
      final rows = await SupabaseService.fetchCommissionSettlements(limit: 48);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
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
        return Colors.green.shade700;
      case 'emitido':
        return Colors.orange.shade800;
      default:
        return AppColors.brandBlue;
    }
  }

  Widget _filterBar() {
    final weeks = _weekKeys;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas las semanas'),
                  selected: _weekFilterKey == null,
                  onSelected: (_) => setState(() => _weekFilterKey = null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ...weeks.map(
                  (k) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        _weekChipLabel(k),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _weekFilterKey == k,
                      onSelected: (_) => setState(() => _weekFilterKey = k),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('Todos', _ImporterSettlementStatusFilter.todos),
                _statusChip('Borrador', _ImporterSettlementStatusFilter.borrador),
                _statusChip(
                  'Pago pendiente',
                  _ImporterSettlementStatusFilter.pendientePago,
                ),
                _statusChip('Pagado', _ImporterSettlementStatusFilter.pagado),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, _ImporterSettlementStatusFilter value) {
    final sel = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: sel,
        onSelected: (_) => setState(() => _statusFilter = value),
        visualDensity: VisualDensity.compact,
        selectedColor: value == _ImporterSettlementStatusFilter.pendientePago
            ? Colors.orange.shade100
            : AppColors.brandBlue.withOpacity(0.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: _sectionExpanded,
        onExpansionChanged: (v) => setState(() => _sectionExpanded = v),
        title: const Text(
          'Cortes de comisión MotoLink',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          _loading
              ? 'Cargando…'
              : '${_rows.length} corte(s) · ${_filtered.length} visible(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else ...[
            if (_rows.isNotEmpty) _filterBar(),
            if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Aún no hay cortes de cuenta. MotoLink consolidará las comisiones '
                  'devengadas en cortes semanales y emitirá la factura correspondiente.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
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
                    color: Colors.grey.shade700,
                  ),
                ),
              )
            else
              ...filtered.map((s) {
                final expanded = _expandedSettlementIds.contains(s.id);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: Colors.grey.shade50,
                    child: ExpansionTile(
                      key: ValueKey('cs-${s.id}'),
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
                      title: Text(
                        s.periodLabelEs,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${CommissionSettlementModel.statusLabelEs(s.status)} · '
                            'Total a pagar: USD ${s.totalFacturaUsd.toStringAsFixed(2)} (IVA incl.)',
                            style: TextStyle(
                              fontSize: 12,
                              color: _statusColor(s.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Base comisión: USD ${s.baseImponibleComisionUsd.toStringAsFixed(2)} + '
                            'IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %: '
                            'USD ${s.ivaComisionUsd.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
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
                                color: Colors.grey.shade700,
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
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CommissionSettlementLinesSection(
                                settlementId: s.id,
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
    );
  }
}

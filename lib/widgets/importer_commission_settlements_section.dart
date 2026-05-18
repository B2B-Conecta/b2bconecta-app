import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/commission_settlement_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'commission_settlement_lines_section.dart';
import 'importer_commission_pago_section.dart';
import 'main_shell_tab.dart';

/// Importador: cortes de comisión MotoLink y registro de pago.
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
      final rows = await SupabaseService.fetchCommissionSettlements(limit: 24);
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

  @override
  Widget build(BuildContext context) {
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
              : '${_rows.length} corte(s) · pague la factura emitida con comprobante',
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
          else if (_rows.isEmpty)
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
          else
            ..._rows.map((s) {
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
                          'USD ${s.totalCommissionUsd.toStringAsFixed(2)}',
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

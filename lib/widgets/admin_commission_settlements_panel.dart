import 'package:flutter/material.dart';
import '../models/commission_settlement_model.dart';
import '../models/catalog_filters.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Admin — Minuta #7 C1: cortes semanales, facturación y cobro de comisiones MotoLink.
class AdminCommissionSettlementsPanel extends StatefulWidget {
  const AdminCommissionSettlementsPanel({super.key});

  @override
  State<AdminCommissionSettlementsPanel> createState() =>
      _AdminCommissionSettlementsPanelState();
}

class _AdminCommissionSettlementsPanelState
    extends State<AdminCommissionSettlementsPanel> {
  List<CommissionSettlementModel> _rows = [];
  bool _loading = true;
  String? _error;
  double _defaultRate = 0.05;
  bool _busy = false;
  final Map<String, List<CommissionSettlementLineModel>> _linesCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rate = await SupabaseService.fetchDefaultCommissionRate();
      final rows = await SupabaseService.fetchCommissionSettlements();
      if (!mounted) return;
      setState(() {
        _defaultRate = rate;
        _rows = rows;
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

  DateTime _mondayOfWeek(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  Future<void> _generatePreviousWeek() async {
    final prevWeek = _mondayOfWeek(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    await _generateForWeek(prevWeek);
  }

  Future<void> _generateForWeek(DateTime weekStart) async {
    setState(() => _busy = true);
    try {
      final result = await SupabaseService.adminGenerateCommissionSettlementsWeek(
        weekStart: weekStart,
      );
      if (!mounted) return;
      final n = (result['created_count'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0
                ? 'Se generaron $n corte(s) en borrador.'
                : 'No hay líneas devengadas pendientes de corte para esa semana.',
          ),
        ),
      );
      _linesCache.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editImportadorRate() async {
    List<ImporterOption> importers = [];
    try {
      importers = await SupabaseService.fetchImporterOptions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      return;
    }
    if (importers.isEmpty) return;
    String? selectedId = importers.first.id;
    final ctrl = TextEditingController(text: '5.00');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('Tasa por importador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(labelText: 'Importador'),
                items: importers
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.id,
                        child: Text(
                          o.businessName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDlg(() => selectedId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Porcentaje (%) — vacío = global',
                  hintText: '5.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || selectedId == null) return;
    final trimmed = ctrl.text.trim();
    double? rate;
    if (trimmed.isNotEmpty) {
      final pct = double.tryParse(trimmed.replaceAll(',', '.'));
      if (pct == null || pct < 0 || pct > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Porcentaje inválido.')),
        );
        return;
      }
      rate = pct / 100;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetImportadorCommissionRate(
        importadorId: selectedId!,
        rate: rate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasa del importador actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDefaultRate() async {
    final ctrl = TextEditingController(
      text: (_defaultRate * 100).toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tasa global de comisión'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Porcentaje (%)',
            hintText: '5.00',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pct = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (pct == null || pct < 0 || pct > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique un porcentaje válido (0–100).')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetDefaultCommissionRate(pct / 100);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasa global actualizada.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issueSettlement(CommissionSettlementModel s) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emitir factura MotoLink'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nº / referencia de factura',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Emitir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (ctrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminIssueCommissionSettlement(
        settlementId: s.id,
        invoiceReference: ctrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corte marcado como emitido.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPaid(CommissionSettlementModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como pagado'),
        content: Text(
          '¿Confirma el cobro de USD ${s.totalCommissionUsd.toStringAsFixed(2)} '
          'del importador ${s.importadorBusinessName ?? s.importadorId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pagado'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminMarkCommissionSettlementPaid(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corte marcado como pagado.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSettlement(CommissionSettlementModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular corte'),
        content: const Text(
          'Las líneas de pedido quedarán disponibles para un nuevo corte. '
          'Solo aplica a cortes en borrador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminCancelCommissionSettlement(s.id);
      if (!mounted) return;
      _linesCache.remove(s.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<CommissionSettlementLineModel>> _linesFor(String id) async {
    if (_linesCache.containsKey(id)) return _linesCache[id]!;
    final lines = await SupabaseService.fetchCommissionSettlementLines(id);
    _linesCache[id] = lines;
    return lines;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pagado':
        return Colors.green.shade700;
      case 'emitido':
        return Colors.orange.shade800;
      case 'anulado':
        return Colors.grey;
      default:
        return AppColors.brandBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            children: [
              _ConfigCard(
                defaultRatePct: _defaultRate * 100,
                onEditRate: _busy ? null : _editDefaultRate,
                onEditImportadorRate: _busy ? null : _editImportadorRate,
                onGenerateWeek: _busy ? null : _generatePreviousWeek,
              ),
              const SizedBox(height: 12),
              Text(
                'Cortes registrados (${_rows.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No hay cortes. Genere el de la semana anterior cuando existan '
                    'pedidos entregados con comisión devengada.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._rows.map(_settlementTile),
            ],
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _settlementTile(CommissionSettlementModel s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          s.importadorBusinessName ?? 'Importador',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.periodLabelEs, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(s.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    CommissionSettlementModel.statusLabelEs(s.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(s.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'USD ${s.totalCommissionUsd.toStringAsFixed(2)} · ${s.lineCount} línea(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (s.invoiceReference != null && s.invoiceReference!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Factura: ${s.invoiceReference}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
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
                if (s.importadorRif != null && s.importadorRif!.isNotEmpty)
                  Text('RIF: ${s.importadorRif}', style: const TextStyle(fontSize: 12)),
                if (s.issuedAt != null)
                  Text(
                    'Emitido: ${formatEsShortDateTime(s.issuedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (s.paidAt != null)
                  Text(
                    'Pagado: ${formatEsShortDateTime(s.paidAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 8),
                FutureBuilder<List<CommissionSettlementLineModel>>(
                  future: _linesFor(s.id),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final lines = snap.data ?? const [];
                    if (lines.isEmpty) {
                      return const Text('Sin líneas.', style: TextStyle(fontSize: 12));
                    }
                    return Column(
                      children: lines
                          .map(
                            (l) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l.productName ?? l.requestId.substring(0, 8),
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                'Venta USD ${l.precioTotalUsd.toStringAsFixed(2)} · '
                                'Comisión USD ${l.comisionDevengadaUsd.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (s.isBorrador) ...[
                      OutlinedButton(
                        onPressed: _busy ? null : () => _issueSettlement(s),
                        child: const Text('Emitir factura'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _cancelSettlement(s),
                        child: const Text('Anular'),
                      ),
                    ],
                    if (s.isEmitido)
                      FilledButton(
                        onPressed: _busy ? null : () => _markPaid(s),
                        child: const Text('Marcar pagado'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.defaultRatePct,
    this.onEditRate,
    this.onEditImportadorRate,
    this.onGenerateWeek,
  });

  final double defaultRatePct;
  final VoidCallback? onEditRate;
  final VoidCallback? onEditImportadorRate;
  final VoidCallback? onGenerateWeek;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandBlueContainer.withOpacity(0.35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comisiones MotoLink (C1)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'La comisión se devenga cuando el aliado marca Recibido. '
              'Tasa global actual: ${defaultRatePct.toStringAsFixed(2)} % '
              '(cada importador puede tener tasa propia).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditRate,
                  icon: const Icon(Icons.percent, size: 18),
                  label: const Text('Tasa global'),
                ),
                OutlinedButton.icon(
                  onPressed: onEditImportadorRate,
                  icon: const Icon(Icons.store, size: 18),
                  label: const Text('Tasa importador'),
                ),
                FilledButton.icon(
                  onPressed: onGenerateWeek,
                  icon: const Icon(Icons.calendar_view_week, size: 18),
                  label: const Text('Corte semana anterior'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

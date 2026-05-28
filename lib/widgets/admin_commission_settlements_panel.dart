import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/commission_settlement_document_type.dart';
import '../models/commission_settlement_model.dart';
import '../models/catalog_filters.dart';
import '../services/supabase_service.dart';
import '../utils/commission_settlement_filter_utils.dart';
import '../utils/commission_volume_tiers.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/commission_settlement_fiscal.dart';
import 'admin_tasa_bcv_card.dart';
import 'commission_settlement_lines_section.dart';
import 'commission_settlement_list_filter_bar.dart';
import 'commission_settlement_filters_sheet.dart';
import 'main_shell_tab.dart';

/// Admin: cortes semanales, facturación y cobro de comisiones MotoLink.
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
  List<CommissionVolumeTier> _volumeTiers = [];
  bool _busy = false;
  final Set<String> _expandedSettlementIds = {};
  final TextEditingController _searchController = TextEditingController();
  CommissionSettlementFilters _filters = const CommissionSettlementFilters();

  List<CommissionSettlementModel> get _filteredRows =>
      filterCommissionSettlements(_rows, _filters);

  int get _activeFilterCount {
    final f = _filters;
    var count = 0;
    if (f.searchQuery.trim().isNotEmpty) count++;
    if (f.status != null) count++;
    if (f.weekScope != null) count++;
    if (f.documentType != null) count++;
    if (f.importadorId != null) count++;
    return count;
  }

  Future<void> _openCommissionSettlementFiltersSheet() async {
    final result = await CommissionSettlementFiltersSheet.show(
      context,
      initial: _filters,
      importadorOptions: _importadorFilterOptions,
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result;
      _searchController.text = result.searchQuery;
    });
  }

  List<CommissionSettlementImporterOption> get _importadorFilterOptions {
    final map = <String, String>{};
    for (final row in _rows) {
      if (row.importadorId.trim().isEmpty) continue;
      final name = row.importadorBusinessName?.trim();
      map[row.importadorId] = (name == null || name.isEmpty)
          ? 'Importador'
          : name;
    }
    final options = map.entries
        .map(
          (e) => CommissionSettlementImporterOption(
            id: e.key,
            businessName: e.value,
          ),
        )
        .toList();
    options.sort(
      (a, b) => a.businessName.toLowerCase().compareTo(
        b.businessName.toLowerCase(),
      ),
    );
    return options;
  }

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerAdminCommissionSettlementDeepLink(
      _onCommissionNotificationDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminCommissionSettlementDeepLink(null);
    _searchController.dispose();
    super.dispose();
  }

  void _onCommissionNotificationDeepLink() {
    final id = MainShellTabController.consumePendingCommissionSettlementId();
    if (id == null) return;
    setState(() => _expandedSettlementIds.add(id));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rate = await SupabaseService.fetchDefaultCommissionRate();
      final tiers = await SupabaseService.fetchCommissionVolumeTiers();
      final rows = await SupabaseService.fetchCommissionSettlements();
      if (!mounted) return;
      setState(() {
        _defaultRate = rate;
        _volumeTiers = tiers;
        _rows = rows;
        _loading = false;
      });
      if (MainShellTabController.peekPendingCommissionSettlementId() != null) {
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

  DateTime _mondayOfWeek(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  Future<void> _generatePreviousWeek() async {
    final prevWeek = _mondayOfWeek(
      DateTime.now().subtract(const Duration(days: 7)),
    );
    await _generateForWeek(prevWeek, label: 'semana anterior');
  }

  /// Semana en curso (lunes–domingo según fecha del servidor).
  Future<void> _generateCurrentWeek() async {
    setState(() => _busy = true);
    try {
      final result =
          await SupabaseService.adminGenerateCommissionSettlementsCurrentWeek();
      if (!mounted) return;
      _showGenerateResult(result, label: 'semana actual');
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

  void _showGenerateResult(
    Map<String, dynamic> result, {
    required String label,
  }) {
    final created = (result['created_count'] as num?)?.toInt() ?? 0;
    final merged = (result['merged_count'] as num?)?.toInt() ?? 0;
    final pending = (result['pending_lines_before'] as num?)?.toInt() ?? 0;
    final ws = result['week_start']?.toString();
    final we = result['week_end']?.toString();
    final period = (ws != null && we != null) ? ' ($ws → $we)' : '';
    String msg;
    if (created > 0 || merged > 0) {
      final parts = <String>[];
      if (created > 0) parts.add('$created corte(s) nuevo(s)');
      if (merged > 0) parts.add('$merged actualizado(s) en borrador');
      msg = '${parts.join(' · ')} ($label$period).';
    } else if (pending > 0) {
      msg =
          'Hay $pending línea(s) devengada(s) en el periodo pero no se pudo '
          'asignar (revise importador y estado del corte).';
    } else {
      msg =
          'Sin líneas devengadas sin corte para $label$period. '
          'Confirme que los pedidos estén Recibido y con comisión registrada.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _generateForWeek(
    DateTime weekStart, {
    required String label,
  }) async {
    setState(() => _busy = true);
    try {
      final result = await SupabaseService.adminGenerateCommissionSettlementsWeek(
        weekStart: weekStart,
      );
      if (!mounted) return;
      _showGenerateResult(result, label: label);
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
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Importador'),
                  items: importers
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(
                            o.businessName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
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
                  labelText: 'Porcentaje (%) — vacío = tramos por volumen',
                  hintText: '5.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              ],
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

  Future<void> _editVolumeTiers() async {
    final rows = _volumeTiers
        .map(
          (t) => (
            min: TextEditingController(
              text: t.minMonthlySalesUsd.toStringAsFixed(0),
            ),
            rate: TextEditingController(
              text: t.ratePercentDisplay.toStringAsFixed(2),
            ),
          ),
        )
        .toList();
    if (rows.isEmpty) {
      rows.add((
        min: TextEditingController(text: '0'),
        rate: TextEditingController(text: '5.00'),
      ));
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Tramos por volumen mensual'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Volumen = suma USD de pedidos entregados en el mes (Caracas). '
                    'Umbrales inclusivos. La tasa fija por importador tiene prioridad.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < rows.length; i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rows[i].min,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Mín. USD/mes',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: rows[i].rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tasa %',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: rows.length > 1
                              ? () => setDlg(() => rows.removeAt(i))
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  TextButton.icon(
                    onPressed: () => setDlg(
                      () => rows.add((
                        min: TextEditingController(text: '10000'),
                        rate: TextEditingController(text: '3.00'),
                      )),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir tramo'),
                  ),
                ],
              ),
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
      ),
    );

    if (ok != true || !mounted) {
      for (final r in rows) {
        r.min.dispose();
        r.rate.dispose();
      }
      return;
    }

    final parsed = <CommissionVolumeTier>[];
    for (final r in rows) {
      final min = double.tryParse(r.min.text.replaceAll(',', '.'));
      final pct = double.tryParse(r.rate.text.replaceAll(',', '.'));
      if (min == null || pct == null || min < 0 || pct < 0 || pct > 100) {
        for (final r in rows) {
          r.min.dispose();
          r.rate.dispose();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revise los tramos (USD y % válidos).')),
        );
        return;
      }
      parsed.add(
        CommissionVolumeTier(
          minMonthlySalesUsd: min,
          ratePct: pct / 100,
        ),
      );
    }
    for (final r in rows) {
      r.min.dispose();
      r.rate.dispose();
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetCommissionVolumeTiers(parsed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tramos de comisión actualizados.')),
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

  Future<void> _issueSettlement(
    CommissionSettlementModel s, {
    required CommissionSettlementDocumentType documentType,
  }) async {
    String previewRef = '';
    try {
      previewRef = await SupabaseService.peekCommissionSettlementReference(
        documentType,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la referencia: $e')),
      );
      return;
    }
    if (!mounted) return;

    final isNota =
        documentType == CommissionSettlementDocumentType.deliveryNote;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isNota ? 'Confirmar emisión' : 'Emitir factura fiscal',
        ),
        content: Text(
          isNota
              ? 'Se asignará la referencia:\n\n$previewRef\n\n'
                  'Serie ML-NOT- (sin IVA). La emisión no se puede deshacer.'
              : 'Factura fiscal con IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %.\n\n'
                  'Referencia: $previewRef\n'
                  'Formato: ML-COM-{año}-{secuencia}. '
                  'Esta acción es irreversible.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isNota ? 'Confirmar' : 'Emitir factura'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final assignedRef = await SupabaseService.adminIssueCommissionSettlement(
        settlementId: s.id,
        documentType: documentType,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      CommissionSettlementModel? emitted;
      for (final row in _rows) {
        if (row.id == s.id) {
          emitted = row;
          break;
        }
      }
      if (emitted != null && emitted.isEmitido) {
        try {
          await SupabaseService.generateAndUploadCommissionSettlementInvoicePdf(
            settlement: emitted,
          );
          if (!mounted) return;
          await _load();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Corte emitido ($assignedRef) pero falló el PDF: $e',
              ),
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignedRef.isNotEmpty
                ? 'Corte emitido ($assignedRef). PDF listo.'
                : 'Corte marcado como emitido.',
          ),
        ),
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

  Future<void> _abrirFacturaPdf(CommissionSettlementModel s) async {
    final path = s.invoicePdfStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url =
          await SupabaseService.createSignedUrlForCommissionInvoicePdf(path);
      final uri = Uri.parse(url);
      if (!mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _generarFacturaPdf(CommissionSettlementModel s) async {
    setState(() => _busy = true);
    try {
      await SupabaseService.generateAndUploadCommissionSettlementInvoicePdf(
        settlement: s,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factura PDF generada.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abrirComprobante(CommissionSettlementModel s) async {
    final path = s.pagoComprobanteStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForComprobantePago(path);
      final uri = Uri.parse(url);
      if (!mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _approvePago(CommissionSettlementModel s) async {
    setState(() => _busy = true);
    try {
      await SupabaseService.adminApproveCommissionSettlementPago(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago confirmado. Se notificó al importador.')),
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

  Future<void> _rejectPago(CommissionSettlementModel s) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar comprobante'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Indique qué debe corregir el importador',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminRejectCommissionSettlementPago(
        settlementId: s.id,
        nota: ctrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante rechazado. Se notificó al importador.')),
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
        title: const Text('Marcar como pagado (sin comprobante)'),
        content: Text(
          '¿Confirma el cobro de USD ${s.totalFacturaUsd.toStringAsFixed(2)} '
          '(comisión + IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %) '
          'de ${s.importadorBusinessName ?? s.importadorId} sin comprobante en la plataforma?',
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

  Future<void> _exportSettlementCsv(CommissionSettlementModel s) async {
    setState(() => _busy = true);
    try {
      final lines = await SupabaseService.fetchCommissionSettlementLines(s.id);
      final buf = StringBuffer()
        ..writeln(
          'periodo,importador,factura,estado,base_comision_usd,iva_usd,total_factura_usd,'
          'lineas,pedido,producto,venta_usd,comision_usd',
        );
      for (final l in lines) {
        buf.writeln(
          '"${s.periodLabelEs}","${s.importadorBusinessName ?? ''}",'
          '"${s.invoiceReference ?? ''}","${s.status}",'
          '${s.baseImponibleComisionUsd},${s.ivaComisionUsd},${s.totalFacturaUsd},'
          '${s.lineCount},'
          '"${l.requestId}","${(l.productName ?? '').replaceAll('"', "'")}",'
          '${l.precioTotalUsd},${l.comisionDevengadaUsd}',
        );
      }
      await Clipboard.setData(ClipboardData(text: buf.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detalle del corte copiado al portapapeles (CSV).'),
        ),
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
              const AdminTasaBcvCard(),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                _CommissionSummaryCard(rows: _rows),
              ],
              const SizedBox(height: 12),
              _ConfigCard(
                defaultRatePct: _defaultRate * 100,
                volumeTiersSummary:
                    commissionVolumeTiersSummaryEs(_volumeTiers),
                onEditRate: _busy ? null : _editDefaultRate,
                onEditImportadorRate: _busy ? null : _editImportadorRate,
                onEditVolumeTiers: _busy ? null : _editVolumeTiers,
                onGeneratePreviousWeek: _busy ? null : _generatePreviousWeek,
                onGenerateCurrentWeek: _busy ? null : _generateCurrentWeek,
              ),
              const SizedBox(height: 12),
              Text(
                _filters.hasActiveFilters
                    ? 'Cortes registrados (${_filteredRows.length} de ${_rows.length})'
                    : 'Cortes registrados (${_rows.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _rows.isEmpty ? null : _openCommissionSettlementFiltersSheet,
                  icon: Badge(
                    isLabelVisible: _activeFilterCount > 0,
                    label: Text('$_activeFilterCount'),
                    backgroundColor: AppColors.brandOrange,
                    child: const Icon(Icons.tune),
                  ),
                  label: const Text('Filtros'),
                ),
              ],
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
              else if (_filteredRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'Ningún corte coincide con los filtros.',
                        style: TextStyle(color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filters = const CommissionSettlementFilters());
                        },
                        child: const Text('Limpiar filtros'),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredRows.map(_settlementTile),
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
    final expanded = _expandedSettlementIds.contains(s.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
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
                if (!s.isBorrador) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: s.isDeliveryNote
                          ? Colors.grey.shade100
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: s.isDeliveryNote
                            ? Colors.grey.shade300
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Text(
                      s.documentTypeEffective.labelEs,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: s.isDeliveryNote
                            ? Colors.grey.shade800
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${s.totalCobroLabelEs}: USD ${s.totalCobroUsd.toStringAsFixed(2)} · '
                    '${s.lineCount} pedido(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                s.isDeliveryNote
                    ? 'Base comisión (neta, sin IVA): USD ${s.baseImponibleComisionUsd.toStringAsFixed(2)}'
                    : 'Base: USD ${s.baseImponibleComisionUsd.toStringAsFixed(2)} + '
                        'IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %: '
                        'USD ${s.ivaComisionUsd.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
            if (s.invoiceReference != null && s.invoiceReference!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ref.: ${s.invoiceReference}',
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
                if (s.isEmitido && s.pagoEstadoLabelEs.isNotEmpty)
                  Text(
                    'Pago: ${s.pagoEstadoLabelEs}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s.pagoEnRevision
                          ? Colors.orange.shade900
                          : Colors.grey.shade800,
                    ),
                  ),
                if (s.pagoRechazado && s.pagoRechazoNota != null &&
                    s.pagoRechazoNota!.trim().isNotEmpty)
                  Text(
                    'Rechazo: ${s.pagoRechazoNota}',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  ),
                const SizedBox(height: 8),
                CommissionSettlementLinesSection(settlementId: s.id),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (s.isBorrador) ...[
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _issueSettlement(
                                  s,
                                  documentType: CommissionSettlementDocumentType
                                      .fiscalInvoice,
                                ),
                        child: const Text('Emitir factura'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _issueSettlement(
                                  s,
                                  documentType: CommissionSettlementDocumentType
                                      .deliveryNote,
                                ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: Text(
                          CommissionSettlementDocumentType
                              .deliveryNote.adminEmitActionLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _cancelSettlement(s),
                        child: const Text('Anular'),
                      ),
                    ],
                    if ((s.isEmitido || s.isPagado) && s.tieneFacturaPdf)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _abrirFacturaPdf(s),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Ver PDF'),
                      ),
                    if ((s.isEmitido || s.isPagado) && !s.tieneFacturaPdf)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _generarFacturaPdf(s),
                        child: const Text('Generar PDF'),
                      ),
                    if ((s.isEmitido || s.isPagado) && s.tieneFacturaPdf)
                      TextButton(
                        onPressed: _busy ? null : () => _generarFacturaPdf(s),
                        child: const Text('Regenerar PDF'),
                      ),
                    if (!s.isBorrador && !s.isAnulado)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _exportSettlementCsv(s),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copiar CSV'),
                      ),
                    if (s.isEmitido && s.pagoEnRevision) ...[
                      if (s.tieneComprobantePago)
                        OutlinedButton(
                          onPressed: _busy ? null : () => _abrirComprobante(s),
                          child: const Text('Ver comprobante'),
                        ),
                      FilledButton(
                        onPressed: _busy ? null : () => _approvePago(s),
                        child: const Text('Confirmar pago'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _rejectPago(s),
                        child: const Text('Rechazar'),
                      ),
                    ],
                    if (s.isEmitido && !s.pagoEnRevision)
                      TextButton(
                        onPressed: _busy ? null : () => _markPaid(s),
                        child: const Text('Pagado sin comprobante'),
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

class _CommissionSummaryCard extends StatelessWidget {
  const _CommissionSummaryCard({required this.rows});

  final List<CommissionSettlementModel> rows;

  @override
  Widget build(BuildContext context) {
    var borrador = 0;
    var emitido = 0;
    var enRevision = 0;
    var pagado = 0;
    double usdEmitido = 0;
    double usdPagado = 0;

    for (final s in rows) {
      if (s.isBorrador) borrador++;
      if (s.isEmitido) {
        emitido++;
        usdEmitido += s.totalCobroUsd;
        if (s.pagoEnRevision) enRevision++;
      }
      if (s.isPagado) {
        pagado++;
        usdPagado += s.totalCobroUsd;
      }
    }

    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de cortes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _chip('Borrador', borrador, AppColors.brandBlue),
                _chip('Emitido', emitido, Colors.orange.shade800),
                _chip('Pago en revisión', enRevision, Colors.deepOrange),
                _chip('Pagado', pagado, Colors.green.shade700),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'USD pendiente de cobro (emitido): ${usdEmitido.toStringAsFixed(2)} · '
              'USD cobrado (pagado): ${usdPagado.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.defaultRatePct,
    required this.volumeTiersSummary,
    this.onEditRate,
    this.onEditImportadorRate,
    this.onEditVolumeTiers,
    this.onGeneratePreviousWeek,
    this.onGenerateCurrentWeek,
  });

  final double defaultRatePct;
  final String volumeTiersSummary;
  final VoidCallback? onEditRate;
  final VoidCallback? onEditImportadorRate;
  final VoidCallback? onEditVolumeTiers;
  final VoidCallback? onGeneratePreviousWeek;
  final VoidCallback? onGenerateCurrentWeek;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reglas y cortes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'La comisión se devenga cuando el aliado marca Recibido. '
              'La tasa se fija en el checkout según el volumen del mes o un override por importador.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tasas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            _configRow(
              icon: Icons.percent,
              title: 'Tasa global (reserva)',
              subtitle: '${defaultRatePct.toStringAsFixed(2)} % si no aplica un tramo',
              actionLabel: 'Editar',
              onAction: onEditRate,
            ),
            const SizedBox(height: 6),
            _configRow(
              icon: Icons.stacked_line_chart,
              title: 'Tramos por volumen mensual',
              subtitle: volumeTiersSummary,
              actionLabel: 'Tramos',
              onAction: onEditVolumeTiers,
            ),
            const SizedBox(height: 6),
            _configRow(
              icon: Icons.store_outlined,
              title: 'Tasa fija por importador',
              subtitle: 'Opcional; anula tramos y volumen',
              actionLabel: 'Configurar',
              onAction: onEditImportadorRate,
            ),
            const SizedBox(height: 14),
            Text(
              'Emisión habitual: ML-COM- con IVA. '
              'Alternativa ML-NOT- (sin IVA): botón secundario al emitir.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Generar cortes en borrador',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onGeneratePreviousWeek,
                    icon: const Icon(Icons.calendar_view_week, size: 18),
                    label: const Text('Semana anterior'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGenerateCurrentWeek,
                    icon: const Icon(Icons.today_outlined, size: 18),
                    label: const Text('Semana actual'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange.shade800,
                      side: BorderSide(color: Colors.deepOrange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '«Semana actual» solo para pruebas en desarrollo.',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _configRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.brandBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

}

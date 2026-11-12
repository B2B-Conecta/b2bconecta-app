import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/core/utils/stored_file_page.dart';

import 'commission_collected_income_card.dart';
import 'commission_settlement_document_type.dart';
import 'commission_settlement_model.dart';
import 'commissions_data_table.dart';
import 'commissions_kpi_cards.dart';
import 'importer_commission_volume_context.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'commission_settlement_filter_utils.dart';
import 'commission_volume_tiers.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'commission_settlement_fiscal.dart';
import 'admin_tasa_bcv_card.dart';
import 'commission_volume_tier_banner.dart';
import 'commission_settlement_lines_section.dart';
import 'commission_settlement_filters_sheet.dart';
import 'commission_settlement_list_filter_bar.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/admin/admin_action_rules.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';

/// Alias de módulo para rutas admin (`/admin/commissions`).
typedef CommissionsModule = AdminCommissionSettlementsPanel;

/// Admin: cortes semanales, facturación y cobro de comisiones B2B Conecta.
class AdminCommissionSettlementsPanel extends StatefulWidget {
  const AdminCommissionSettlementsPanel({super.key, required this.viewerRole});

  /// Rol de la sesión: decide si se muestran los ajustes de tasas.
  final String? viewerRole;

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
  Map<String, ImporterCommissionVolumeContext> _volumeByImportador = {};
  bool _busy = false;
  final Set<String> _expandedSettlementIds = {};
  final TextEditingController _searchController = TextEditingController();
  CommissionSettlementFilters _filters = const CommissionSettlementFilters();
  int _incomeCardEpoch = 0;
  double? _tasaBcv;
  int _tableResetKey = 0;

  List<CommissionSettlementModel> get _filteredRows =>
      filterCommissionSettlements(_rows, _filters);

  int get _activeFilterCount {
    final f = _filters;
    var count = 0;
    if (f.weekScope != null) count++;
    if (f.documentType != null) count++;
    if (f.importadorId != null) count++;
    return count;
  }

  void _onQuickSearch(String q) {
    setState(() {
      _filters = _filters.copyWithSearch(q);
      _tableResetKey++;
    });
  }

  void _onStatusPill(String? status) {
    setState(() {
      _filters = _filters.copyWithStatus(status);
      _tableResetKey++;
    });
  }

  void _toggleSettlementExpand(String id) {
    setState(() {
      if (_expandedSettlementIds.contains(id)) {
        _expandedSettlementIds.remove(id);
      } else {
        _expandedSettlementIds.add(id);
      }
    });
  }

  void _onSettlementRowAction(CommissionSettlementModel s, String actionId) {
    switch (actionId) {
      case 'toggle':
        _toggleSettlementExpand(s.id);
      case 'pdf':
        _abrirFacturaPdf(s);
      case 'gen_pdf':
      case 'regen_pdf':
        _generarFacturaPdf(s);
      case 'csv':
        _exportSettlementCsv(s);
      case 'anular':
        _cancelSettlement(s);
    }
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

  void _openSettlementFromReport(String settlementId) {
    CommissionSettlementModel? row;
    for (final s in _rows) {
      if (s.id == settlementId) {
        row = s;
        break;
      }
    }
    setState(() {
      _expandedSettlementIds.add(settlementId);
      final ref = row?.invoiceReference?.trim();
      if (ref != null && ref.isNotEmpty) {
        _filters = _filters.copyWithSearch(ref);
        _searchController.text = ref;
      }
      _tableResetKey++;
    });
  }

  void _filterImportadorFromReport(String importadorId) {
    setState(() => _filters = _filters.copyWithImportadorId(importadorId));
  }

  void _filterDocumentTypeFromReport(CommissionSettlementDocumentType type) {
    setState(() => _filters = _filters.copyWithDocumentType(type));
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
      final volumeByImportador =
          await SupabaseService.fetchImporterCommissionVolumeContexts(
        rows.map((r) => r.importadorId),
      );
      final tasaRec = await SupabaseService.fetchGlobalTasaBcvRecord();
      if (!mounted) return;
      setState(() {
        _defaultRate = rate;
        _volumeTiers = tiers;
        _rows = rows;
        _volumeByImportador = volumeByImportador;
        _tasaBcv = tasaRec?.tasa;
        _loading = false;
        _incomeCardEpoch++;
        _tableResetKey++;
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

  bool get _canEditRates =>
      AdminActionRules.canEditCommissionRates(viewerRole: widget.viewerRole);

  Future<void> _editImportadorRate() async {
    if (!_canEditRates) return;
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
    if (importers.isEmpty || !mounted) return;
    final result = await UnifiedActionDialog.show<({String id, double? rate})>(
      context: context,
      builder: (ctx) => _ImportadorRateDialog(importers: importers),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetImportadorCommissionRate(
        importadorId: result.id,
        rate: result.rate,
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
    if (!_canEditRates) return;
    final pct = await UnifiedActionDialog.show<double>(
      context: context,
      builder: (ctx) => _DefaultRateDialog(
        initialPct: _defaultRate * 100,
      ),
    );
    if (pct == null || !mounted) return;
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
    if (!_canEditRates) return;
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
                    'Volumen = suma USD de pedidos entregados en el mes (todos los estados). '
                    'Umbrales inclusivos. La tasa fija por importador tiene prioridad.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textPrimary,
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
                  'Serie B2B-NOT- (sin IVA). La emisión no se puede deshacer. '
                  'Las facturas históricas ML-NOT- no se renumeran.'
              : 'Factura fiscal con IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %.\n\n'
                  'Referencia: $previewRef\n'
                  'Formato: B2B-COM-{año}-{secuencia}. '
                  'Esta acción es irreversible. Las facturas históricas ML-COM- se conservan.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
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
    await openStoredFile(
      context,
      signedUrl: () =>
          SupabaseService.createSignedUrlForCommissionInvoicePdf(path),
      fileName: 'factura-comision.pdf',
    );
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
    await openStoredFile(
      context,
      signedUrl: () => SupabaseService.createSignedUrlForComprobantePago(path),
      fileName: s.pagoComprobanteFileName,
    );
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
        content: Text(
          s.isEmitido
              ? 'Este corte ya tiene documento'
                  '${s.invoiceReference == null || s.invoiceReference!.trim().isEmpty ? '' : ' (${s.invoiceReference})'}. '
                  'Al anularlo, los pedidos vuelven a quedar libres para un corte nuevo. '
                  'El número de factura se conserva y no se reutiliza. '
                  'Un corte ya cobrado no se puede anular.'
              : 'Las líneas de pedido quedarán disponibles para un nuevo corte.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corte anulado. Los pedidos quedaron libres.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.brand));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final canEditTasa = AdminActionRules.canEditPlatformConfig(
      viewerRole: widget.viewerRole,
    );
    final rulesCard = _RulesCard(
      defaultRatePct: _defaultRate * 100,
      volumeTiersSummary: commissionVolumeTiersSummaryEs(_volumeTiers),
      canEditRates: _canEditRates,
      onEditRate: _busy ? null : _editDefaultRate,
      onEditImportadorRate: _busy ? null : _editImportadorRate,
      onEditVolumeTiers: _busy ? null : _editVolumeTiers,
    );
    final generateCta = _GenerateCutsCta(
      busy: _busy,
      onGeneratePreviousWeek: _busy ? null : _generatePreviousWeek,
      onGenerateCurrentWeek: _busy ? null : _generateCurrentWeek,
    );
    final settlementsBody = _rows.isEmpty
        ? Material(
            color: theme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.borderSubtle),
              ),
              child: Row(
                children: [
                  LucideIcon(
                    LucideGlyph.clipboardCheck,
                    size: 18,
                    color: theme.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sin liquidaciones aún. Use «Generar corte» en la cuenta operativa.',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : CommissionsDataTable(
            rows: _filteredRows,
            searchController: _searchController,
            statusFilter: (_filters.status == null ||
                    _filters.status == 'pagado' ||
                    _filters.status == 'emitido')
                ? _filters.status
                : '__advanced__',
            onStatusFilter: _onStatusPill,
            onSearchChanged: _onQuickSearch,
            expandedIds: _expandedSettlementIds,
            onToggleExpand: _toggleSettlementExpand,
            detailBuilder: _settlementDetail,
            onRowAction: _onSettlementRowAction,
            busy: _busy,
            tasaBcv: _tasaBcv,
            onOpenAdvancedFilters: _openCommissionSettlementFiltersSheet,
            activeFilterCount: _activeFilterCount,
            resetKey: _tableResetKey,
            onClearFilters: () {
              _searchController.clear();
              setState(() {
                _filters = const CommissionSettlementFilters();
                _tableResetKey++;
              });
            },
          );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommissionsKpiCards(rows: _rows, tasaBcv: _tasaBcv),
        const SizedBox(height: 12),
        CommissionCollectedIncomeCard(
          key: ValueKey('admin-income-$_incomeCardEpoch'),
          isAdmin: true,
          tasaBcv: _tasaBcv,
          onOpenSettlement: _openSettlementFromReport,
          onFilterImportador: _filterImportadorFromReport,
          onFilterDocumentType: _filterDocumentTypeFromReport,
        ),
        const SizedBox(height: 12),
        Text(
          'Historial de liquidaciones',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        settlementsBody,
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminTasaBcvCard(
          canEdit: canEditTasa,
          onRateChanged: (rate) {
            if (!mounted) return;
            setState(() => _tasaBcv = rate);
          },
        ),
        const SizedBox(height: 12),
        rulesCard,
        const SizedBox(height: 12),
        generateCta,
      ],
    );

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          color: theme.brand,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1080;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 70, child: leftColumn),
                        const SizedBox(width: 16),
                        Expanded(flex: 30, child: rightColumn),
                      ],
                    )
                  else ...[
                    leftColumn,
                    const SizedBox(height: 14),
                    rightColumn,
                  ],
                ],
              );
            },
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: theme.textPrimary.withOpacity(0.12),
              child: Center(
                child: CircularProgressIndicator(color: theme.brand),
              ),
            ),
          ),
      ],
    );
  }

  Widget _settlementDetail(CommissionSettlementModel s) {
    final theme = B2BThemeExtension.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.isBorrador && _volumeByImportador[s.importadorId] != null) ...[
          CommissionVolumeTierBanner(
            volumeContext: _volumeByImportador[s.importadorId]!,
            compact: true,
            title: 'Volumen mes (referencia al emitir)',
          ),
          const SizedBox(height: 8),
        ],
        Text(
          s.isDeliveryNote
              ? 'Base comisión (neta, sin IVA): REF ${s.baseImponibleComisionUsd.toStringAsFixed(2)}'
              : 'Base: REF ${s.baseImponibleComisionUsd.toStringAsFixed(2)} + '
                  'IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %: '
                  'REF ${s.ivaComisionUsd.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 12, color: theme.textSecondary),
        ),
        if (!s.isBorrador)
          Text(
            s.documentTypeEffective.labelEs,
            style: TextStyle(fontSize: 12, color: theme.textPrimary),
          ),
        if (s.importadorRif != null && s.importadorRif!.isNotEmpty)
          Text(
            'RIF: ${s.importadorRif}',
            style: TextStyle(fontSize: 12, color: theme.textPrimary),
          ),
        if (s.issuedAt != null)
          Text(
            'Emitido: ${formatEsShortDateTime(s.issuedAt)}',
            style: TextStyle(fontSize: 12, color: theme.textPrimary),
          ),
        if (s.paidAt != null)
          Text(
            'Pagado: ${formatEsShortDateTime(s.paidAt)}',
            style: TextStyle(fontSize: 12, color: theme.textPrimary),
          ),
        if (s.isEmitido && s.pagoEstadoLabelEs.isNotEmpty)
          Text(
            'Pago: ${s.pagoEstadoLabelEs}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: s.pagoEnRevision ? theme.brand : theme.textPrimary,
            ),
          ),
        if (s.pagoRechazado &&
            s.pagoRechazoNota != null &&
            s.pagoRechazoNota!.trim().isNotEmpty)
          Text(
            'Rechazo: ${s.pagoRechazoNota}',
            style: TextStyle(fontSize: 11, color: errorColor),
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
                          documentType:
                              CommissionSettlementDocumentType.fiscalInvoice,
                        ),
                child: const Text('Emitir factura'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _issueSettlement(
                          s,
                          documentType:
                              CommissionSettlementDocumentType.deliveryNote,
                        ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.textSecondary,
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
            ],
            if ((s.isEmitido || s.isPagado) && s.tieneFacturaPdf)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _abrirFacturaPdf(s),
                icon: LucideIcon(
                  LucideGlyph.fileText,
                  size: 16,
                  color: theme.brand,
                ),
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
                icon: LucideIcon(
                  LucideGlyph.copy,
                  size: 16,
                  color: theme.brand,
                ),
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
                style: TextButton.styleFrom(foregroundColor: errorColor),
                child: const Text('Rechazar'),
              ),
            ],
            if (s.isEmitido && !s.pagoEnRevision)
              TextButton(
                onPressed: _busy ? null : () => _markPaid(s),
                child: const Text('Pagado sin comprobante'),
              ),
            if (s.canAnular)
              TextButton(
                onPressed: _busy ? null : () => _cancelSettlement(s),
                style: TextButton.styleFrom(foregroundColor: errorColor),
                child: const Text('Anular corte'),
              ),
          ],
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({
    required this.defaultRatePct,
    required this.volumeTiersSummary,
    required this.canEditRates,
    this.onEditRate,
    this.onEditImportadorRate,
    this.onEditVolumeTiers,
  });

  final double defaultRatePct;
  final String volumeTiersSummary;
  final bool canEditRates;
  final VoidCallback? onEditRate;
  final VoidCallback? onEditImportadorRate;
  final VoidCallback? onEditVolumeTiers;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cuenta operativa',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Métodos de cobro y reglas de retención.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _ruleRow(
              context: context,
              glyph: LucideGlyph.landmark,
              title: 'Métodos de cobro',
              subtitle: 'Zelle / Cuenta bancaria nacional',
            ),
            const SizedBox(height: 6),
            _ruleRow(
              context: context,
              glyph: LucideGlyph.percent,
              title: 'Comisión base',
              subtitle: '${defaultRatePct.toStringAsFixed(2)} %',
              actionLabel: 'Ver / editar',
              onAction: onEditRate,
              showAction: canEditRates,
            ),
            const SizedBox(height: 6),
            _ruleRow(
              context: context,
              glyph: LucideGlyph.store,
              title: 'Tasa por importador',
              subtitle: 'Override opcional',
              actionLabel: 'Configurar',
              onAction: onEditImportadorRate,
              showAction: canEditRates,
            ),
            const SizedBox(height: 6),
            _ruleRow(
              context: context,
              glyph: LucideGlyph.barChart3,
              title: 'Tramos por volumen',
              subtitle: volumeTiersSummary,
              actionLabel: 'Tramos',
              onAction: onEditVolumeTiers,
              showAction: canEditRates,
            ),
            const SizedBox(height: 10),
            Text(
              'B2B-COM- (IVA) · B2B-NOT- (sin IVA).',
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: theme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _ruleRow({
    required BuildContext context,
    required LucideGlyph glyph,
    required String title,
    required String subtitle,
    String actionLabel = '',
    VoidCallback? onAction,
    bool showAction = false,
  }) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LucideIcon(glyph, size: 16, color: theme.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (showAction)
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.brand,
                side: BorderSide(color: theme.borderStrong),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Centro de acción primaria: generar cortes en borrador.
class _GenerateCutsCta extends StatelessWidget {
  const _GenerateCutsCta({
    required this.busy,
    this.onGeneratePreviousWeek,
    this.onGenerateCurrentWeek,
  });

  final bool busy;
  final VoidCallback? onGeneratePreviousWeek;
  final VoidCallback? onGenerateCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.brandContainer,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.brand.withOpacity(0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generador de cortes',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Crea borradores quincenales / semanales a partir de comisiones devengadas.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onGeneratePreviousWeek,
              icon: busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.surfaceCard,
                      ),
                    )
                  : LucideIcon(
                      LucideGlyph.clipboardCheck,
                      size: 16,
                      color: theme.surfaceCard,
                    ),
              label: const Text('Generar corte (semana anterior)'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.brand,
                foregroundColor: theme.surfaceCard,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onGenerateCurrentWeek,
              icon: LucideIcon(
                LucideGlyph.activity,
                size: 15,
                color: theme.brand,
              ),
              label: const Text('Semana actual (pruebas)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.brand,
                side: BorderSide(color: theme.borderStrong),
                minimumSize: const Size.fromHeight(38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultRateDialog extends StatefulWidget {
  const _DefaultRateDialog({required this.initialPct});

  final double initialPct;

  @override
  State<_DefaultRateDialog> createState() => _DefaultRateDialogState();
}

class _DefaultRateDialogState extends State<_DefaultRateDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialPct.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pct = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (pct == null || pct < 0 || pct > 100) {
      setState(() => _error = 'Indique un porcentaje válido (0–100).');
      return;
    }
    Navigator.of(context).pop(pct);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return UnifiedActionDialog(
      title: 'Comisión base',
      subtitle: 'Tasa global de retención aplicada por defecto.',
      glyph: LucideGlyph.percent,
      tone: UnifiedActionTone.info,
      primaryLabel: 'Guardar',
      onPrimary: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Porcentaje (%)',
              hintText: '2.50',
              suffixText: '%',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.brand, width: 1.4),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportadorRateDialog extends StatefulWidget {
  const _ImportadorRateDialog({required this.importers});

  final List<ImporterOption> importers;

  @override
  State<_ImportadorRateDialog> createState() => _ImportadorRateDialogState();
}

class _ImportadorRateDialogState extends State<_ImportadorRateDialog> {
  late String _selectedId;
  final _ctrl = TextEditingController(text: '5.00');
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.importers.first.id;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _ctrl.text.trim();
    double? rate;
    if (trimmed.isNotEmpty) {
      final pct = double.tryParse(trimmed.replaceAll(',', '.'));
      if (pct == null || pct < 0 || pct > 100) {
        setState(() => _error = 'Porcentaje inválido (0–100 o vacío).');
        return;
      }
      rate = pct / 100;
    }
    Navigator.of(context).pop((id: _selectedId, rate: rate));
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return UnifiedActionDialog(
      title: 'Tasa por importador',
      subtitle: 'Override opcional. Vacío = tramos por volumen.',
      glyph: LucideGlyph.store,
      tone: UnifiedActionTone.info,
      primaryLabel: 'Guardar',
      onPrimary: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Importador',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
            ),
            items: widget.importers
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
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedId = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Porcentaje (%)',
              hintText: '5.00',
              suffixText: '%',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.brand, width: 1.4),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

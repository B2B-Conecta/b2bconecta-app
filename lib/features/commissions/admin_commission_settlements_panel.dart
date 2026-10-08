import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/core/utils/stored_file_page.dart';

import 'commission_collected_income_card.dart';
import 'commission_settlement_document_type.dart';
import 'commission_settlement_model.dart';
import 'importer_commission_volume_context.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'commission_settlement_filter_utils.dart';
import 'commission_volume_tiers.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'commission_settlement_fiscal.dart';
import 'admin_tasa_bcv_card.dart';
import 'commission_volume_tier_banner.dart';
import 'commission_settlement_lines_section.dart';
import 'commission_settlement_list_filter_bar.dart';
import 'commission_settlement_filters_sheet.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';

/// Admin: cortes semanales, facturación y cobro de comisiones B2B Conecta.
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
  Map<String, ImporterCommissionVolumeContext> _volumeByImportador = {};
  bool _busy = false;
  final Set<String> _expandedSettlementIds = {};
  final TextEditingController _searchController = TextEditingController();
  CommissionSettlementFilters _filters = const CommissionSettlementFilters();
  int _incomeCardEpoch = 0;

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
      if (!mounted) return;
      setState(() {
        _defaultRate = rate;
        _volumeTiers = tiers;
        _rows = rows;
        _volumeByImportador = volumeByImportador;
        _loading = false;
        _incomeCardEpoch++;
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
              const SizedBox(height: 12),
              _CommissionAmountsStrip(rows: _rows),
              const SizedBox(height: 12),
              Text(
                _filters.hasActiveFilters
                    ? 'Cortes y liquidaciones (${_filteredRows.length} de ${_rows.length})'
                    : 'Cortes y liquidaciones (${_rows.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openCommissionSettlementFiltersSheet,
                  icon: Badge(
                    isLabelVisible: _activeFilterCount > 0,
                    label: Text('$_activeFilterCount'),
                    backgroundColor: AppColors.brand,
                    child: const Icon(Icons.tune),
                  ),
                  label: const Text('Filtros'),
                ),
              ],
              const SizedBox(height: 8),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Sin cobros registrados. Genere un corte en borrador abajo.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_filteredRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Text(
                        'Ningún corte coincide con los filtros.',
                        style: TextStyle(color: AppColors.textSecondary),
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
                PagedItems(
                  items: _filteredRows,
                  embedded: true,
                  itemBuilder: _settlementTile,
                ),
              const SizedBox(height: 12),
              CommissionCollectedIncomeCard(
                key: ValueKey('admin-income-$_incomeCardEpoch'),
                isAdmin: true,
                onOpenSettlement: _openSettlementFromReport,
                onFilterImportador: _filterImportadorFromReport,
                onFilterDocumentType: _filterDocumentTypeFromReport,
              ),
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
    final ref = s.invoiceReference?.trim() ?? '';
    final name = s.importadorBusinessName ?? 'Importador';
    final status = CommissionSettlementModel.statusLabelEs(s.status);
    final amount = 'USD ${s.totalCobroUsd.toStringAsFixed(2)}';
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
          ref.isNotEmpty ? ref : name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.isNotEmpty
                  ? '$name · $status · $amount'
                  : '$status · $amount',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${s.periodLabelEs} · ${s.lineCount} pedido(s) · Consultar detalle',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (s.canAnular)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => _cancelSettlement(s),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Anular corte'),
                ),
              ),
            if (s.isBorrador && _volumeByImportador[s.importadorId] != null) ...[
              const SizedBox(height: 6),
              CommissionVolumeTierBanner(
                volumeContext: _volumeByImportador[s.importadorId]!,
                compact: true,
                title: 'Volumen mes (referencia al emitir)',
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.isDeliveryNote
                      ? 'Base comisión (neta, sin IVA): USD ${s.baseImponibleComisionUsd.toStringAsFixed(2)}'
                      : 'Base: USD ${s.baseImponibleComisionUsd.toStringAsFixed(2)} + '
                          'IVA ${CommissionSettlementFiscal.ivaPct.toStringAsFixed(0)} %: '
                          'USD ${s.ivaComisionUsd.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (!s.isBorrador)
                  Text(
                    s.documentTypeEffective.labelEs,
                    style: const TextStyle(fontSize: 12),
                  ),
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
                          ? AppColors.brandBlue
                          : AppColors.textPrimary,
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
                          foregroundColor: AppColors.textSecondary,
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

class _CommissionAmountsStrip extends StatelessWidget {
  const _CommissionAmountsStrip({required this.rows});

  final List<CommissionSettlementModel> rows;

  @override
  Widget build(BuildContext context) {
    var cobrado = 0.0;
    var pendiente = 0.0;
    for (final s in rows) {
      if (s.isPagado) cobrado += s.totalCobroUsd;
      if (s.isEmitido) pendiente += s.totalCobroUsd;
    }

    return Row(
      children: [
        Expanded(
          child: _amount(
            label: 'Cobrado',
            value: cobrado,
            color: AppColors.successGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _amount(
            label: 'Pendiente',
            value: pendiente,
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }

  Widget _amount({
    required String label,
    required double value,
    required Color color,
  }) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'USD ${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
          ],
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
            Text(
              'Reglas y cortes',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Devengo al marcar Recibido · tasa por volumen o override',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tasas',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _configRow(
              icon: Icons.percent,
              title: 'Tasa global',
              subtitle: '${defaultRatePct.toStringAsFixed(2)} %',
              actionLabel: 'Editar',
              onAction: onEditRate,
            ),
            const SizedBox(height: 6),
            _configRow(
              icon: Icons.stacked_line_chart,
              title: 'Tramos volumen',
              subtitle: volumeTiersSummary,
              actionLabel: 'Tramos',
              onAction: onEditVolumeTiers,
            ),
            const SizedBox(height: 6),
            _configRow(
              icon: Icons.store_outlined,
              title: 'Tasa por importador',
              subtitle: 'Override opcional',
              actionLabel: 'Configurar',
              onAction: onEditImportadorRate,
            ),
            const SizedBox(height: 12),
            Text(
              'B2B-COM- (IVA) · B2B-NOT- (sin IVA). Históricos ML- se conservan.',
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Generar cortes en borrador',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
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
                      foregroundColor: AppColors.brandAccent,
                      side: BorderSide(color: AppColors.brandAccent),
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
                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
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
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.brandAccent),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AppColors.textSecondary,
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

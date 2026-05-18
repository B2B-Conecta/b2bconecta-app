import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/commission_settlement_model.dart';
import '../models/catalog_filters.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'main_shell_tab.dart';

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
  final Set<String> _expandedSettlementIds = {};

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
      final rows = await SupabaseService.fetchCommissionSettlements();
      if (!mounted) return;
      setState(() {
        _defaultRate = rate;
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
    await _generateForWeek(prevWeek);
  }

  Future<void> _generateCurrentWeek() async {
    setState(() => _busy = true);
    try {
      final result =
          await SupabaseService.adminGenerateCommissionSettlementsCurrentWeek();
      if (!mounted) return;
      _showGenerateResult(result, label: 'semana actual');
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
    final n = (result['created_count'] as num?)?.toInt() ?? 0;
    final ws = result['week_start']?.toString();
    final we = result['week_end']?.toString();
    final period = (ws != null && we != null) ? ' ($ws → $we)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n > 0
              ? 'Se generaron $n corte(s) en borrador ($label$period).'
              : 'Sin líneas devengadas pendientes para $label$period. '
                  'Use «Semana actual» si acaba de marcar pedidos Recibido hoy.',
        ),
      ),
    );
  }

  Future<void> _generateForWeek(DateTime weekStart) async {
    setState(() => _busy = true);
    try {
      final result = await SupabaseService.adminGenerateCommissionSettlementsWeek(
        weekStart: weekStart,
      );
      if (!mounted) return;
      _showGenerateResult(result, label: 'semana seleccionada');
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
                  labelText: 'Porcentaje (%) — vacío = global',
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

  Future<void> _issueSettlement(CommissionSettlementModel s) async {
    String previewRef = '';
    try {
      previewRef = await SupabaseService.peekCommissionInvoiceReference();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la referencia: $e')),
      );
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emitir factura MotoLink'),
        content: Text(
          'Se asignará automáticamente la referencia:\n\n'
          '$previewRef\n\n'
          'Formato: ML-COM-{año}-{secuencia de 6 dígitos}. '
          'El importador la verá en sus cortes de comisión.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade800),
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
    setState(() => _busy = true);
    try {
      final assignedRef = await SupabaseService.adminIssueCommissionSettlement(
        settlementId: s.id,
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
                ? 'Corte emitido. Factura: $assignedRef (PDF listo).'
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
          '¿Confirma el cobro de USD ${s.totalCommissionUsd.toStringAsFixed(2)} '
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
                onGenerateCurrentWeek: _busy ? null : _generateCurrentWeek,
                onGeneratePreviousWeek: _busy ? null : _generatePreviousWeek,
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
                    if ((s.isEmitido || s.isPagado) && s.tieneFacturaPdf)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _abrirFacturaPdf(s),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Ver factura PDF'),
                      ),
                    if ((s.isEmitido || s.isPagado) && !s.tieneFacturaPdf)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _generarFacturaPdf(s),
                        child: const Text('Generar factura PDF'),
                      ),
                    if ((s.isEmitido || s.isPagado) && s.tieneFacturaPdf)
                      TextButton(
                        onPressed: _busy ? null : () => _generarFacturaPdf(s),
                        child: const Text('Regenerar PDF'),
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

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.defaultRatePct,
    this.onEditRate,
    this.onEditImportadorRate,
    this.onGenerateCurrentWeek,
    this.onGeneratePreviousWeek,
  });

  final double defaultRatePct;
  final VoidCallback? onEditRate;
  final VoidCallback? onEditImportadorRate;
  final VoidCallback? onGenerateCurrentWeek;
  final VoidCallback? onGeneratePreviousWeek;

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
              '(cada importador puede tener tasa propia). '
              'Los lunes 07:00 UTC se genera el corte de la semana anterior. '
              'Al emitir, la referencia es automática y se genera el PDF de factura de comisión.',
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
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Generar corte (pruebas)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onGenerateCurrentWeek,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Semana actual'),
                ),
                OutlinedButton.icon(
                  onPressed: onGeneratePreviousWeek,
                  icon: const Icon(Icons.calendar_view_week, size: 18),
                  label: const Text('Semana anterior'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

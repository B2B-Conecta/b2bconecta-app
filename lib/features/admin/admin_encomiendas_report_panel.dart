import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/payments/document_type_preference.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'encomiendas_report_excel_service.dart';
import 'package:motolink_pro_app/core/utils/excel_file_export.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'admin_product_sales_ranking.dart';
import 'encomiendas_filters_bar.dart';
import 'encomiendas_orders_table.dart';
import 'executive_summary_cards.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';

/// Reportes de encomiendas: facturación (preferencia de documento) y métricas gerenciales.
class AdminEncomiendasReportPanel extends StatefulWidget {
  const AdminEncomiendasReportPanel({
    super.key,
    this.embeddedInHub = false,
  });

  /// Cuando vive dentro de [AdminReportsHubPanel] (sin tabs internas).
  final bool embeddedInHub;

  @override
  State<AdminEncomiendasReportPanel> createState() =>
      _AdminEncomiendasReportPanelState();
}

class _AdminEncomiendasReportPanelState
    extends State<AdminEncomiendasReportPanel> {
  List<TransactionRequestModel> _raw = [];
  List<TransactionRequestModel> _filtered = [];
  List<ImporterOption> _importers = [];
  bool _loading = false;
  String? _error;

  late DateTime _desde;
  late DateTime _hasta;
  final _searchCtrl = TextEditingController();

  EncomiendasPeriodPreset _periodPreset = EncomiendasPeriodPreset.d90;
  EncomiendasStatusPill _statusPill = EncomiendasStatusPill.todos;

  String? _ownerId;
  String _docPrefFilter = 'all';

  /// `null` = todos; 10/20 = top productos más vendidos.
  int? _topSoldLimit;
  bool _exporting = false;

  static const _docOptions = <_DocOpt>[
    _DocOpt('all', 'Todas'),
    _DocOpt(DocumentTypePreference.notaEntrega, 'Nota de entrega'),
    _DocOpt(DocumentTypePreference.facturaFiscal, 'Factura fiscal'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = DateTime(now.year, now.month, now.day);
    _desde = _hasta.subtract(const Duration(days: 90));
    _periodPreset = EncomiendasPeriodPreset.d90;
    _searchCtrl.addListener(_applyLocalFilters);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _reloadImporters();
    await _load();
  }

  Future<void> _reloadImporters() async {
    try {
      final imp = await SupabaseService.fetchImporterOptions();
      if (!mounted) return;
      setState(() => _importers = imp);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyLocalFilters);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = _statusPill.serverStatuses?.toList();
      final rows = await SupabaseService.fetchTransactionRequestsForAdminReport(
        createdFromLocal: _desde,
        createdToLocal: _hasta,
        statuses: statuses,
        ownerId: _ownerId,
      );
      if (!mounted) return;
      setState(() {
        _raw = rows;
        _loading = false;
      });
      _applyLocalFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<TransactionRequestModel> _applyLocalFiltersCore({
    bool applyTopSold = true,
  }) {
    var list = List<TransactionRequestModel>.from(_raw);

    switch (_docPrefFilter) {
      case DocumentTypePreference.notaEntrega:
      case DocumentTypePreference.facturaFiscal:
        list = list
            .where((r) => r.documentTypePreference?.trim() == _docPrefFilter)
            .toList();
        break;
      default:
        break;
    }

    list = TransactionRequestFilterUtils.apply(
      list,
      searchQuery: _searchCtrl.text,
      statusFilter: null,
    );

    if (applyTopSold && _topSoldLimit != null) {
      final keys = topProductKeys(list, limit: _topSoldLimit!);
      list = list.where((r) => keys.contains(adminProductSalesKey(r))).toList();
    }

    return list;
  }

  List<AdminProductSalesStat> get _productSalesRanking =>
      aggregateProductSales(_applyLocalFiltersCore(applyTopSold: false));

  void _applyLocalFilters() {
    setState(() => _filtered = _applyLocalFiltersCore());
  }

  void _clearAllFilters() {
    setState(() {
      _statusPill = EncomiendasStatusPill.todos;
      _ownerId = null;
      _docPrefFilter = 'all';
      _topSoldLimit = null;
      _searchCtrl.clear();
      _periodPreset = EncomiendasPeriodPreset.d90;
      final now = DateTime.now();
      _hasta = DateTime(now.year, now.month, now.day);
      _desde = _hasta.subtract(const Duration(days: 90));
    });
    _load();
  }

  int get _advancedActiveCount {
    var n = 0;
    if (_ownerId != null) n++;
    if (_docPrefFilter != 'all') n++;
    if (_topSoldLimit != null) n++;
    return n;
  }

  void _applyPeriodPreset(EncomiendasPeriodPreset preset) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final days = switch (preset) {
      EncomiendasPeriodPreset.d7 => 7,
      EncomiendasPeriodPreset.d30 => 30,
      EncomiendasPeriodPreset.d90 => 90,
      EncomiendasPeriodPreset.custom => null,
    };
    if (days == null) return;
    setState(() {
      _periodPreset = preset;
      _hasta = end;
      _desde = end.subtract(Duration(days: days));
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await pickEncomiendasCustomRange(
      context: context,
      desde: _desde,
      hasta: _hasta,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _desde = picked.$1;
      _hasta = picked.$2;
      _periodPreset = EncomiendasPeriodPreset.custom;
    });
    await _load();
  }

  void _onStatusPill(EncomiendasStatusPill pill) {
    setState(() => _statusPill = pill);
    _load();
  }

  Future<void> _applyAdvanced({
    required String? ownerId,
    required String docPref,
    required int? topSoldLimit,
  }) async {
    setState(() {
      _ownerId = ownerId;
      _docPrefFilter = docPref;
      _topSoldLimit = topSoldLimit;
    });
    await _load();
  }

  Widget _buildFiltersBar() {
    return EncomiendasFiltersBar(
      desde: _desde,
      hasta: _hasta,
      periodPreset: _periodPreset,
      statusPill: _statusPill,
      importers: _importers,
      ownerId: _ownerId,
      docPrefFilter: _docPrefFilter,
      topSoldLimit: _topSoldLimit,
      searchCtrl: _searchCtrl,
      loading: _loading,
      exporting: _exporting,
      canExport: _filtered.isNotEmpty && !_exporting && !_loading,
      filteredCount: _filtered.length,
      advancedActiveCount: _advancedActiveCount,
      onPeriodPreset: _applyPeriodPreset,
      onCustomRange: _pickCustomRange,
      onStatusPill: _onStatusPill,
      onSearchChanged: (_) => _applyLocalFilters(),
      onClearSearch: () {
        _searchCtrl.clear();
        _applyLocalFilters();
      },
      onExport: _exportExcel,
      onRefresh: _load,
      onApplyAdvanced: _applyAdvanced,
      onClearAll: _clearAllFilters,
    );
  }

  EncomiendasReportExportMeta _exportMeta() {
    final lines = <String>[];
    lines.add('Estados: ${_statusPill.labelEs}');
    if (_ownerId != null) {
      final imp = _importers
          .where((o) => o.id == _ownerId)
          .map((o) => o.businessName)
          .firstOrNull;
      lines.add('Importador: ${imp ?? _ownerId}');
    }
    final docLabel = _docOptions
        .where((o) => o.value == _docPrefFilter)
        .map((o) => o.label)
        .firstOrNull;
    if (docLabel != null && _docPrefFilter != 'all') {
      lines.add('Documento: $docLabel');
    }
    if (_topSoldLimit != null) {
      lines.add('Productos más vendidos: top ${_topSoldLimit!}');
    }
    final q = _searchCtrl.text.trim();
    if (q.isNotEmpty) lines.add('Búsqueda: «$q»');
    lines.add('Filas exportadas: ${_filtered.length}');
    return EncomiendasReportExportMeta(
      generatedAt: DateTime.now(),
      dateFromLabel:
          '${_desde.day.toString().padLeft(2, '0')}/${_desde.month.toString().padLeft(2, '0')}/${_desde.year}',
      dateToLabel:
          '${_hasta.day.toString().padLeft(2, '0')}/${_hasta.month.toString().padLeft(2, '0')}/${_hasta.year}',
      filterSummaryLines: lines,
    );
  }

  Future<void> _exportExcel() async {
    if (_loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Espere a que termine la carga del servidor.'),
        ),
      );
      return;
    }
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay filas para exportar. Amplíe fechas o quite filtros.',
          ),
        ),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = EncomiendasReportExcelService.buildReportBytes(
        _filtered,
        meta: _exportMeta(),
        topProducts: _productSalesRanking,
      );
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final from = ymd(_desde);
      final to = ymd(_hasta);
      final periodSuffix = from == to ? from : '${from}_a_$to';
      final result = await saveExcelForExport(
        name: 'B2B_Conecta_Encomiendas_$periodSuffix',
        bytes: bytes,
      );
      if (!mounted) return;
      if (result == ExcelExportResult.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exportación cancelada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            excelExportSavedMessage(
              'Excel listo: ${_filtered.length} pedidos («Encomiendas») '
              'y ranking de productos («Productos mas vendidos»).',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _topSoldProductsSection() {
    final theme = B2BThemeExtension.of(context);
    final ranking = _productSalesRanking;
    if (ranking.isEmpty) {
      return Text(
        'Sin ventas en el período con los filtros actuales.',
        style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
      );
    }

    final displayLimit = _topSoldLimit ?? 10;
    final shown = ranking.take(displayLimit).toList();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(height: 1, color: theme.border),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: i < 3
                      ? theme.brand.withOpacity(0.18)
                      : theme.surfaceSubtle,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: i < 3 ? theme.brand : theme.textSecondary,
                    ),
                  ),
                ),
                title: Text(
                  shown[i].productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: theme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  [
                    if ((shown[i].productSku ?? '').isNotEmpty)
                      'SKU ${shown[i].productSku}',
                    if ((shown[i].importerName ?? '').isNotEmpty)
                      shown[i].importerName!,
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: theme.textSecondary),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${shown[i].unitsSold} uds.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      '${shown[i].totalRefUsd.toStringAsFixed(2)} REF',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    return ExecutiveSummaryStaticCards(orders: _applyLocalFiltersCore());
  }

  Widget _buildEncomiendasBody() {
    if (_error != null && _raw.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Builder(
        builder: (context) {
          final mobile = MediaQuery.sizeOf(context).width < 600;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, mobile ? 8 : 0, 16, 24),
            children: [
              _buildFiltersBar(),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final theme = B2BThemeExtension.of(context);
                  return Row(
                    children: [
                      LucideIcon(
                        LucideGlyph.barChart3,
                        size: 18,
                        color: theme.brand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mobile ? 'Resumen' : 'Resumen gerencial',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: mobile ? 14 : 15,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              _summary(),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final theme = B2BThemeExtension.of(context);
                  return Row(
                    children: [
                      LucideIcon(
                        LucideGlyph.trendingUp,
                        size: 18,
                        color: theme.brand,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          mobile ? 'Top ventas' : 'Productos más vendidos',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: mobile ? 14 : 15,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      if (_topSoldLimit != null)
                        Text(
                          'Top $_topSoldLimit',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: theme.textSecondary,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              _topSoldProductsSection(),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final theme = B2BThemeExtension.of(context);
                  return Row(
                    children: [
                      LucideIcon(
                        LucideGlyph.fileText,
                        size: 18,
                        color: theme.brand,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Detalle de pedidos',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: mobile ? 14 : 15,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              EncomiendasOrdersTable(
                orders: _filtered,
                loading: _loading && _filtered.isEmpty,
                errorMessage: _error,
                onRetry: _load,
                onRefresh: _load,
                pageSize: 10,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildEncomiendasBody();
  }
}

class _DocOpt {
  const _DocOpt(this.value, this.label);
  final String value;
  final String label;
}

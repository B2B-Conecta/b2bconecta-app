import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/payments/document_type_preference.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'admin_promo_campaigns_panel.dart';
import 'package:motolink_pro_app/features/referrals/admin_referrals_panel.dart';
import 'admin_returns_report_panel.dart';
import 'admin_user_monitoring_panel.dart';
import 'encomiendas_report_excel_service.dart';
import 'package:motolink_pro_app/core/utils/excel_file_export.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/filter_chip_strip.dart';
import 'package:motolink_pro_app/core/layout/filter_menu_button.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'admin_product_sales_ranking.dart';
import 'admin_catalog_featured_section.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';

/// Reportes de encomiendas: facturación (preferencia de documento) y métricas gerenciales.
class AdminEncomiendasReportPanel extends StatefulWidget {
  const AdminEncomiendasReportPanel({super.key});

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

  /// Vacío = todos los estados (servidor).
  final Set<String> _statusSelection = {};

  String? _ownerId;
  String _docPrefFilter = 'all';
  bool _soloConValoracion = false;
  bool _soloPagosAprobados = false;
  bool _soloEntregados = false;

  /// `null` = todos; 10/20/50 = solo pedidos de los productos más vendidos.
  int? _topSoldLimit;
  int _sectionIndex = 0;
  bool _exporting = false;

  static const _topSoldOptions = <int>[10, 20, 50];

  static const _docOptions = <_DocOpt>[
    _DocOpt('all', 'Todas las preferencias'),
    _DocOpt('pendiente', 'Preferencia pendiente'),
    _DocOpt(DocumentTypePreference.notaEntrega, 'Nota de entrega'),
    _DocOpt(DocumentTypePreference.facturaFiscal, 'Factura fiscal'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = DateTime(now.year, now.month, now.day);
    _desde = _hasta.subtract(const Duration(days: 90));
    _searchCtrl.addListener(_applyLocalFilters);
    MainShellTabController.adminPresenceRequest.addListener(_openPresence);
    _bootstrap();
  }

  void _openPresence() {
    if (!mounted) return;
    setState(() => _sectionIndex = 2);
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
    MainShellTabController.adminPresenceRequest.removeListener(_openPresence);
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
      final statuses =
          _statusSelection.isEmpty ? null : _statusSelection.toList();
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

    if (_soloEntregados) {
      list = list
          .where((r) => r.status == TransactionRequestStatus.entregado)
          .toList();
    }

    switch (_docPrefFilter) {
      case 'pendiente':
        list = list
            .where(
              (r) =>
                  r.documentTypePreference == null ||
                  r.documentTypePreference!.trim().isEmpty,
            )
            .toList();
        break;
      case DocumentTypePreference.notaEntrega:
      case DocumentTypePreference.facturaFiscal:
        list = list
            .where((r) => r.documentTypePreference?.trim() == _docPrefFilter)
            .toList();
        break;
      default:
        break;
    }

    if (_soloConValoracion) {
      list = list.where((r) => r.aliadoExperienceSubmittedAt != null).toList();
    }
    if (_soloPagosAprobados) {
      list = list
          .where(
            (r) => r.pagoEstadoRevision?.trim() == 'aprobado',
          )
          .toList();
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

  void _setDocPrefFilter(String value) {
    setState(() => _docPrefFilter = value);
    _applyLocalFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _statusSelection.clear();
      _ownerId = null;
      _docPrefFilter = 'all';
      _soloConValoracion = false;
      _soloPagosAprobados = false;
      _soloEntregados = false;
      _topSoldLimit = null;
      _searchCtrl.clear();
    });
    _load();
  }

  String _formatDateShort(DateTime d) => '${d.day}/${d.month}/${d.year}';

  int get _activeFilterCount {
    var n = 0;
    if (_statusSelection.isNotEmpty) n++;
    if (_ownerId != null) n++;
    if (_docPrefFilter != 'all') n++;
    if (_soloConValoracion) n++;
    if (_soloPagosAprobados) n++;
    if (_soloEntregados) n++;
    if (_topSoldLimit != null) n++;
    if (_searchCtrl.text.trim().isNotEmpty) n++;
    return n;
  }

  Future<void> _showAdvancedFiltersSheet() async {
    await showAdaptiveAdminSheet<void>(
      context: context,
      builder: (ctx, _) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshSheet() => setSheetState(() {});
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Filtros del reporte',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estado e importador → servidor',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Estado del pedido',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final s
                            in TransactionRequestStatus.valuesForReportFilter)
                          FilterChip(
                            label: Text(
                              TransactionRequestStatus.labelEs(s),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            selected: _statusSelection.contains(s),
                            visualDensity: VisualDensity.compact,
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _statusSelection.add(s);
                                } else {
                                  _statusSelection.remove(s);
                                }
                              });
                              refreshSheet();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _ownerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Importador',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos los importadores'),
                        ),
                        ..._importers.map(
                          (o) => DropdownMenuItem<String?>(
                            value: o.id,
                            child: Text(
                              o.businessName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _ownerId = v);
                        refreshSheet();
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Preferencia de documento',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedFilterBar(
                      labels: [for (final opt in _docOptions) opt.label],
                      selectedIndex: _docOptions
                          .indexWhere((opt) => opt.value == _docPrefFilter)
                          .clamp(0, _docOptions.length - 1),
                      onSelected: (index) {
                        _setDocPrefFilter(_docOptions[index].value);
                        refreshSheet();
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Con valoración de la tienda minorista',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _soloConValoracion,
                      onChanged: (v) {
                        setState(() => _soloConValoracion = v);
                        _applyLocalFilters();
                        refreshSheet();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Pago aprobado',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _soloPagosAprobados,
                      onChanged: (v) {
                        setState(() => _soloPagosAprobados = v);
                        _applyLocalFilters();
                        refreshSheet();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Solo entregados',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _soloEntregados,
                      onChanged: (v) {
                        setState(() => _soloEntregados = v);
                        _applyLocalFilters();
                        refreshSheet();
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Productos más vendidos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Limita el detalle y el Excel a los productos con más unidades '
                      'en el rango y filtros actuales (excepto este tope).',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedFilterBar(
                      labels: [
                        'Todos',
                        for (final n in _topSoldOptions) 'Top $n',
                      ],
                      selectedIndex: _topSoldLimit == null
                          ? 0
                          : _topSoldOptions.indexOf(_topSoldLimit!) + 1,
                      onSelected: (index) {
                        setState(() {
                          _topSoldLimit =
                              index == 0 ? null : _topSoldOptions[index - 1];
                        });
                        _applyLocalFilters();
                        refreshSheet();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _clearAllFilters();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Limpiar todo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _load();
                            },
                            child: const Text('Aplicar al servidor'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactFiltersCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: MediaQuery.sizeOf(context).width < 600
                          ? 'Producto, SKU, tienda minorista…'
                          : 'Buscar producto, SKU, tienda minorista…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.borderSubtle),
                      ),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyLocalFilters();
                              },
                            ),
                    ),
                    onChanged: (_) => _applyLocalFilters(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  tooltip: 'Actualizar desde servidor',
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isAdminDesktopLayout(context))
              _desktopFilterToolbar()
            else
              FilterChipStrip(
                children: [
                  for (final (i, days) in const [30, 90, 365].indexed)
                    StripChip(
                      label: '$days días',
                      selected: _presetDayIndex == i,
                      onTap: _loading
                          ? null
                          : () {
                              _presetDays(days);
                              _load();
                            },
                    ),
                  StripChip(
                    label:
                        '${_formatDateShort(_desde)} – ${_formatDateShort(_hasta)}',
                    icon: Icons.calendar_today_outlined,
                    selected: _presetDayIndex < 0,
                    onTap: _loading ? null : _pickRange,
                  ),
                  const StripDivider(),
                  StripChip(
                    label: _activeFilterCount == 0
                        ? 'Filtros'
                        : 'Filtros ($_activeFilterCount)',
                    icon: Icons.tune,
                    selected: _activeFilterCount > 0,
                    onTap: _showAdvancedFiltersSheet,
                  ),
                  ..._activeFilterChips(),
                  if (_activeFilterCount > 0)
                    TextButton(
                      onPressed: _clearAllFilters,
                      child: const Text('Limpiar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _desktopFilterToolbar() {
    final preset = _presetDayIndex;
    const presets = [30, 90, 365];
    final rangeLabel =
        '${_formatDateShort(_desde)} – ${_formatDateShort(_hasta)}';
    return FilterToolbar(
      children: [
        FilterMenuButton(
          icon: Icons.calendar_today_outlined,
          label: preset >= 0
              ? 'Período · ${presets[preset]} días'
              : 'Período · $rangeLabel',
          active: true,
          enabled: !_loading,
          menuChildren: [
            for (final (i, days) in presets.indexed)
              FilterMenuOption(
                label: 'Últimos $days días',
                selected: preset == i,
                onPressed: () {
                  _presetDays(days);
                  _load();
                },
              ),
            const Divider(height: 8),
            FilterMenuOption(
              label:
                  preset < 0 ? 'Personalizado · $rangeLabel' : 'Personalizado…',
              icon: Icons.date_range_outlined,
              selected: preset < 0,
              onPressed: _pickRange,
            ),
          ],
        ),
        FilterPillButton(
          icon: Icons.tune,
          label: _activeFilterCount == 0
              ? 'Filtros'
              : 'Filtros ($_activeFilterCount)',
          active: _activeFilterCount > 0,
          showChevron: false,
          onTap: _showAdvancedFiltersSheet,
        ),
        ..._activeFilterChips(),
        if (_activeFilterCount > 0)
          TextButton(
            onPressed: _clearAllFilters,
            child: const Text('Limpiar'),
          ),
      ],
    );
  }

  Future<void> _pickRange() async {
    final from = _desde;
    final to = _hasta;
    await _pickDesde();
    if (!mounted) return;
    await _pickHasta();
    if (!mounted) return;
    if (_desde != from || _hasta != to) _load();
  }

  Future<void> _pickDesde() async {
    final d = await showAppDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Desde',
    );
    if (d != null) setState(() => _desde = d);
  }

  Future<void> _pickHasta() async {
    final d = await showAppDatePicker(
      context: context,
      initialDate: _hasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Hasta',
    );
    if (d != null) setState(() => _hasta = d);
  }

  int get _presetDayIndex {
    final end = DateTime(_hasta.year, _hasta.month, _hasta.day);
    final start = DateTime(_desde.year, _desde.month, _desde.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    if (end != todayDay) return -1;
    return const [30, 90, 365].indexOf(end.difference(start).inDays);
  }

  void _presetDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    setState(() {
      _hasta = end;
      _desde = end.subtract(Duration(days: days));
    });
  }

  EncomiendasReportExportMeta _exportMeta() {
    final lines = <String>[];
    if (_statusSelection.isNotEmpty) {
      final labels =
          _statusSelection.map(TransactionRequestStatus.labelEs).join(', ');
      lines.add('Estados: $labels');
    } else {
      lines.add('Estados: todos');
    }
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
    if (_soloConValoracion)
      lines.add('Solo con valoración de la tienda minorista');
    if (_soloPagosAprobados) lines.add('Solo pagos aprobados');
    if (_soloEntregados) lines.add('Solo entregados');
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
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final result = await saveExcelForExport(
        name: 'motolink_encomiendas_$stamp',
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

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    if (_statusSelection.isNotEmpty) {
      for (final s in _statusSelection) {
        chips.add(
          Chip(
            label: Text(TransactionRequestStatus.labelEs(s)),
            visualDensity: VisualDensity.compact,
          ),
        );
      }
    }
    if (_ownerId != null) {
      final name = _importers
          .where((o) => o.id == _ownerId)
          .map((o) => o.businessName)
          .firstOrNull;
      chips.add(
        Chip(
          label: Text(name ?? 'Importador'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (_docPrefFilter != 'all') {
      final label = _docOptions
          .where((o) => o.value == _docPrefFilter)
          .map((o) => o.label)
          .firstOrNull;
      if (label != null) {
        chips.add(
            Chip(label: Text(label), visualDensity: VisualDensity.compact));
      }
    }
    if (_soloConValoracion) {
      chips.add(const Chip(
        label: Text('Con valoración'),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (_soloPagosAprobados) {
      chips.add(const Chip(
        label: Text('Pago aprobado'),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (_soloEntregados) {
      chips.add(const Chip(
        label: Text('Solo entregados'),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (_topSoldLimit != null) {
      chips.add(Chip(
        label: Text('Top ${_topSoldLimit!} más vendidos'),
        visualDensity: VisualDensity.compact,
      ));
    }
    return chips;
  }

  Widget _topSoldProductsSection() {
    final ranking = _productSalesRanking;
    if (ranking.isEmpty) {
      return Text(
        'Sin ventas en el período con los filtros actuales.',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      );
    }

    final displayLimit = _topSoldLimit ?? 10;
    final shown = ranking.take(displayLimit).toList();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.divider),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: i < 3
                      ? AppColors.brandAccent.withOpacity(0.18)
                      : AppColors.surfaceTinted,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: i < 3
                          ? AppColors.brandAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                title: Text(
                  shown[i].productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  [
                    if ((shown[i].productSku ?? '').isNotEmpty)
                      'SKU ${shown[i].productSku}',
                    if ((shown[i].importerName ?? '').isNotEmpty)
                      shown[i].importerName!,
                  ].join(' · '),
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${shown[i].unitsSold} uds.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${shown[i].totalRefUsd.toStringAsFixed(2)} REF',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
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
    final list = _filtered;
    if (list.isEmpty) {
      return Text(
        'Sin resultados con los filtros actuales.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }
    final totalUsd = list.fold<double>(0, (s, r) => s + r.precioTotal);
    final conFacturaImportador =
        list.where((r) => r.hasProveedorFactura).length;
    final pagosAprobados = list
        .where(
            (r) => r.pagoEstadoRevision?.trim() == PagoRevisionEstado.aprobado)
        .length;
    final prefNota = list
        .where((r) =>
            r.documentTypePreference == DocumentTypePreference.notaEntrega)
        .length;
    final prefFiscal = list
        .where((r) =>
            r.documentTypePreference == DocumentTypePreference.facturaFiscal)
        .length;
    final prefPend = list
        .where(
          (r) =>
              r.documentTypePreference == null ||
              r.documentTypePreference!.trim().isEmpty,
        )
        .length;
    final valorados =
        list.where((r) => r.aliadoExperienceSubmittedAt != null).toList();
    double? avgStars;
    if (valorados.isNotEmpty) {
      final sum =
          valorados.fold<int>(0, (s, r) => s + (r.aliadoExperienceStars ?? 0));
      avgStars = sum / valorados.length;
    }
    final entregados = list
        .where((r) => r.status == TransactionRequestStatus.entregado)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(
              title: 'Pedidos',
              value: '${list.length}',
              icon: Icons.inventory_2_outlined,
            ),
            _StatCard(
              title: 'Total REF',
              value: totalUsd.toStringAsFixed(2),
              icon: Icons.payments_outlined,
            ),
            _StatCard(
              title: 'Con factura',
              value: '$conFacturaImportador',
              icon: Icons.receipt_long_outlined,
            ),
            _StatCard(
              title: 'Pagos OK',
              value: '$pagosAprobados',
              icon: Icons.verified_outlined,
            ),
            _StatCard(
              title: 'Entregados',
              value: '$entregados',
              icon: Icons.done_all_outlined,
            ),
            _StatCard(
              title: 'Nota / Fiscal / Pend.',
              value: '$prefNota / $prefFiscal / $prefPend',
              icon: Icons.description_outlined,
            ),
            _StatCard(
              title: 'Valoraciones',
              value: valorados.isEmpty
                  ? '—'
                  : '${valorados.length} · ${avgStars!.toStringAsFixed(2)} ★',
              icon: Icons.star_outline,
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionSwitcher() {
    return SegmentedFilterBar(
      labels: const [
        'Pedidos',
        'Promos',
        'Usuarios',
        'Referidos',
        'Devoluciones',
      ],
      selectedIndex: _sectionIndex,
      onSelected: (index) => setState(() => _sectionIndex = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sectionIndex == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _sectionSwitcher(),
          ),
          const Expanded(child: AdminPromoCampaignsPanel()),
        ],
      );
    }

    if (_sectionIndex == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _sectionSwitcher(),
          ),
          Expanded(
            child: AdminUserMonitoringPanel(
              presenceRequest:
                  MainShellTabController.adminPresenceRequest.value,
            ),
          ),
        ],
      );
    }

    if (_sectionIndex == 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _sectionSwitcher(),
          ),
          const Expanded(child: AdminReferralsPanel()),
        ],
      );
    }

    if (_sectionIndex == 4) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _sectionSwitcher(),
          ),
          const Expanded(child: AdminReturnsReportPanel()),
        ],
      );
    }

    if (_error != null && _raw.isEmpty && !_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _sectionSwitcher(),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                        onPressed: _load, child: const Text('Reintentar')),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _sectionSwitcher(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: Builder(
              builder: (context) {
                final mobile = MediaQuery.sizeOf(context).width < 600;
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, mobile ? 8 : 0, 16, 24),
                  children: [
                    _buildCompactFiltersCard(),
                    const SizedBox(height: 10),
                    const AdminCatalogFeaturedSection(),
                    const SizedBox(height: 10),
                    Material(
                      color: AppColors.surfaceTinted,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.table_chart_outlined,
                                  size: 20,
                                  color: AppColors.brandAccent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _filtered.isEmpty
                                        ? 'Sin datos'
                                        : '${_filtered.length} para Excel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (!mobile)
                                  Text(
                                    'Encomiendas + ranking',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed:
                                  (_filtered.isEmpty || _exporting || _loading)
                                      ? null
                                      : _exportExcel,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_outlined),
                              label: Text(
                                _exporting
                                    ? 'Generando…'
                                    : (mobile
                                        ? 'Descargar Excel'
                                        : 'Descargar Excel (.xlsx)'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.insights_outlined,
                          size: 18,
                          color: AppColors.brandAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mobile ? 'Resumen' : 'Resumen gerencial',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: mobile ? 14 : 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _summary(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 18,
                          color: AppColors.brandAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            mobile ? 'Top ventas' : 'Productos más vendidos',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: mobile ? 14 : 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (_topSoldLimit != null)
                          Text(
                            'Top $_topSoldLimit',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _topSoldProductsSection(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.list_alt_outlined,
                          size: 18,
                          color: AppColors.brandAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Detalle',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: mobile ? 14 : 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${_filtered.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_filtered.isEmpty && _loading)
                      const SizedBox(
                        height: 320,
                        child: AdminListSkeleton(
                          itemCount: 4,
                          padding: EdgeInsets.zero,
                        ),
                      )
                    else if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      PagedItems<TransactionRequestModel>(
                        items: _filtered,
                        itemKey: (r) => r.id,
                        embedded: true,
                        separator: 8,
                        itemBuilder: _detailTile,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String? _pagoEstadoLabel(TransactionRequestModel r) {
    final pe = r.pagoEstadoRevision?.trim();
    if (pe == null || pe.isEmpty) return null;
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pago pendiente';
      case PagoRevisionEstado.enRevision:
        return 'Pago en revisión';
      case PagoRevisionEstado.aprobado:
        return 'Pago aprobado';
      case PagoRevisionEstado.rechazado:
        return 'Pago rechazado';
      default:
        return pe;
    }
  }

  String? _pagoMetodoLabel(TransactionRequestModel r) {
    final m = r.pagoMetodo?.trim();
    if (m == null || m.isEmpty) return null;
    return PagoMetodo.labelEs(m);
  }

  Widget _detailTile(TransactionRequestModel r) {
    final doc = r.documentTypePreference?.trim();
    final docLabel = doc == null || doc.isEmpty
        ? 'Pendiente'
        : (DocumentTypePreference.labelEs(doc) ?? doc);
    final stars = r.aliadoExperienceStars;
    final hasRating = r.aliadoExperienceSubmittedAt != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    r.productName ?? 'Producto',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(label: TransactionRequestStatus.labelEs(r.status)),
              ],
            ),
            if ((r.productSku ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'SKU ${r.productSku!.trim()}',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${formatEsShortDateTime(r.createdAt)} · '
              '${r.precioTotal.toStringAsFixed(2)} REF · ${r.cantidad} uds.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${r.aliadoBusinessName ?? "Tienda minorista"} → ${r.ownerBusinessName ?? "Importador"}',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniChip(
                  icon: Icons.description_outlined,
                  label: docLabel,
                ),
                _MiniChip(
                  icon: Icons.receipt_long_outlined,
                  label: r.hasProveedorFactura
                      ? 'Factura importador'
                      : 'Sin factura importador',
                  highlighted: r.hasProveedorFactura,
                ),
                if (_pagoEstadoLabel(r) != null)
                  _MiniChip(
                    icon: Icons.payments_outlined,
                    label: _pagoEstadoLabel(r)!,
                    highlighted: r.pagoEstadoRevision?.trim() ==
                        PagoRevisionEstado.aprobado,
                  ),
                if (_pagoMetodoLabel(r) != null)
                  _MiniChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: _pagoMetodoLabel(r)!,
                  ),
                if (hasRating)
                  _MiniChip(
                    icon: Icons.star_rounded,
                    label: '${stars ?? 0}/5',
                    highlighted: true,
                  ),
              ],
            ),
            if ((r.aliadoExperienceComment ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '“${r.aliadoExperienceComment!.trim()}”',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.brandBlue.withOpacity(0.95),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.brandAccent : AppColors.textPrimary;
    final bg =
        highlighted ? AppColors.brandBlueContainer : AppColors.surfaceTinted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.brandBlue),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocOpt {
  const _DocOpt(this.value, this.label);
  final String value;
  final String label;
}

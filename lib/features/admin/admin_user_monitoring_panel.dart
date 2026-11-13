import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';

import 'activity_metrics_grid.dart';
import 'admin_catalog_coverage.dart';
import 'admin_user_presence_section.dart';
import 'user_presence.dart';
import 'admin_published_catalogs_section.dart';
import 'admin_user_activity_row_model.dart';
import 'admin_users_chrome.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

enum _ActivityPeriod { day, week }

enum _ActivityRoleFilter { all, aliado, importador }

enum _CatalogListFilter { todos, publicados, sinCatalogo }


/// Admin: monitoreo de ingresos y pedidos por aliado/importador.
class AdminUserMonitoringPanel extends StatefulWidget {
  const AdminUserMonitoringPanel({
    super.key,
    this.loadRows,
    this.loadCatalogCoverage,
    this.loadPresence,
    this.presenceRequest = 0,
    this.showCatalogCoverage = true,
  });

  /// Al cambiar (y ser > 0) abre la presencia con el período «hoy».
  final int presenceRequest;

  /// Incluye métrica y modo Catálogos (Presencia / Reportes).
  final bool showCatalogCoverage;

  final Future<List<AdminUserActivityRowModel>> Function({
    String? role,
    required String period,
  })? loadRows;
  final Future<AdminCatalogCoverage> Function()? loadCatalogCoverage;
  final Future<List<AdminUserPresenceRow>> Function()? loadPresence;

  @override
  State<AdminUserMonitoringPanel> createState() =>
      _AdminUserMonitoringPanelState();
}

class _AdminUserMonitoringPanelState extends State<AdminUserMonitoringPanel> {
  List<AdminUserActivityRowModel> _rows = const [];
  bool _loading = true;
  String? _error;
  _ActivityPeriod _period = _ActivityPeriod.week;
  _ActivityRoleFilter _roleFilter = _ActivityRoleFilter.all;
  final _searchCtrl = TextEditingController();
  final _listScroll = ScrollController();
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;
  ActivityMetricFocus _metricFocus = ActivityMetricFocus.none;
  AdminCatalogCoverage? _coverage;
  bool _coverageLoading = true;
  bool _showingCatalogs = false;
  bool _presenceOpen = false;
  _CatalogListFilter _catalogFilter = _CatalogListFilter.todos;
  final _catalogSearchCtrl = TextEditingController();
  int _catalogPageIndex = 0;
  int _catalogPageSize = listPageSizeOptions.first;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _pageIndex = 0));
    _catalogSearchCtrl.addListener(() {
      setState(() => _catalogPageIndex = 0);
    });
    if (widget.presenceRequest > 0) {
      _presenceOpen = true;
      _period = _ActivityPeriod.day;
    }
    _load();
    if (widget.showCatalogCoverage) _loadCoverage();
  }

  @override
  void didUpdateWidget(covariant AdminUserMonitoringPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.presenceRequest == oldWidget.presenceRequest ||
        widget.presenceRequest <= 0) {
      return;
    }
    final reload = _period != _ActivityPeriod.day;
    setState(() {
      _presenceOpen = true;
      _showingCatalogs = false;
      _period = _ActivityPeriod.day;
      _pageIndex = 0;
    });
    if (reload) _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _catalogSearchCtrl.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final period = _period == _ActivityPeriod.day ? 'day' : 'week';
      final role = switch (_roleFilter) {
        _ActivityRoleFilter.all => null,
        _ActivityRoleFilter.aliado => 'aliado',
        _ActivityRoleFilter.importador => 'importador',
      };
      final customRows = widget.loadRows;
      final rows = customRows != null
          ? await customRows(role: role, period: period)
          : await SupabaseService.listAdminUserActivityMonitoring(
              role: role,
              period: period,
            );
      if (!mounted) return;
      setState(() {
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

  Future<void> _refreshAll() async {
    await _load();
    if (widget.showCatalogCoverage) await _loadCoverage();
  }

  List<AdminUserActivityRowModel> get _filtered {
    var list = _rows;
    switch (_metricFocus) {
      case ActivityMetricFocus.withLogins:
        list = list.where((r) => r.loginCountPeriod > 0).toList();
      case ActivityMetricFocus.withOrders:
        list = list.where((r) => r.ordersCountPeriod > 0).toList();
      case ActivityMetricFocus.withDelivered:
        list = list.where((r) => r.ordersDeliveredPeriod > 0).toList();
      case ActivityMetricFocus.withVolume:
        list = list.where((r) => r.ordersVolumeUsdPeriod > 0).toList();
      case ActivityMetricFocus.users:
      case ActivityMetricFocus.catalogs:
      case ActivityMetricFocus.none:
        break;
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((r) {
      final name = (r.businessName ?? '').toLowerCase();
      final rif = (r.rif ?? '').toLowerCase();
      final city = (r.ciudad ?? '').toLowerCase();
      final state = (r.estado ?? '').toLowerCase();
      return name.contains(q) ||
          rif.contains(q) ||
          city.contains(q) ||
          state.contains(q);
    }).toList();
  }

  void _onMetricFocus(ActivityMetricFocus focus) {
    if (focus == ActivityMetricFocus.catalogs) {
      if (_coverage == null && !_coverageLoading) {
        unawaited(_loadCoverage());
      }
      setState(() {
        _showingCatalogs = true;
        _catalogFilter = _CatalogListFilter.todos;
        _catalogSearchCtrl.clear();
        _catalogPageIndex = 0;
        _presenceOpen = false;
        _metricFocus = ActivityMetricFocus.catalogs;
      });
      return;
    }
    setState(() {
      _showingCatalogs = false;
      _metricFocus = focus;
      _pageIndex = 0;
      if (focus != ActivityMetricFocus.none) _presenceOpen = false;
    });
  }

  String get _periodLabel =>
      _period == _ActivityPeriod.day ? 'hoy' : 'últimos 7 días';

  Future<void> _loadCoverage() async {
    setState(() => _coverageLoading = true);
    try {
      final custom = widget.loadCatalogCoverage;
      final coverage = custom != null
          ? await custom()
          : await _fetchCatalogCoverage();
      if (!mounted) return;
      setState(() {
        _coverage = coverage;
        _coverageLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _coverageLoading = false);
    }
  }

  Future<AdminCatalogCoverage> _fetchCatalogCoverage() async {
    final results = await Future.wait<Object>([
      SupabaseService.fetchImporterOptions(),
      SupabaseService.fetchPublishedCatalogOwnerIds(),
    ]);
    return splitImportersByPublishedCatalog(
      importers: results[0] as List<ImporterOption>,
      publishedOwnerIds: results[1] as Set<String>,
    );
  }

  void _setPeriod(_ActivityPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _pageIndex = 0;
    });
    _load();
  }

  void _setRole(_ActivityRoleFilter role) {
    if (_roleFilter == role) return;
    setState(() {
      _roleFilter = role;
      _pageIndex = 0;
    });
    _load();
  }

  void _openImporterCatalog(ImporterOption importer) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = B2BThemeExtension.of(ctx);
        final size = MediaQuery.sizeOf(ctx);
        final width = size.width >= 1008 ? 960.0 : size.width - 48;
        return Dialog(
          backgroundColor: theme.dialogSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.border),
          ),
          child: SizedBox(
            width: width < 280 ? 280 : width,
            height: size.height * 0.82,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AdminPublishedCatalogsSection(
                focusImporter: importer,
                onCloseFocus: () => Navigator.pop(ctx),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showCatalogCoverage && _showingCatalogs) {
      return _catalogLists();
    }

    final theme = B2BThemeExtension.of(context);
    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final totalUsers = _rows.length;
    final totalLogins = _rows.fold<int>(0, (s, r) => s + r.loginCountPeriod);
    final totalOrders = _rows.fold<int>(0, (s, r) => s + r.ordersCountPeriod);
    final totalDelivered =
        _rows.fold<int>(0, (s, r) => s + r.ordersDeliveredPeriod);
    final totalVolume = _rows.fold<double>(
      0,
      (s, r) => s + r.ordersVolumeUsdPeriod,
    );

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AdminUsersChrome.brand,
      child: ListView(
        controller: _listScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AdminUsersChrome.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            B2bDataTableFilterPill(
                              label: 'Hoy',
                              selected: _period == _ActivityPeriod.day,
                              glyph: LucideGlyph.activity,
                              onTap: () => _setPeriod(_ActivityPeriod.day),
                            ),
                            const SizedBox(width: 6),
                            B2bDataTableFilterPill(
                              label: 'Semana',
                              selected: _period == _ActivityPeriod.week,
                              glyph: LucideGlyph.activity,
                              onTap: () => _setPeriod(_ActivityPeriod.week),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 22,
                              color: theme.borderSubtle,
                            ),
                            const SizedBox(width: 10),
                            B2bDataTableFilterPill(
                              label: 'Todos',
                              selected: _roleFilter == _ActivityRoleFilter.all,
                              glyph: LucideGlyph.users,
                              onTap: () => _setRole(_ActivityRoleFilter.all),
                            ),
                            const SizedBox(width: 6),
                            B2bDataTableFilterPill(
                              label: 'Minorista',
                              selected:
                                  _roleFilter == _ActivityRoleFilter.aliado,
                              glyph: LucideGlyph.userRound,
                              onTap: () => _setRole(_ActivityRoleFilter.aliado),
                            ),
                            const SizedBox(width: 6),
                            B2bDataTableFilterPill(
                              label: 'Mayorista',
                              selected: _roleFilter ==
                                  _ActivityRoleFilter.importador,
                              glyph: LucideGlyph.store,
                              onTap: () =>
                                  _setRole(_ActivityRoleFilter.importador),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Actualizar',
                      visualDensity: VisualDensity.compact,
                      onPressed: _loading ? null : _refreshAll,
                      icon: LucideIcon(
                        LucideGlyph.refreshCw,
                        size: 16,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  users: totalUsers,
                  logins: totalLogins,
                  orders: totalOrders,
                  delivered: totalDelivered,
                  volumeUsd: totalVolume,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _activityTable(filtered, page),
        ],
      ),
    );
  }

  Widget _activityTable(
    List<AdminUserActivityRowModel> filtered,
    List<AdminUserActivityRowModel> page,
  ) {
    final theme = B2BThemeExtension.of(context);
    final loadingEmpty = _loading && _rows.isEmpty;
    final errorEmpty = _error != null && _rows.isEmpty;
    final noMatches = !loadingEmpty && !errorEmpty && filtered.isEmpty;

    return B2bDataTableShell(
      toolbar: B2bDataTableToolbar(
        searchController: _searchCtrl,
        searchHint: 'Nombre, RIF o ubicación…',
      ),
      header: const B2bDataTableHeader(
        cells: [
          B2bDataTableHeaderCell(label: 'Cuenta', flex: 4),
          B2bDataTableHeaderCell(label: 'Rol', flex: 2),
          B2bDataTableHeaderCell(label: 'Actividad', flex: 4),
          B2bDataTableHeaderCell(label: 'Último acceso', flex: 3),
        ],
      ),
      rows: loadingEmpty || errorEmpty || noMatches
          ? const <Widget>[]
          : [
              for (var i = 0; i < page.length; i++)
                _UserActivityRow(
                  row: page[i],
                  zebra: i.isOdd,
                  isLast: i == page.length - 1,
                ),
            ],
      empty: loadingEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : errorEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brand,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Ningún usuario coincide con los filtros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
      footer: loadingEmpty || errorEmpty
          ? null
          : ListPageBar(
              total: filtered.length,
              pageIndex: _pageIndex,
              pageSize: _pageSize,
              alwaysShow: filtered.isNotEmpty,
              entityLabel: 'cuentas',
              onPageIndex: (index) => setState(() => _pageIndex = index),
              onPageSize: (size) => setState(() {
                _pageSize = size;
                _pageIndex = 0;
              }),
            ),
    );
  }

  Widget _summaryRow({
    required int users,
    required int logins,
    required int orders,
    required int delivered,
    required double volumeUsd,
  }) {
    final theme = B2BThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityMetricsGrid(
          users: users,
          logins: logins,
          orders: orders,
          delivered: delivered,
          volumeUsd: volumeUsd,
          periodLabel: _periodLabel,
          focus: _metricFocus,
          onFocusChanged: _onMetricFocus,
          showCatalogs: widget.showCatalogCoverage,
          catalogsLoading: _coverageLoading,
          catalogsCount: _coverage?.published.length,
        ),
        if (_presenceOpen) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.brand),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: AdminUserPresenceSection(
                loadRows: widget.loadPresence,
                onlyLoggedInToday: true,
                loadTodayLogins: () {
                  final custom = widget.loadRows;
                  if (custom != null) {
                    return custom(role: null, period: 'day');
                  }
                  return SupabaseService.listAdminUserActivityMonitoring(
                    period: 'day',
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<({ImporterOption importer, bool published})> get _catalogRows {
    final coverage = _coverage ?? AdminCatalogCoverage.empty;
    final q = _catalogSearchCtrl.text.trim().toLowerCase();
    bool matches(ImporterOption i) {
      if (q.isEmpty) return true;
      final name = i.businessName.toLowerCase();
      final estado = (i.estado ?? '').toLowerCase();
      final ciudad = (i.ciudad ?? '').toLowerCase();
      return name.contains(q) || estado.contains(q) || ciudad.contains(q);
    }

    final rows = <({ImporterOption importer, bool published})>[];
    if (_catalogFilter != _CatalogListFilter.sinCatalogo) {
      for (final i in coverage.published) {
        if (matches(i)) rows.add((importer: i, published: true));
      }
    }
    if (_catalogFilter != _CatalogListFilter.publicados) {
      for (final i in coverage.withoutCatalog) {
        if (matches(i)) rows.add((importer: i, published: false));
      }
    }
    rows.sort(
      (a, b) => a.importer.businessName
          .toLowerCase()
          .compareTo(b.importer.businessName.toLowerCase()),
    );
    return rows;
  }

  Widget _catalogLists() {
    final coverage = _coverage ?? AdminCatalogCoverage.empty;
    final rows = _catalogRows;
    final page = sliceListPage(
      items: rows,
      pageIndex: _catalogPageIndex,
      pageSize: _catalogPageSize,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DecoratedBox(
        decoration: AdminUsersChrome.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver a presencia',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _showingCatalogs = false;
                      _metricFocus = ActivityMetricFocus.none;
                    }),
                    icon: LucideIcon(
                      LucideGlyph.arrowLeft,
                      size: 18,
                      color: AdminUsersChrome.titleColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Catálogos publicados',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AdminUsersChrome.titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                'Mayoristas con y sin catálogo publicado.',
                style: TextStyle(fontSize: 12, color: AdminUsersChrome.muted),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                children: [
                  TextField(
                    controller: _catalogSearchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: AdminUsersChrome.field(
                      label: 'Buscar',
                      hint: 'Proveedor o ubicación…',
                    ).copyWith(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 10, right: 6),
                        child: LucideIcon(
                          LucideGlyph.search,
                          size: 16,
                          color: AdminUsersChrome.muted,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        B2bDataTableFilterPill(
                          label: 'Todos',
                          selected:
                              _catalogFilter == _CatalogListFilter.todos,
                          glyph: LucideGlyph.users,
                          onTap: () => setState(() {
                            _catalogFilter = _CatalogListFilter.todos;
                            _catalogPageIndex = 0;
                          }),
                        ),
                        const SizedBox(width: 6),
                        B2bDataTableFilterPill(
                          label:
                              'Publicados · ${coverage.published.length}',
                          selected: _catalogFilter ==
                              _CatalogListFilter.publicados,
                          glyph: LucideGlyph.store,
                          onTap: () => setState(() {
                            _catalogFilter = _CatalogListFilter.publicados;
                            _catalogPageIndex = 0;
                          }),
                        ),
                        const SizedBox(width: 6),
                        B2bDataTableFilterPill(
                          label:
                              'Sin catálogo · ${coverage.withoutCatalog.length}',
                          selected: _catalogFilter ==
                              _CatalogListFilter.sinCatalogo,
                          glyph: LucideGlyph.package,
                          onTap: () => setState(() {
                            _catalogFilter = _CatalogListFilter.sinCatalogo;
                            _catalogPageIndex = 0;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Ningún proveedor coincide con la búsqueda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminUsersChrome.muted,
                        ),
                      ),
                    )
                  else ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: AdminUsersChrome.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const B2bDataTableHeader(
                            cells: [
                              B2bDataTableHeaderCell(
                                label: 'Mayorista',
                                flex: 4,
                              ),
                              B2bDataTableHeaderCell(
                                label: 'Ubicación',
                                flex: 2,
                              ),
                              B2bDataTableHeaderCell(
                                label: 'Estado',
                                flex: 2,
                              ),
                            ],
                          ),
                          for (var i = 0; i < page.length; i++)
                            _ImporterCatalogRow(
                              importer: page[i].importer,
                              published: page[i].published,
                              zebra: i.isOdd,
                              isLast: i == page.length - 1,
                              onOpenCatalog: page[i].published
                                  ? () => _openImporterCatalog(page[i].importer)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    ListPageBar(
                      total: rows.length,
                      pageIndex: _catalogPageIndex,
                      pageSize: _catalogPageSize,
                      alwaysShow: rows.isNotEmpty,
                      onPageIndex: (index) =>
                          setState(() => _catalogPageIndex = index),
                      onPageSize: (size) => setState(() {
                        _catalogPageSize = size;
                        _catalogPageIndex = 0;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImporterCatalogRow extends StatefulWidget {
  const _ImporterCatalogRow({
    required this.importer,
    required this.published,
    required this.zebra,
    required this.isLast,
    this.onOpenCatalog,
  });

  final ImporterOption importer;
  final bool published;
  final bool zebra;
  final bool isLast;
  final VoidCallback? onOpenCatalog;

  @override
  State<_ImporterCatalogRow> createState() => _ImporterCatalogRowState();
}

class _ImporterCatalogRowState extends State<_ImporterCatalogRow> {
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _resolveLogo();
  }

  @override
  void didUpdateWidget(covariant _ImporterCatalogRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.importer.logoStoragePath !=
        widget.importer.logoStoragePath) {
      _resolveLogo();
    }
  }

  Future<void> _resolveLogo() async {
    final path = widget.importer.logoStoragePath?.trim();
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _logoUrl = null);
      return;
    }
    try {
      final url = await SupabaseService.createSignedUrlForProfileLogo(path);
      if (mounted) setState(() => _logoUrl = url);
    } catch (_) {
      if (mounted) setState(() => _logoUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final name = widget.importer.businessName.trim().isEmpty
        ? 'Sin nombre comercial'
        : widget.importer.businessName.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    final location = widget.importer.ubicacionLine;

    final menu = B2bDataRowActionsMenu(
      actions: [
        B2bDataRowAction(
          id: 'open',
          label: widget.published ? 'Ver catálogo' : 'Sin catálogo publicado',
          glyph: LucideGlyph.store,
          enabled: widget.onOpenCatalog != null,
        ),
      ],
      onSelected: (_) => widget.onOpenCatalog?.call(),
    );

    return B2bDataTableZebraRow(
      zebra: widget.zebra,
      isLast: widget.isLast,
      onTap: widget.onOpenCatalog,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.brandContainer,
                  backgroundImage:
                      _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                  child: _logoUrl == null
                      ? Text(
                          initials.isEmpty ? '?' : initials,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: theme.brand,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              location,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: B2bDataStatusBadge(
                label: widget.published ? 'Publicado' : 'Sin catálogo',
                background:
                    widget.published ? theme.successBg : theme.surfaceSubtle,
                foreground:
                    widget.published ? theme.successFg : theme.textMuted,
              ),
            ),
          ),
          SizedBox(width: 48, child: menu),
        ],
      ),
    );
  }
}

class _UserActivityRow extends StatelessWidget {
  const _UserActivityRow({
    required this.row,
    required this.zebra,
    required this.isLast,
  });

  final AdminUserActivityRowModel row;
  final bool zebra;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final location = [
      if ((row.ciudad ?? '').trim().isNotEmpty) row.ciudad!.trim(),
      if ((row.estado ?? '').trim().isNotEmpty) row.estado!.trim(),
    ].join(', ');
    final title = row.businessName?.trim().isNotEmpty == true
        ? row.businessName!.trim()
        : 'Sin nombre comercial';
    final initials = title
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
    final rif = (row.rif ?? '').trim();
    final subtitle = [
      if (rif.isNotEmpty) rif,
      if (location.isNotEmpty) location,
    ].join(' · ');
    final role = _activityRoleStyle(row.role, theme);

    final menu = B2bDataRowActionsMenu(
      actions: [
        B2bDataRowAction(
          id: 'copy-name',
          label: 'Copiar nombre',
          glyph: LucideGlyph.user,
        ),
        B2bDataRowAction(
          id: 'copy-rif',
          label: 'Copiar RIF',
          glyph: LucideGlyph.copy,
          enabled: rif.isNotEmpty,
        ),
      ],
      onSelected: (id) {
        switch (id) {
          case 'copy-name':
            _copyValue(context, title, 'Nombre copiado');
          case 'copy-rif':
            _copyValue(context, rif, 'RIF copiado');
        }
      },
    );

    return B2bDataTableZebraRow(
      zebra: zebra,
      isLast: isLast,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.brandContainer,
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: B2bDataStatusBadge(
                label: role.label,
                background: role.background,
                foreground: role.foreground,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _ActivityKpiLine(row: row),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.lastLoginAt == null
                  ? 'Sin ingresos'
                  : 'Último ingreso: ${formatEsShortDateTime(row.lastLoginAt)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: theme.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 48, child: menu),
        ],
      ),
    );
  }
}

({String label, Color foreground, Color background}) _activityRoleStyle(
  String? role,
  B2BThemeExtension theme,
) {
  switch (role?.trim().toLowerCase()) {
    case 'importador':
      return (
        label: 'Importador',
        foreground: theme.brand,
        background: theme.brandContainer,
      );
    case 'aliado':
      return (
        label: 'Minorista',
        foreground: theme.successFg,
        background: theme.successBg,
      );
    case 'mayorista':
      return (
        label: 'Mayorista',
        foreground: theme.textPrimary,
        background: theme.surfaceSubtle,
      );
    default:
      return (
        label: ProfileRoleLabels.labelEs(role),
        foreground: theme.textSecondary,
        background: theme.surfaceSubtle,
      );
  }
}

class _ActivityKpiLine extends StatelessWidget {
  const _ActivityKpiLine({required this.row});

  final AdminUserActivityRowModel row;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final base = TextStyle(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: theme.textSecondary,
    );
    final strong = base.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.textPrimary,
    );

    TextSpan metric(String value, String label) {
      return TextSpan(
        children: [
          TextSpan(text: value, style: strong),
          TextSpan(text: ' $label'),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          metric('${row.loginCountPeriod}', 'Ingresos'),
          const TextSpan(text: ' • '),
          metric('${row.ordersCountPeriod}', row.ordersLabel),
          const TextSpan(text: ' • '),
          metric('${row.ordersDeliveredPeriod}', 'Entregados'),
          const TextSpan(text: ' • '),
          metric('${row.ordersInProgressPeriod}', 'En curso'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

void _copyValue(BuildContext context, String value, String message) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return;
  Clipboard.setData(ClipboardData(text: trimmed));
  final theme = B2BThemeExtension.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: theme.dialogSurface,
      content: Text(
        message,
        style: TextStyle(
          color: theme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

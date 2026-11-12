import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/accounts_table_skeleton.dart';
import 'package:motolink_pro_app/features/admin/admin_service.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

enum _SealAudienceFilter { todos, mayoristas, minoristas }

/// Usuarios › Sellos y Vitrina: Verificado / Destacado (mayoristas + minoristas).
class AdminCatalogSealsPanel extends StatefulWidget {
  const AdminCatalogSealsPanel({super.key});

  @override
  State<AdminCatalogSealsPanel> createState() => _AdminCatalogSealsPanelState();
}

class _AdminCatalogSealsPanelState extends State<AdminCatalogSealsPanel> {
  static const _windowOptions = <int>[7, 30];
  static const _featureDayOptions = <(int, String)>[
    (7, '7 días'),
    (30, '30 días'),
    (3650, 'Permanente'),
  ];

  final _searchCtrl = TextEditingController();
  List<_SealStoreRow> _rows = const [];
  bool _loading = true;
  String? _error;
  int _windowDays = 30;
  String? _busyId;
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;
  _SealAudienceFilter _audience = _SealAudienceFilter.todos;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _pageIndex = 0));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.adminListImporterSalesSnapshots(days: _windowDays),
        AdminService.ownerListProfilesWithDossier(),
      ]);
      final snapshots = results[0] as List<ImporterSalesSnapshot>;
      final profiles = results[1] as List<ProfileModel>;

      final byId = <String, _SealStoreRow>{};
      for (final s in snapshots) {
        final id = s.importadorId?.trim() ?? '';
        if (id.isEmpty) continue;
        byId[id] = _SealStoreRow.fromImporter(s);
      }
      for (final p in profiles) {
        if (p.id.isEmpty || p.isDeactivated) continue;
        if (p.isImportador) {
          final existing = byId[p.id];
          if (existing != null) {
            byId[p.id] = existing.mergeProfileSeals(p);
          } else {
            byId[p.id] = _SealStoreRow.fromProfile(p, isMinorista: false);
          }
        } else if (p.isAliado) {
          byId[p.id] = _SealStoreRow.fromProfile(p, isMinorista: true);
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = byId.values.toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar mayoristas y minoristas.';
        _loading = false;
      });
    }
  }

  List<_SealStoreRow> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _rows.where((e) {
      switch (_audience) {
        case _SealAudienceFilter.mayoristas:
          if (e.isMinorista) return false;
        case _SealAudienceFilter.minoristas:
          if (!e.isMinorista) return false;
        case _SealAudienceFilter.todos:
          break;
      }
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          (e.email?.toLowerCase().contains(q) ?? false);
    }).toList();
    list.sort((a, b) {
      final af = a.isCatalogFeatured ? 1 : 0;
      final bf = b.isCatalogFeatured ? 1 : 0;
      if (af != bf) return bf.compareTo(af);
      final av = a.isCatalogVerified ? 1 : 0;
      final bv = b.isCatalogVerified ? 1 : 0;
      if (av != bv) return bv.compareTo(av);
      if (a.isMinorista != b.isMinorista) {
        return a.isMinorista ? 1 : -1;
      }
      return b.unitsSold.compareTo(a.unitsSold);
    });
    return list;
  }

  int get _featuredMayoristas => _rows
      .where((e) => !e.isMinorista && e.isCatalogFeatured)
      .length;

  Future<void> _setFeaturedDays(_SealStoreRow row, int days) async {
    if (row.id.isEmpty || _busyId != null) return;
    setState(() => _busyId = row.id);
    try {
      await SupabaseService.adminSetImporterCatalogFeatured(
        importadorId: row.id,
        days: days,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final label = days == 0
          ? 'Se quitó el sello Destacado de ${row.name}.'
          : days >= 3650
              ? '${row.name} marcado como Destacado permanente.'
              : '${row.name} marcado como Destacado por $days días.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('featured_limit')
          ? 'Solo se pueden destacar 3 mayoristas a la vez.'
          : 'No se pudo actualizar el sello Destacado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _setVerified(_SealStoreRow row, bool verified) async {
    if (row.id.isEmpty || _busyId != null) return;
    setState(() => _busyId = row.id);
    try {
      await SupabaseService.adminSetImporterCatalogVerified(
        importadorId: row.id,
        verified: verified,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? '${row.name} marcado como Verificado.'
                : 'Se quitó el sello Verificado de ${row.name}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      final msg = raw.contains('importador no válido') ||
              raw.contains('perfil no válido') ||
              raw.contains('p0002')
          ? (row.isMinorista
              ? 'No se pudo marcar Verificado: la base aún no admite sellos para minoristas. Aplique la migración de sellos aliado.'
              : 'No se pudo marcar Verificado: perfil de mayorista no válido.')
          : 'No se pudo actualizar el sello Verificado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _pickFeaturedDuration(_SealStoreRow row) async {
    if (!row.isMinorista &&
        _featuredMayoristas >= 3 &&
        !row.isCatalogFeatured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya hay 3 mayoristas Destacados. Quite uno para sumar otro.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final theme = B2BThemeExtension.of(context);
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.dialogSurface,
      builder: (ctx) {
        final t = B2BThemeExtension.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Destacar ${row.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  row.isMinorista
                      ? 'Sello Destacado para la tienda minorista.'
                      : 'Sello dorado por alto volumen. Sube sus productos al inicio del catálogo.',
                  style: TextStyle(fontSize: 12.5, color: t.textSecondary),
                ),
                const SizedBox(height: 14),
                for (final opt in _featureDayOptions) ...[
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(ctx, opt.$1),
                    child: Text(opt.$2),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (days != null) await _setFeaturedDays(row, days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AdminUsersChrome.sectionHeader(
          title: 'Sellos y Vitrina',
          subtitle:
              'Gestiona Verificado y Destacado de mayoristas y tiendas minoristas.',
          glyph: LucideGlyph.shieldCheck,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CompactFilterPill(
                label: 'Todos',
                selected: _audience == _SealAudienceFilter.todos,
                onTap: () => setState(() {
                  _audience = _SealAudienceFilter.todos;
                  _pageIndex = 0;
                }),
              ),
              const SizedBox(width: 8),
              _CompactFilterPill(
                label: 'Mayoristas',
                selected: _audience == _SealAudienceFilter.mayoristas,
                onTap: () => setState(() {
                  _audience = _SealAudienceFilter.mayoristas;
                  _pageIndex = 0;
                }),
              ),
              const SizedBox(width: 8),
              _CompactFilterPill(
                label: 'Minoristas',
                selected: _audience == _SealAudienceFilter.minoristas,
                onTap: () => setState(() {
                  _audience = _SealAudienceFilter.minoristas;
                  _pageIndex = 0;
                }),
              ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: theme.border,
              ),
              for (var i = 0; i < _windowOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _CompactFilterPill(
                  label: '${_windowOptions[i]} días',
                  selected: _windowDays == _windowOptions[i],
                  onTap: () {
                    final days = _windowOptions[i];
                    if (_windowDays == days) return;
                    setState(() {
                      _windowDays = days;
                      _pageIndex = 0;
                    });
                    _load();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderStrong),
            boxShadow: [
              BoxShadow(
                color: theme.textPrimary.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.04,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 640;
                  final search = TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar mayorista o minorista…',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: LucideIcon(
                          LucideGlyph.search,
                          size: 18,
                          color: theme.textSecondary,
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      filled: true,
                      fillColor: theme.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderStrong),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.brand, width: 1.4),
                      ),
                    ),
                  );
                  final meta = Text(
                    '${filtered.length} cuenta${filtered.length == 1 ? '' : 's'} · '
                    '$_featuredMayoristas mayorista${_featuredMayoristas == 1 ? '' : 's'} destacado${_featuredMayoristas == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  );
                  final refresh = IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _load,
                    icon: LucideIcon(
                      LucideGlyph.refreshCw,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: meta),
                            refresh,
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      meta,
                      refresh,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (_loading)
                const AccountsTableSkeleton(compact: false)
              else if (_error != null && _rows.isEmpty)
                _ErrorBox(
                  theme: theme,
                  message: _error!,
                  onRetry: _load,
                )
              else ...[
                _Header(theme: theme),
                if (page.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Text(
                      _searchCtrl.text.trim().isEmpty
                          ? 'No hay cuentas en este filtro.'
                          : 'Ninguna cuenta coincide con la búsqueda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < page.length; i++)
                    _SealRow(
                      theme: theme,
                      row: page[i],
                      zebra: i.isOdd,
                      busy: _busyId == page[i].id,
                      onToggleVerified: () =>
                          _setVerified(page[i], !page[i].isCatalogVerified),
                      onFeature: () => _pickFeaturedDuration(page[i]),
                      onUnfeature: page[i].isCatalogFeatured
                          ? () => _setFeaturedDays(page[i], 0)
                          : null,
                    ),
                ListPageBar(
                  total: filtered.length,
                  pageIndex: _pageIndex,
                  pageSize: _pageSize,
                  alwaysShow: filtered.isNotEmpty,
                  onPageIndex: (index) => setState(() => _pageIndex = index),
                  onPageSize: (size) => setState(() {
                    _pageSize = size;
                    _pageIndex = 0;
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SealStoreRow {
  const _SealStoreRow({
    required this.id,
    required this.name,
    required this.isMinorista,
    this.email,
    this.catalogFeaturedUntil,
    this.catalogVerifiedAt,
    this.unitsSold = 0,
    this.revenueRef = 0,
    this.ordersEntregados = 0,
    this.productsPaused = 0,
  });

  final String id;
  final String name;
  final bool isMinorista;
  final String? email;
  final DateTime? catalogFeaturedUntil;
  final DateTime? catalogVerifiedAt;
  final int unitsSold;
  final double revenueRef;
  final int ordersEntregados;
  final int productsPaused;

  bool get isCatalogFeatured {
    final until = catalogFeaturedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get isCatalogVerified => catalogVerifiedAt != null;

  factory _SealStoreRow.fromImporter(ImporterSalesSnapshot s) {
    final name = (s.businessName ?? '').trim();
    return _SealStoreRow(
      id: s.importadorId?.trim() ?? '',
      name: name.isEmpty ? 'Mayorista' : name,
      isMinorista: false,
      catalogFeaturedUntil: s.catalogFeaturedUntil,
      catalogVerifiedAt: s.catalogVerifiedAt,
      unitsSold: s.unitsSold,
      revenueRef: s.revenueRef,
      ordersEntregados: s.ordersEntregados,
      productsPaused: s.productsPaused,
    );
  }

  factory _SealStoreRow.fromProfile(
    ProfileModel p, {
    required bool isMinorista,
  }) {
    final name = (p.businessName ?? '').trim();
    return _SealStoreRow(
      id: p.id,
      name: name.isEmpty
          ? (isMinorista ? 'Tienda minorista' : 'Mayorista')
          : name,
      isMinorista: isMinorista,
      email: p.email,
      catalogFeaturedUntil: p.catalogFeaturedUntil,
      catalogVerifiedAt: p.catalogVerifiedAt,
    );
  }

  _SealStoreRow mergeProfileSeals(ProfileModel p) {
    return _SealStoreRow(
      id: id,
      name: name,
      isMinorista: false,
      email: p.email ?? email,
      catalogFeaturedUntil: p.catalogFeaturedUntil ?? catalogFeaturedUntil,
      catalogVerifiedAt: p.catalogVerifiedAt ?? catalogVerifiedAt,
      unitsSold: unitsSold,
      revenueRef: revenueRef,
      ordersEntregados: ordersEntregados,
      productsPaused: productsPaused,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final B2BThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    TextStyle headStyle() => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.textSecondary,
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.tableHeaderBg,
        border: Border(
          top: BorderSide(color: theme.borderSubtle),
          bottom: BorderSide(color: theme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Cuenta', style: headStyle())),
          Expanded(flex: 2, child: Text('Detalle', style: headStyle())),
          Expanded(flex: 2, child: Text('Sellos', style: headStyle())),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SealRow extends StatelessWidget {
  const _SealRow({
    required this.theme,
    required this.row,
    required this.zebra,
    required this.busy,
    required this.onToggleVerified,
    required this.onFeature,
    this.onUnfeature,
  });

  final B2BThemeExtension theme;
  final _SealStoreRow row;
  final bool zebra;
  final bool busy;
  final VoidCallback onToggleVerified;
  final VoidCallback onFeature;
  final VoidCallback? onUnfeature;

  @override
  Widget build(BuildContext context) {
    final featured = row.isCatalogFeatured;
    final verified = row.isCatalogVerified;
    final initials = row.name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    Widget sealChip(String label, Color fg, Color bg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
    }

    final menu = PopupMenuButton<_SealAction>(
      tooltip: 'Acciones',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderStrong),
      ),
      color: theme.dialogSurface,
      onSelected: (a) {
        switch (a) {
          case _SealAction.toggleVerified:
            onToggleVerified();
          case _SealAction.feature:
            onFeature();
          case _SealAction.unfeature:
            onUnfeature?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _SealAction.toggleVerified,
          child: Text(verified ? 'Quitar Verificado' : 'Marcar Verificado'),
        ),
        if (!featured)
          const PopupMenuItem(
            value: _SealAction.feature,
            child: Text('Destacar…'),
          )
        else ...[
          const PopupMenuItem(
            value: _SealAction.feature,
            child: Text('Renovar destacado…'),
          ),
          const PopupMenuItem(
            value: _SealAction.unfeature,
            child: Text('Quitar Destacado'),
          ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.brand,
                ),
              )
            : LucideIcon(
                LucideGlyph.slidersHorizontal,
                size: 18,
                color: theme.textSecondary,
              ),
      ),
    );

    final detail = row.isMinorista
        ? (row.email?.trim().isNotEmpty == true
            ? row.email!.trim()
            : 'Tienda minorista')
        : '${row.unitsSold} uds · ${formatRefAmount(row.revenueRef)} REF\n'
            '${row.ordersEntregados} entregados · ${row.productsPaused} pausados';

    return ColoredBox(
      color: zebra ? theme.tableRowOdd : theme.tableRowEven,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.isMinorista ? 'Minorista' : 'Mayorista',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.textSecondary,
                          ),
                        ),
                        if (featured && row.catalogFeaturedUntil != null)
                          Text(
                            'Destacado hasta ${formatEsShortDateTime(row.catalogFeaturedUntil)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: theme.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (verified)
                    sealChip('Verificado', theme.brand, theme.brandContainer),
                  if (featured)
                    sealChip(
                      'Destacado',
                      theme.textPrimary,
                      theme.surfaceSubtle,
                    ),
                  if (!verified && !featured)
                    Text(
                      'Sin sellos',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 48, child: menu),
          ],
        ),
      ),
    );
  }
}

enum _SealAction { toggleVerified, feature, unfeature }

class _CompactFilterPill extends StatelessWidget {
  const _CompactFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = selected ? theme.brand : theme.brandContainer;
    final fg = selected ? theme.surfaceCard : theme.brand;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  final B2BThemeExtension theme;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brandContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          LucideIcon(LucideGlyph.circleAlert, size: 18, color: theme.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: theme.textPrimary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

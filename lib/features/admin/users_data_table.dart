import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/accounts_table_skeleton.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

enum UsersTableSortColumn { user, role, status, joined }

/// Tabla moderna de usuarios / talleres con búsqueda, orden, selección y
/// paginación (vista Usuarios › Cuentas).
class UsersDataTable extends StatefulWidget {
  const UsersDataTable({
    super.key,
    required this.profiles,
    required this.viewer,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.pageSize = 10,
    this.onRefresh,
    this.onCreate,
    this.onView,
    this.onEdit,
    this.onApprove,
    this.onDeactivate,
    this.onBlock,
    this.onReactivate,
    this.onHardDelete,
    this.onBulkDeactivate,
  });

  final List<ProfileModel> profiles;
  final ProfileModel viewer;
  final bool loading;
  final String? errorMessage;
  final Future<void> Function()? onRetry;
  final int pageSize;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onCreate;
  final ValueChanged<ProfileModel>? onView;
  final ValueChanged<ProfileModel>? onEdit;
  final ValueChanged<ProfileModel>? onApprove;
  final ValueChanged<ProfileModel>? onDeactivate;
  final ValueChanged<ProfileModel>? onBlock;
  final ValueChanged<ProfileModel>? onReactivate;

  /// Purga total (Super Admin / propietario).
  final ValueChanged<ProfileModel>? onHardDelete;
  final Future<void> Function(List<ProfileModel> selected)? onBulkDeactivate;

  /// Filas de demostración (sector mayorista VE) cuando no hay datos.
  static List<ProfileModel> sampleRows({DateTime? now}) {
    final t = now ?? DateTime(2026, 10, 12);
    return [
      ProfileModel(
        id: 'sample-1',
        businessName: 'Taller Moto Ruices',
        email: 'ruices@taller.ve',
        role: 'aliado',
        accountAccessStatus: AccountAccessStatus.active,
        createdAt: t.subtract(const Duration(days: 40)),
        isOwner: false,
      ),
      ProfileModel(
        id: 'sample-2',
        businessName: 'Importadora Valencia Parts',
        email: 'ops@importvalencia.ve',
        role: 'importador',
        accountAccessStatus: AccountAccessStatus.active,
        createdAt: t.subtract(const Duration(days: 120)),
        isOwner: false,
      ),
      ProfileModel(
        id: 'sample-3',
        businessName: 'B2B Conecta Ops',
        email: 'admin@b2bconecta.ve',
        role: 'administrador',
        accountAccessStatus: AccountAccessStatus.active,
        createdAt: t.subtract(const Duration(days: 400)),
        isOwner: true,
      ),
      ProfileModel(
        id: 'sample-4',
        businessName: 'Taller El Rayo Caracas',
        email: 'elrayo@motos.ve',
        role: 'aliado',
        accountAccessStatus: AccountAccessStatus.pendingReview,
        createdAt: t.subtract(const Duration(days: 3)),
        isOwner: false,
      ),
      ProfileModel(
        id: 'sample-5',
        businessName: 'Mayorista Andes Lubricantes',
        email: 'ventas@andeslube.ve',
        role: 'importador',
        accountAccessStatus: AccountAccessStatus.active,
        createdAt: t.subtract(const Duration(days: 75)),
        isOwner: false,
      ),
    ];
  }

  @override
  State<UsersDataTable> createState() => _UsersDataTableState();
}

/// Alias de producto para la tabla de cuentas.
typedef AccountsDataTable = UsersDataTable;

class _UsersDataTableState extends State<UsersDataTable> {
  static Color get _muted => AdminUsersChrome.muted;

  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  final _searchCtrl = TextEditingController();
  final Set<String> _selected = {};
  UsersTableSortColumn _sort = UsersTableSortColumn.joined;
  bool _sortAsc = false;
  int _pageIndex = 0;
  late int _pageSize;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.pageSize.clamp(1, 50);
    if (!listPageSizeOptions.contains(_pageSize)) {
      _pageSize = listPageSizeOptions.first;
    }
    _searchCtrl.addListener(() => setState(() => _pageIndex = 0));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProfileModel> get _source {
    if (widget.profiles.isNotEmpty) return widget.profiles;
    if (widget.loading || widget.errorMessage != null) {
      return const <ProfileModel>[];
    }
    return UsersDataTable.sampleRows();
  }

  bool get _usingSamples =>
      widget.profiles.isEmpty &&
      !widget.loading &&
      widget.errorMessage == null;

  List<ProfileModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _source.where((p) {
      if (q.isEmpty) return true;
      final name = (p.businessName ?? '').toLowerCase();
      final email = (p.email ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    int cmpName(ProfileModel a, ProfileModel b) {
      final an = (a.businessName ?? a.email ?? a.id).toLowerCase();
      final bn = (b.businessName ?? b.email ?? b.id).toLowerCase();
      return an.compareTo(bn);
    }

    list.sort((a, b) {
      int base;
      switch (_sort) {
        case UsersTableSortColumn.user:
          base = cmpName(a, b);
        case UsersTableSortColumn.role:
          base = _roleRank(a).compareTo(_roleRank(b));
          if (base == 0) base = cmpName(a, b);
        case UsersTableSortColumn.status:
          base = (_isActive(a) ? 0 : 1).compareTo(_isActive(b) ? 0 : 1);
          if (base == 0) base = cmpName(a, b);
        case UsersTableSortColumn.joined:
          final aAt = a.createdAt;
          final bAt = b.createdAt;
          if (aAt == null && bAt == null) {
            base = cmpName(a, b);
          } else if (aAt == null) {
            base = 1;
          } else if (bAt == null) {
            base = -1;
          } else {
            base = aAt.compareTo(bAt);
          }
      }
      return _sortAsc ? base : -base;
    });
    return list;
  }

  static int _roleRank(ProfileModel p) {
    if (p.isAdministrador) return p.isOwner ? 0 : 1;
    if (p.isImportador) return 2;
    if (p.isAliado) return 3;
    return 4;
  }

  static bool _isActive(ProfileModel p) {
    if (p.deactivatedAt != null) return false;
    final s = p.accountAccessStatus?.trim();
    if (s == null || s.isEmpty) return true;
    return s == AccountAccessStatus.active;
  }

  void _toggleSort(UsersTableSortColumn col) {
    setState(() {
      if (_sort == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sort = col;
        _sortAsc = col == UsersTableSortColumn.user;
      }
      _pageIndex = 0;
    });
  }

  String _joinDate(DateTime? at) {
    if (at == null) return '—';
    final d = at.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String _displayName(ProfileModel p) {
    final n = p.businessName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return p.email?.trim().isNotEmpty == true ? p.email!.trim() : 'Usuario';
  }

  String _initials(ProfileModel p) {
    final name = _displayName(p);
    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length < 2 ? 1 : 2).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  (_RoleBadgeStyle, String) _roleBadge(ProfileModel p) {
    final dark = AppColors.brightness == Brightness.dark;
    if (p.isAdministrador) {
      return (
        _RoleBadgeStyle(
          bg: dark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
          fg: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
        ),
        p.isOwner ? 'Super Admin' : 'Admin',
      );
    }
    if (p.isImportador) {
      return (
        _RoleBadgeStyle(
          bg: dark ? const Color(0x2616A34A) : const Color(0xFFF0FDF4),
          fg: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
        ),
        'Proveedor',
      );
    }
    return (
      _RoleBadgeStyle(
        bg: dark ? AdminUsersChrome.zebra : const Color(0xFFF8FAFC),
        fg: dark ? AdminUsersChrome.muted : const Color(0xFF475569),
      ),
      'Taller comprador',
    );
  }

  Future<void> _bulkDeactivate() async {
    final ids = _selected.toSet();
    final selected =
        _source.where((p) => ids.contains(p.id) && _isActive(p)).toList();
    if (selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar seleccionados'),
        content: Text(
          '¿Desactivar ${selected.length} cuenta(s)? Conservarán historial y correo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (widget.onBulkDeactivate != null) {
      await widget.onBulkDeactivate!(selected);
    }
    if (mounted) setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final pageIds = page.map((p) => p.id).toSet();
    final allPageSelected =
        pageIds.isNotEmpty && pageIds.every(_selected.contains);
    final theme = B2BThemeExtension.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminUsersChrome.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminUsersChrome.border),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(
              AppColors.isDarkOf(context) ? 0.35 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            searchCtrl: _searchCtrl,
            resultCount: filtered.length,
            usingSamples: _usingSamples,
            selectedCount: _selected.length,
            onCreate: widget.onCreate,
            onBulkDeactivate:
                _selected.isEmpty ? null : () => _bulkDeactivate(),
            onRefresh: widget.onRefresh,
          ),
          const SizedBox(height: 14),
          if (widget.errorMessage != null && widget.profiles.isEmpty) ...[
            _AccountsErrorBanner(
              message: widget.errorMessage!,
              onRetry: widget.onRetry ?? widget.onRefresh,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.loading)
            LayoutBuilder(
              builder: (context, constraints) {
                return AccountsTableSkeleton(
                  compact: constraints.maxWidth < 760,
                );
              },
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final hasQuery = _searchCtrl.text.trim().isNotEmpty;
                return Column(
                  children: [
                    if (widget.errorMessage != null &&
                        widget.profiles.isNotEmpty) ...[
                      _AccountsErrorBanner(
                        message: widget.errorMessage!,
                        onRetry: widget.onRetry ?? widget.onRefresh,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _StickyHeader(
                      compact: compact,
                      allSelected: allPageSelected,
                      onToggleAll: (v) {
                        setState(() {
                          if (v) {
                            _selected.addAll(pageIds);
                          } else {
                            _selected.removeAll(pageIds);
                          }
                        });
                      },
                      sort: _sort,
                      sortAsc: _sortAsc,
                      onSort: _toggleSort,
                    ),
                    if (page.isEmpty)
                      _AccountsEmptyState(
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => _pageIndex = 0);
                        },
                        showClear: hasQuery || _selected.isNotEmpty,
                      )
                    else
                      for (var i = 0; i < page.length; i++)
                        _UserRow(
                          profile: page[i],
                          zebra: i.isOdd,
                          compact: compact,
                          selected: _selected.contains(page[i].id),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selected.add(page[i].id);
                              } else {
                                _selected.remove(page[i].id);
                              }
                            });
                          },
                          displayName: _displayName(page[i]),
                          initials: _initials(page[i]),
                          role: _roleBadge(page[i]),
                          active: _isActive(page[i]),
                          joinDate: _joinDate(page[i].createdAt),
                          pendingReview: page[i].accountAccessStatus ==
                              AccountAccessStatus.pendingReview,
                          onView: () => widget.onView?.call(page[i]),
                          onEdit: () => widget.onEdit?.call(page[i]),
                          onApprove: () => widget.onApprove?.call(page[i]),
                          onDeactivate: () => widget.onDeactivate?.call(page[i]),
                          onBlock: widget.onBlock == null
                              ? null
                              : () => widget.onBlock!(page[i]),
                          onReactivate: widget.onReactivate == null
                              ? null
                              : () => widget.onReactivate!(page[i]),
                          onHardDelete: widget.onHardDelete == null
                              ? null
                              : () => widget.onHardDelete!(page[i]),
                          canHardDelete: widget.viewer.isOwner,
                          canBlock: _isActive(page[i]) &&
                              page[i].accountAccessStatus !=
                                  AccountAccessStatus.rejected,
                          canReactivate: page[i].isDeactivated ||
                              page[i].accountAccessStatus ==
                                  AccountAccessStatus.rejected ||
                              OwnerAccountRules.canActivateAccess(
                                accountAccessStatus:
                                    page[i].accountAccessStatus,
                                deactivatedAt: page[i].deactivatedAt,
                              ),
                        ),
                    ListPageBar(
                      total: filtered.length,
                      pageIndex: _pageIndex,
                      pageSize: _pageSize,
                      alwaysShow: filtered.isNotEmpty,
                      entityLabel: 'usuarios',
                      onPageIndex: (index) =>
                          setState(() => _pageIndex = index),
                      onPageSize: (size) => setState(() {
                        _pageSize = size;
                        _pageIndex = 0;
                      }),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleBadgeStyle {
  const _RoleBadgeStyle({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchCtrl,
    required this.resultCount,
    required this.usingSamples,
    required this.selectedCount,
    this.onCreate,
    this.onBulkDeactivate,
    this.onRefresh,
  });

  final TextEditingController searchCtrl;
  final int resultCount;
  final bool usingSamples;
  final int selectedCount;
  final VoidCallback? onCreate;
  final VoidCallback? onBulkDeactivate;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = B2BThemeExtension.of(context);
        final narrow = constraints.maxWidth < 640;
        final search = TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o correo…',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: LucideIcon(
                LucideGlyph.search,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
            filled: true,
            fillColor: AdminUsersChrome.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AdminUsersChrome.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AdminUsersChrome.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AdminUsersChrome.brand, width: 1.4),
            ),
          ),
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              usingSamples
                  ? '$resultCount ejemplo${resultCount == 1 ? '' : 's'}'
                  : '$resultCount resultado${resultCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            if (selectedCount > 0)
              TextButton.icon(
                onPressed: onBulkDeactivate,
                icon: const LucideIcon(
                  LucideGlyph.trash2,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                label: Text('Desactivar ($selectedCount)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                ),
              ),
            if (onRefresh != null)
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () => onRefresh?.call(),
                icon: const LucideIcon(
                  LucideGlyph.refreshCw,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: theme.surfaceCard,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: LucideIcon(
                LucideGlyph.userPlus,
                size: 18,
                color: theme.surfaceCard,
              ),
              label: Text(narrow ? 'Invitar' : 'Crear / Invitar Usuario'),
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              actions,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.compact,
    required this.allSelected,
    required this.onToggleAll,
    required this.sort,
    required this.sortAsc,
    required this.onSort,
  });

  final bool compact;
  final bool allSelected;
  final ValueChanged<bool> onToggleAll;
  final UsersTableSortColumn sort;
  final bool sortAsc;
  final ValueChanged<UsersTableSortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    Widget head(String label, UsersTableSortColumn col, {int flex = 1}) {
      final active = sort == col;
      final color = active ? theme.brand : theme.textSecondary;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => onSort(col),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                LucideIcon(
                  active && sortAsc
                      ? LucideGlyph.trendingUp
                      : LucideGlyph.trendingDown,
                  size: 12,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.tableHeaderBg,
        border: Border(
          bottom: BorderSide(color: theme.borderStrong),
          top: BorderSide(color: theme.borderStrong),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allSelected,
              onChanged: (v) => onToggleAll(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (compact)
            head('Usuario', UsersTableSortColumn.user, flex: 3)
          else ...[
            head('Usuario', UsersTableSortColumn.user, flex: 4),
            head('Rol', UsersTableSortColumn.role, flex: 2),
            head('Estado', UsersTableSortColumn.status, flex: 2),
            head('Registro', UsersTableSortColumn.joined, flex: 2),
            const SizedBox(
              width: 48,
              child: Text(
                '',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserRow extends StatefulWidget {
  const _UserRow({
    required this.profile,
    required this.zebra,
    required this.compact,
    required this.selected,
    required this.onSelected,
    required this.displayName,
    required this.initials,
    required this.role,
    required this.active,
    required this.joinDate,
    required this.pendingReview,
    this.onView,
    this.onEdit,
    this.onApprove,
    this.onDeactivate,
    this.onBlock,
    this.onReactivate,
    this.onHardDelete,
    this.canHardDelete = false,
    this.canReactivate = false,
    this.canBlock = false,
  });

  final ProfileModel profile;
  final bool zebra;
  final bool compact;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String displayName;
  final String initials;
  final (_RoleBadgeStyle, String) role;
  final bool active;
  final String joinDate;
  final bool pendingReview;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onDeactivate;
  final VoidCallback? onBlock;
  final VoidCallback? onReactivate;
  final VoidCallback? onHardDelete;
  final bool canHardDelete;
  final bool canReactivate;
  final bool canBlock;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _resolveLogo();
  }

  @override
  void didUpdateWidget(covariant _UserRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.logoStoragePath !=
        widget.profile.logoStoragePath) {
      _resolveLogo();
    }
  }

  Future<void> _resolveLogo() async {
    final path = widget.profile.logoStoragePath?.trim();
    if (path == null || path.isEmpty) {
      setState(() => _logoUrl = null);
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
    final roleStyle = widget.role.$1;
    final roleLabel = widget.role.$2;
    final userCell = Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: roleStyle.bg,
          backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
          child: _logoUrl == null
              ? Text(
                  widget.initials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: roleStyle.fg,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminUsersChrome.titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.profile.email?.trim().isNotEmpty == true
                    ? widget.profile.email!.trim()
                    : 'Sin correo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AdminUsersChrome.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget badge(String label, Color bg, Color fg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
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

    final status = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.active
                ? const Color(0xFF16A34A)
                : const Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        badge(
          widget.active ? 'Activo' : 'Inactivo',
          widget.active
              ? (AppColors.brightness == Brightness.dark
                  ? const Color(0x2616A34A)
                  : const Color(0xFFF0FDF4))
              : AdminUsersChrome.zebra,
          widget.active
              ? (AppColors.brightness == Brightness.dark
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF16A34A))
              : AdminUsersChrome.muted,
        ),
      ],
    );

    final menu = PopupMenuButton<_RowAction>(
      tooltip: 'Acciones',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AdminUsersChrome.border),
      ),
      color: AdminUsersChrome.cardColor,
      onSelected: (a) {
        switch (a) {
          case _RowAction.view:
            widget.onView?.call();
          case _RowAction.edit:
            widget.onEdit?.call();
          case _RowAction.approve:
            widget.onApprove?.call();
          case _RowAction.deactivate:
            widget.onDeactivate?.call();
          case _RowAction.block:
            widget.onBlock?.call();
          case _RowAction.reactivate:
            widget.onReactivate?.call();
          case _RowAction.hardDelete:
            widget.onHardDelete?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RowAction.view,
          child: _ActionMenuTile(
            glyph: LucideGlyph.fileText,
            title: 'Ver expediente y documentos',
            subtitle: 'Datos fiscales y KYC en el panel lateral',
          ),
        ),
        PopupMenuItem(
          value: _RowAction.edit,
          child: _ActionMenuTile(
            glyph: LucideGlyph.pencil,
            title: 'Editar datos de la cuenta',
            subtitle: 'Nombre, RIF, teléfono y ubicación',
          ),
        ),
        if (widget.pendingReview)
          PopupMenuItem(
            value: _RowAction.approve,
            child: _ActionMenuTile(
              glyph: LucideGlyph.clipboardCheck,
              title: 'Revisar documentación',
              subtitle: 'Abrir expediente para verificar',
            ),
          ),
        if (widget.canReactivate && widget.onReactivate != null)
          PopupMenuItem(
            value: _RowAction.reactivate,
            child: _ActionMenuTile(
              glyph: LucideGlyph.circlePlay,
              title: 'Restablecer acceso',
              subtitle: 'Volver a habilitar el inicio de sesión',
              color: AdminUsersChrome.brand,
            ),
          ),
        if (widget.canBlock && widget.onBlock != null)
          PopupMenuItem(
            value: _RowAction.block,
            child: _ActionMenuTile(
              glyph: LucideGlyph.circlePause,
              title: 'Suspender acceso temporalmente',
              subtitle: 'Pausa el inicio de sesión sin dar de baja',
              color: const Color(0xFFD97706),
            ),
          ),
        if (widget.active)
          PopupMenuItem(
            value: _RowAction.deactivate,
            child: _ActionMenuTile(
              glyph: LucideGlyph.userMinus,
              title: 'Desactivar cuenta (conservar historial)',
              subtitle: 'Congela acceso y reserva el correo',
              color: const Color(0xFFD97706),
            ),
          ),
        if (widget.canHardDelete && widget.onHardDelete != null)
          PopupMenuItem(
            value: _RowAction.hardDelete,
            child: _ActionMenuTile(
              glyph: LucideGlyph.trash2,
              title: 'Eliminar y liberar correo',
              subtitle: 'Borrado permanente de la cuenta',
              color: const Color(0xFFDC2626),
            ),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.all(8),
        child: LucideIcon(
          LucideGlyph.slidersHorizontal,
          size: 18,
          color: AdminUsersChrome.muted,
        ),
      ),
    );

    if (widget.compact) {
      return ColoredBox(
        color: widget.zebra ? AdminUsersChrome.zebra : AdminUsersChrome.rowEven,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: widget.selected,
                onChanged: (v) => widget.onSelected(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    userCell,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        badge(roleLabel, roleStyle.bg, roleStyle.fg),
                        status,
                        Text(
                          widget.joinDate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              menu,
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: widget.zebra ? AdminUsersChrome.zebra : AdminUsersChrome.rowEven,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: widget.selected,
                onChanged: (v) => widget.onSelected(v ?? false),
              ),
            ),
            Expanded(flex: 4, child: userCell),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: badge(roleLabel, roleStyle.bg, roleStyle.fg),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(alignment: Alignment.centerLeft, child: status),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.joinDate,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AdminUsersChrome.muted,
                ),
              ),
            ),
            SizedBox(width: 48, child: menu),
          ],
        ),
      ),
    );
  }
}

enum _RowAction {
  view,
  edit,
  approve,
  block,
  reactivate,
  deactivate,
  hardDelete,
}

class _ActionMenuTile extends StatelessWidget {
  const _ActionMenuTile({
    required this.glyph,
    required this.title,
    required this.subtitle,
    this.color,
  });

  final LucideGlyph glyph;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AdminUsersChrome.titleColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: LucideIcon(glyph, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AdminUsersChrome.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsEmptyState extends StatelessWidget {
  const _AccountsEmptyState({
    required this.onClear,
    required this.showClear,
  });

  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.surfaceSubtle,
              shape: BoxShape.circle,
              border: Border.all(color: theme.borderSubtle),
            ),
            alignment: Alignment.center,
            child: const LucideIcon(
              LucideGlyph.searchX,
              size: 28,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron usuarios ni talleres',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta ajustando los términos de búsqueda o removiendo los filtros aplicados para ver más resultados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.textSecondary,
            ),
          ),
          if (showClear) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              icon: LucideIcon(
                LucideGlyph.rotateCcw,
                size: 16,
                color: theme.textSecondary,
              ),
              label: const Text(
                'Limpiar filtros y búsqueda',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountsErrorBanner extends StatelessWidget {
  const _AccountsErrorBanner({
    required this.message,
    this.onRetry,
  });

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0x26EF4444) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          LucideIcon(
            LucideGlyph.circleAlert,
            size: 18,
            color: dark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Error al cargar los datos de usuarios. Por favor, verifica tu conexión.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: dark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: () => onRetry!(),
              icon: LucideIcon(
                LucideGlyph.refreshCw,
                size: 14,
                color: dark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
              ),
              label: Text(
                'Reintentar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:
                      dark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

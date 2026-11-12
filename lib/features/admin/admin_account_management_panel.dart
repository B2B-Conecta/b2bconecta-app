import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/admin/incomplete_signup_row.dart';
import 'package:motolink_pro_app/features/admin/account_action_dialogs.dart';
import 'package:motolink_pro_app/features/admin/delete_user_dialog.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier_form.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/admin_crud_toast.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_standard_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/add_user_modal.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/owner_account_kyc_dossier_section.dart';
import 'package:motolink_pro_app/features/admin/users_data_table.dart';

enum _AccountListMode { cuentas, incompletos }

enum _IncompleteFilter { todos, sinConfirmar, confirmados }

/// Administración: alta, expediente, bloqueo, baja lógica y borrado de Auth.
/// Cambiar rol y el catálogo del mayorista siguen reservados al propietario.
class AdminAccountManagementPanel extends StatefulWidget {
  const AdminAccountManagementPanel({
    super.key,
    required this.viewer,
    this.embeddedInHub = false,
  });

  final ProfileModel viewer;

  /// Embebido en [AdminUsersHubPanel].
  final bool embeddedInHub;

  @override
  State<AdminAccountManagementPanel> createState() =>
      _AdminAccountManagementPanelState();
}

class _AdminAccountManagementPanelState
    extends State<AdminAccountManagementPanel> {
  List<ProfileModel> _rows = const [];
  List<IncompleteSignupRow> _incomplete = const [];
  bool _loading = true;
  bool _incompleteLoading = false;
  bool _incompleteLoaded = false;
  String? _error;
  String? _incompleteError;
  String? _busyIncompleteId;
  _AccountListMode _mode = _AccountListMode.cuentas;
  _IncompleteFilter _incompleteFilter = _IncompleteFilter.todos;
  String? _busyId;
  String? _previewProfileId;
  OwnerAccountSort _sort = OwnerAccountSort.newest;
  final _searchCtrl = TextEditingController();
  final _listScroll = ScrollController();
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerAdminAccountNotificationDeepLink(
      _consumeAccountDeepLink,
    );
    _searchCtrl.addListener(() => setState(() => _pageIndex = 0));
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminAccountNotificationDeepLink(null);
    MainShellTabController.clearAdminBreadcrumbTrail();
    _searchCtrl.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _syncBreadcrumbTrail() {
    if (_mode != _AccountListMode.incompletos) {
      MainShellTabController.clearAdminBreadcrumbTrail();
      return;
    }
    MainShellTabController.setAdminBreadcrumbTrail(
      AdminBreadcrumbTrail(
        leafLabel: 'Registro Incompleto',
        onBack: () {
          unawaited(_selectMode(_AccountListMode.cuentas));
        },
        onPopToParent: () {
          unawaited(_selectMode(_AccountListMode.cuentas));
        },
      ),
    );
  }

  ProfileModel? _findProfile(String id) {
    for (final p in _rows) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _consumeAccountDeepLink() {
    final pending = MainShellTabController.consumePendingAccountProfileId() ??
        MainShellTabController.consumePendingKycProfileId();
    if (pending == null || !mounted) return;
    setState(() {
      _mode = _AccountListMode.cuentas;
      _previewProfileId = pending;
      _searchCtrl.clear();
    });
    if (!isAdminDesktopLayout(context)) {
      final p = _findProfile(pending);
      if (p != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openAccountPreview(p);
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.ownerListProfilesWithDossier();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      _consumeAccountDeepLink();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadIncomplete() async {
    setState(() {
      _incompleteLoading = true;
      _incompleteError = null;
    });
    try {
      final rows = await SupabaseService.listIncompleteSignups();
      if (!mounted) return;
      setState(() {
        _incomplete = rows;
        _incompleteLoading = false;
        _incompleteLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _incompleteError = e.toString();
        _incompleteLoading = false;
        _incompleteLoaded = true;
      });
    }
  }

  Future<void> _selectMode(_AccountListMode mode) async {
    if (_mode == mode) return;
    _searchCtrl.clear();
    setState(() {
      _mode = mode;
      _pageIndex = 0;
    });
    _syncBreadcrumbTrail();
    if (mode == _AccountListMode.incompletos && !_incompleteLoaded) {
      await _loadIncomplete();
    }
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
  }

  Future<void> _completeIncomplete(IncompleteSignupRow row) async {
    final stub = ProfileModel(
      id: row.userId,
      email: row.email,
      businessName: row.displayName,
      phone: row.phone,
      role: 'aliado',
      accountAccessStatus: AccountAccessStatus.pendingReview,
      createdAt: row.createdAt,
    );
    final changed = await OwnerAccountDossierForm.open(
      context,
      existing: stub,
      allowAdminRole: widget.viewer.isOwner,
      canDeleteAccount: false,
    );
    if (changed == true && mounted) {
      AdminCrudToast.success(context, 'Expediente actualizado.');
      await _loadIncomplete();
      await _load();
    }
  }

  List<IncompleteSignupRow> get _incompleteFiltered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _incomplete.where((row) {
      switch (_incompleteFilter) {
        case _IncompleteFilter.sinConfirmar:
          if (row.email == null || row.emailConfirmed) return false;
        case _IncompleteFilter.confirmados:
          if (!row.emailConfirmed) return false;
        case _IncompleteFilter.todos:
          break;
      }
      if (q.isEmpty) return true;
      final name = (row.displayName ?? '').toLowerCase();
      final email = (row.email ?? '').toLowerCase();
      final phone = (row.phone ?? '').toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    });
    return sortByCreatedAt(
      filtered,
      createdAtOf: (row) => row.createdAt,
      tieBreakKey: (row) => row.userId,
      newestFirst: _sort != OwnerAccountSort.oldest,
    );
  }

  Future<void> _openAccountPreview(ProfileModel p) async {
    setState(() => _previewProfileId = p.id);
    if (isAdminDesktopLayout(context)) return;
    await showAdaptiveAdminSheet<void>(
      context: context,
      draggable: true,
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              p.businessName?.trim().isNotEmpty == true
                  ? p.businessName!.trim()
                  : (p.email ?? 'Sin nombre'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            OwnerAccountDossier(
              profile: p,
              isSelf: p.id == widget.viewer.id,
            ),
            OwnerAccountKycDossierSection(
              profile: p,
              viewerRole: widget.viewer.role,
            ),
            _previewRoleToggle(p),
          ],
        );
      },
    );
  }

  bool _canChangeRole(ProfileModel p) {
    if (OwnerAccountRules.canChangeB2bRole(
      viewerIsOwner: widget.viewer.isOwner,
      viewerRole: widget.viewer.role,
      viewerId: widget.viewer.id,
      targetId: p.id,
      targetIsOwner: p.isOwner,
      targetRole: p.role,
    )) {
      return true;
    }
    // Owner: también puede asignar rol administrador.
    return OwnerAccountRules.canManageTarget(
      viewerIsOwner: widget.viewer.isOwner,
      viewerId: widget.viewer.id,
      targetId: p.id,
      targetIsOwner: p.isOwner,
    );
  }

  bool _canOperate(ProfileModel p) => OwnerAccountRules.canDeleteTarget(
        viewerIsOwner: widget.viewer.isOwner,
        viewerRole: widget.viewer.role,
        viewerId: widget.viewer.id,
        targetId: p.id,
        targetIsOwner: p.isOwner,
        targetRole: p.role,
      );

  Future<bool> _runBusy(ProfileModel p, Future<void> Function() action) async {
    setState(() => _busyId = p.id);
    try {
      await action();
      if (!mounted) return false;
      await _load();
      return true;
    } catch (e) {
      if (!mounted) return false;
      AdminCrudToast.error(
        context,
        'No se pudo completar la operación. $e',
      );
      return false;
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _block(ProfileModel p) async {
    final note = await showSuspendAccessDialog(
      context: context,
      profile: p,
    );
    if (note == null || !mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerSetAccountAccess(
        profileId: p.id,
        status: AccountAccessStatus.rejected,
        note: note,
      );
    });
    if (!mounted || !done) return;
    AdminCrudToast.success(context, 'Acceso suspendido temporalmente.');
  }

  Future<void> _reactivate(ProfileModel p) async {
    final firstActivate = OwnerAccountRules.canActivateAccess(
      accountAccessStatus: p.accountAccessStatus,
      deactivatedAt: p.deactivatedAt,
    );
    final ok = await showReactivateAccountDialog(
      context: context,
      profile: p,
      firstActivate: firstActivate,
    );
    if (ok != true || !mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerSetAccountAccess(
        profileId: p.id,
        status: AccountAccessStatus.active,
      );
    });
    if (!mounted || !done) return;
    AdminCrudToast.success(
      context,
      firstActivate ? 'Cuenta activada correctamente.' : 'Acceso restablecido.',
    );
  }

  Future<void> _deactivate(ProfileModel p) async {
    final note = await showDeactivateAccountDialog(
      context: context,
      profile: p,
    );
    if (note == null || !mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerDeactivateProfile(
        profileId: p.id,
        note: note,
      );
    });
    if (!mounted || !done) return;
    AdminCrudToast.success(
      context,
      'Cuenta desactivada. Historial y correo se conservan.',
    );
  }

  Future<void> _hardDelete(ProfileModel p) async {
    final ok = await showDeleteUserDialog(
      context: context,
      profile: p,
      onDelete: (confirm) => SupabaseService.ownerHardDeleteProfile(
        profileId: p.id,
        confirm: confirm,
      ),
    );
    if (ok != true || !mounted) return;
    if (_previewProfileId == p.id) {
      setState(() => _previewProfileId = null);
    }
    await _load();
    if (!mounted) return;
    AdminCrudToast.success(
      context,
      'Cuenta borrada. El correo quedó libre para reutilizar.',
    );
  }

  /// Única acción del panel lateral: alternar Minorista ↔ Mayorista.
  Widget _previewRoleToggle(ProfileModel p) {
    final role = p.role?.trim().toLowerCase();
    final isB2b = role == 'aliado' || role == 'importador';
    if (!isB2b || !_canChangeRole(p)) return const SizedBox.shrink();
    final isAliado = role == 'aliado';
    final busy = _busyId == p.id;

    Future<void> apply(String next) async {
      if (busy || next == role) return;
      final done = await _runBusy(p, () async {
        await SupabaseService.ownerSetProfileRole(
          profileId: p.id,
          role: next,
        );
      });
      if (!mounted || !done) return;
      AdminCrudToast.success(
        context,
        'Rol actualizado a «${ProfileRoleLabels.labelEs(next)}».',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AdminUsersChrome.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminUsersChrome.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LucideIcon(
                    LucideGlyph.arrowLeftRight,
                    size: 15,
                    color: AdminUsersChrome.brand,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Rol de la cuenta',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminUsersChrome.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RolePill(
                      label: 'Minorista',
                      selected: isAliado,
                      enabled: !busy,
                      onTap: () => apply('aliado'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RolePill(
                      label: 'Mayorista',
                      selected: !isAliado,
                      enabled: !busy,
                      onTap: () => apply('importador'),
                    ),
                  ),
                ],
              ),
              if (busy) ...[
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AdminUsersChrome.brand,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isAdminDesktopLayout(context);
    final preview =
        _previewProfileId == null ? null : _findProfile(_previewProfileId!);

    final listBody = RefreshIndicator(
      onRefresh: _mode == _AccountListMode.incompletos ? _loadIncomplete : _load,
      color: AppColors.brand,
      child: ListView(
        controller: _listScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_mode == _AccountListMode.incompletos)
            ..._incompleteSection()
          else ...[
            UsersDataTable(
              profiles: _rows,
              viewer: widget.viewer,
              loading: _loading,
              errorMessage: _error,
              onRetry: _load,
              onRefresh: _load,
              onCreate: () async {
                final created = await AddUserModal.open(
                  context,
                  allowAdminRole: widget.viewer.isOwner,
                );
                if (created == true && mounted) {
                  AdminCrudToast.success(
                    context,
                    'Usuario creado o invitación enviada.',
                  );
                  await _load();
                }
              },
              onView: (p) {
                setState(() => _previewProfileId = p.id);
                if (!desktop) {
                  unawaited(_openAccountPreview(p));
                }
              },
              onEdit: (p) async {
                final changed = await OwnerAccountDossierForm.open(
                  context,
                  existing: p,
                  allowAdminRole: widget.viewer.isOwner,
                  canDeleteAccount: _canOperate(p),
                );
                if (changed == true && mounted) {
                  AdminCrudToast.success(
                    context,
                    'Taller actualizado correctamente.',
                  );
                  await _load();
                }
              },
              onApprove: (p) {
                setState(() => _previewProfileId = p.id);
                if (!desktop) {
                  unawaited(_openAccountPreview(p));
                }
              },
              onDeactivate: _deactivate,
              onBlock: _block,
              onReactivate: _reactivate,
              onHardDelete: widget.viewer.isOwner ? _hardDelete : null,
              onBulkDeactivate: (selected) async {
                for (final p in selected) {
                  if (!_canOperate(p)) continue;
                  await SupabaseService.ownerDeactivateProfile(
                    profileId: p.id,
                    note: 'Desactivación masiva desde tabla de usuarios',
                  );
                }
                if (mounted) await _load();
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _selectMode(_AccountListMode.incompletos),
                child: const Text('Ver registros incompletos'),
              ),
            ),
          ],
        ],
      ),
    );

    if (!desktop || _mode == _AccountListMode.incompletos || preview == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktop
                ? AppBreakpoints.adminContentMaxWidth
                : AppBreakpoints.formMaxWidth,
          ),
          child: listBody,
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.adminContentMaxWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: listBody),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 380,
              child: Material(
                color: AdminUsersChrome.cardColor,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            preview.businessName?.trim().isNotEmpty == true
                                ? preview.businessName!.trim()
                                : (preview.email ?? 'Sin nombre'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AdminUsersChrome.titleColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () =>
                              setState(() => _previewProfileId = null),
                          icon: LucideIcon(
                            LucideGlyph.close,
                            size: 18,
                            color: AdminUsersChrome.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OwnerAccountDossier(
                      profile: preview,
                      isSelf: preview.id == widget.viewer.id,
                    ),
                    OwnerAccountKycDossierSection(
                      profile: preview,
                      viewerRole: widget.viewer.role,
                      onChanged: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    _previewRoleToggle(preview),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _incompleteSection() {
    final theme = B2BThemeExtension.of(context);
    final filtered = _incompleteFiltered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final confirmLabel = switch (_incompleteFilter) {
      _IncompleteFilter.todos => 'Todos',
      _IncompleteFilter.sinConfirmar => 'Sin confirmar',
      _IncompleteFilter.confirmados => 'Confirmados',
    };

    Widget body;
    if (_incompleteLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    } else if (_incompleteError != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              _incompleteError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _loadIncomplete,
              style: FilledButton.styleFrom(
                backgroundColor: theme.brand,
                foregroundColor: theme.surfaceCard,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (filtered.isEmpty) {
      body = _IncompleteEmptyState(
        filteredEmpty: _incomplete.isNotEmpty,
        onBackToAccounts: () => _selectMode(_AccountListMode.cuentas),
        onClearSearch: _incomplete.isNotEmpty
            ? () => setState(() {
                  _searchCtrl.clear();
                  _incompleteFilter = _IncompleteFilter.todos;
                  _pageIndex = 0;
                })
            : null,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.tableRowEven,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const B2bDataTableHeader(
                  cells: [
                    B2bDataTableHeaderCell(label: 'Usuario / Correo', flex: 4),
                    B2bDataTableHeaderCell(label: 'Paso pendiente', flex: 3),
                    B2bDataTableHeaderCell(label: 'Fecha de inicio', flex: 2),
                    B2bDataTableHeaderCell(label: 'Acciones', flex: 3),
                  ],
                ),
                for (var i = 0; i < page.length; i++)
                  _IncompleteTableRow(
                    key: ValueKey<String>('incompleto-${page[i].userId}'),
                    row: page[i],
                    zebra: i.isOdd,
                    isLast: i == page.length - 1,
                    busy: _busyIncompleteId == page[i].userId,
                    onComplete: () => _completeIncomplete(page[i]),
                    onBan: () => _banIncomplete(page[i]),
                    onPurge: () => _purgeIncomplete(page[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListPageBar(
            total: filtered.length,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
            alwaysShow: true,
            entityLabel: 'registros',
            onPageIndex: (index) {
              setState(() => _pageIndex = index);
              if (_listScroll.hasClients) _listScroll.jumpTo(0);
            },
            onPageSize: (size) {
              setState(() {
                _pageSize = size;
                _pageIndex = 0;
              });
              if (_listScroll.hasClients) _listScroll.jumpTo(0);
            },
          ),
        ],
      );
    }

    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: theme.textPrimary.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.brandContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.brand.withOpacity(0.35)),
                  ),
                  child: Text(
                    'Registro Incompleto',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: theme.brand,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _selectMode(_AccountListMode.cuentas),
                  icon: LucideIcon(
                    LucideGlyph.arrowLeft,
                    size: 16,
                    color: theme.brand,
                  ),
                  label: Text(
                    'Volver a todas las cuentas',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.brand,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AdminStandardFilterBar(
              padding: EdgeInsets.zero,
              searchController: _searchCtrl,
              searchHint: 'Buscar por nombre, correo o teléfono…',
              onSearchChanged: (_) => setState(() => _pageIndex = 0),
              clearVisible: _incompleteFilter != _IncompleteFilter.todos ||
                  _sort != OwnerAccountSort.newest,
              onClear: () => setState(() {
                _incompleteFilter = _IncompleteFilter.todos;
                _sort = OwnerAccountSort.newest;
                _pageIndex = 0;
              }),
              menus: [
                AdminFilterDropdown(
                  icon: Icons.mark_email_read_outlined,
                  placeholder: 'Estado',
                  valueLabel: confirmLabel,
                  active: _incompleteFilter != _IncompleteFilter.todos,
                  options: [
                    for (final f in _IncompleteFilter.values)
                      AdminFilterOption(
                        label: switch (f) {
                          _IncompleteFilter.todos => 'Todos',
                          _IncompleteFilter.sinConfirmar => 'Sin confirmar',
                          _IncompleteFilter.confirmados => 'Confirmados',
                        },
                        selected: _incompleteFilter == f,
                        onSelect: () => setState(() {
                          _incompleteFilter = f;
                          _pageIndex = 0;
                        }),
                      ),
                  ],
                ),
                AdminFilterDropdown(
                  icon: Icons.sort,
                  placeholder: 'Orden',
                  valueLabel: _sort.labelEs,
                  active: _sort != OwnerAccountSort.newest,
                  options: [
                    for (final s in const [
                      OwnerAccountSort.newest,
                      OwnerAccountSort.oldest,
                    ])
                      AdminFilterOption(
                        label: s.labelEs,
                        selected: _sort == s,
                        onSelect: () => setState(() {
                          _sort = s;
                          _pageIndex = 0;
                        }),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            body,
          ],
        ),
      ),
    ];
  }

  Future<String?> _promptIncompleteNote() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(OwnerAccountRules.softDeleteDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'El registro incompleto no podrá iniciar sesión. '
              'El correo sigue ocupado hasta que lo borre.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Motivo (mín. 3 caracteres)…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final note = ctrl.text.trim();
              if (note.length < 3) return;
              Navigator.of(ctx).pop(note);
            },
            child: const Text(OwnerAccountRules.softDeleteActionLabel),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<String?> _promptIncompletePurge(IncompleteSignupRow row) async {
    final ctrl = TextEditingController();
    final email = row.email?.trim();
    final hasEmail = email != null && email.isNotEmpty;
    final expected = hasEmail ? email.toLowerCase() : row.userId.toLowerCase();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final canConfirm = ctrl.text.trim().toLowerCase() == expected;
          return AlertDialog(
            title: const Text(OwnerAccountRules.hardDeleteDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasEmail
                      ? 'Se eliminará el usuario de Auth y el correo quedará libre '
                          'para un registro nuevo.\n\nEscriba $email para confirmar.'
                      : 'Se eliminará el usuario de Auth.\n\n'
                          'Escriba el id del usuario para confirmar.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hasEmail ? 'Correo…' : 'Id de usuario…',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.of(ctx).pop(ctrl.text.trim())
                    : null,
                child: const Text(OwnerAccountRules.hardDeleteActionLabel),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<void> _banIncomplete(IncompleteSignupRow row) async {
    final note = await _promptIncompleteNote();
    if (note == null || !mounted) return;
    setState(() => _busyIncompleteId = row.userId);
    try {
      await SupabaseService.banIncompleteSignup(
        userId: row.userId,
        note: note,
      );
      if (!mounted) return;
      AdminCrudToast.success(
        context,
        'Registro incompleto desactivado. El correo sigue ocupado.',
      );
      await _loadIncomplete();
    } catch (e) {
      if (!mounted) return;
      AdminCrudToast.error(context, 'No se pudo desactivar: $e');
    } finally {
      if (mounted) setState(() => _busyIncompleteId = null);
    }
  }

  Future<void> _purgeIncomplete(IncompleteSignupRow row) async {
    final confirm = await _promptIncompletePurge(row);
    if (confirm == null || !mounted) return;
    setState(() => _busyIncompleteId = row.userId);
    try {
      await SupabaseService.purgeIncompleteSignup(
        userId: row.userId,
        confirm: confirm,
      );
      if (!mounted) return;
      AdminCrudToast.success(
        context,
        'Registro borrado. El correo quedó libre.',
      );
      await _loadIncomplete();
    } catch (e) {
      if (!mounted) return;
      AdminCrudToast.error(context, 'No se pudo borrar: $e');
    } finally {
      if (mounted) setState(() => _busyIncompleteId = null);
    }
  }

}

class _IncompleteEmptyState extends StatelessWidget {
  const _IncompleteEmptyState({
    required this.filteredEmpty,
    required this.onBackToAccounts,
    this.onClearSearch,
  });

  final bool filteredEmpty;
  final VoidCallback onBackToAccounts;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    if (filteredEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Text(
              'Ningún registro coincide con la búsqueda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: theme.textSecondary,
              ),
            ),
            if (onClearSearch != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClearSearch,
                child: Text(
                  'Limpiar filtros',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.brand,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.successBg,
              shape: BoxShape.circle,
              border: Border.all(color: theme.successFg.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              LucideGlyph.circleCheck,
              size: 28,
              color: theme.successFg,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '¡Todo al día!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay talleres ni proveedores con registros pendientes de completar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onBackToAccounts,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.textPrimary,
              side: BorderSide(color: theme.borderStrong),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'Ver todas las cuentas',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncompleteTableRow extends StatelessWidget {
  const _IncompleteTableRow({
    super.key,
    required this.row,
    required this.zebra,
    required this.isLast,
    required this.busy,
    required this.onComplete,
    required this.onBan,
    required this.onPurge,
  });

  final IncompleteSignupRow row;
  final bool zebra;
  final bool isLast;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onBan;
  final VoidCallback onPurge;

  String get _pendingLabel {
    if (row.isBanned) return 'Desactivado';
    if (row.email == null || row.email!.trim().isEmpty) return 'Sin correo';
    if (!row.emailConfirmed) return 'Correo sin confirmar';
    return 'Falta expediente';
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final err = Theme.of(context).colorScheme.error;
    final pending = _pendingLabel;
    final amberFg = const Color(0xFFD97706);
    final amberBg = theme.surfaceSubtle;
    final chipFg = row.isBanned
        ? err
        : pending == 'Falta expediente' || pending == 'Correo sin confirmar'
            ? amberFg
            : theme.brand;
    final chipBg = row.isBanned
        ? err.withOpacity(0.12)
        : pending == 'Falta expediente' || pending == 'Correo sin confirmar'
            ? amberBg
            : theme.brandContainer;

    final userCell = Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.brandContainer,
          child: Text(
            _initials(row.title),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              if (row.email != null &&
                  row.displayName != null &&
                  row.displayName!.trim().isNotEmpty)
                Text(
                  row.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final pendingChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipFg.withOpacity(0.25)),
      ),
      child: Text(
        pending,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: chipFg,
        ),
      ),
    );

    final actions = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        FilledButton.icon(
          onPressed: busy || row.isBanned ? null : onComplete,
          style: FilledButton.styleFrom(
            backgroundColor: theme.brand,
            foregroundColor: theme.surfaceCard,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: LucideIcon(
            LucideGlyph.fileText,
            size: 14,
            color: theme.surfaceCard,
          ),
          label: Text(
            'Completar expediente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.surfaceCard,
            ),
          ),
        ),
        PopupMenuButton<String>(
          enabled: !busy,
          tooltip: 'Más acciones',
          onSelected: (v) {
            if (v == 'ban') onBan();
            if (v == 'purge') onPurge();
          },
          itemBuilder: (_) => [
            if (!row.isBanned)
              const PopupMenuItem(
                value: 'ban',
                child: Text(OwnerAccountRules.softDeleteActionLabel),
              ),
            const PopupMenuItem(
              value: 'purge',
              child: Text(OwnerAccountRules.hardDeleteActionLabel),
            ),
          ],
          child: Icon(
            Icons.more_vert,
            size: 20,
            color: theme.textSecondary,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: zebra ? theme.tableRowOdd : theme.tableRowEven,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: theme.borderSubtle)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 720;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                userCell,
                const SizedBox(height: 8),
                Row(
                  children: [
                    pendingChip,
                    const Spacer(),
                    Text(
                      formatEsShortDateTime(row.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 4, child: userCell),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: Align(
                alignment: Alignment.centerLeft,
                child: pendingChip,
              )),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  formatEsShortDateTime(row.createdAt),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: theme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? AdminUsersChrome.brand : AdminUsersChrome.cardColor;
    final fg = selected ? const Color(0xFFF8FAFC) : AdminUsersChrome.titleColor;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AdminUsersChrome.brand
                  : AdminUsersChrome.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: enabled ? fg : AdminUsersChrome.muted,
            ),
          ),
        ),
      ),
    );
  }
}

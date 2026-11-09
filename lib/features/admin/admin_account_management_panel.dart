import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/admin/incomplete_signup_row.dart';
import 'package:motolink_pro_app/features/admin/owner_account_delete_dialog.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier_form.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';
import 'package:motolink_pro_app/features/admin/owner_importer_catalog_screen.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_standard_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_users_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_users_filter_models.dart';

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
  _AccountListMode _mode = _AccountListMode.cuentas;
  _IncompleteFilter _incompleteFilter = _IncompleteFilter.todos;
  String? _busyId;
  String? _previewProfileId;
  AdminUserEstadoFilter _estado = AdminUserEstadoFilter.todos;
  AdminUserRolFilter _rol = AdminUserRolFilter.todos;
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
    _searchCtrl.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  ProfileModel? _findProfile(String id) {
    for (final p in _rows) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _consumeAccountDeepLink() {
    final pending = MainShellTabController.consumePendingAccountProfileId();
    if (pending == null || !mounted) return;
    setState(() {
      _mode = _AccountListMode.cuentas;
      _previewProfileId = pending;
      _estado = AdminUserEstadoFilter.todos;
      _rol = AdminUserRolFilter.todos;
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
    if (mode == _AccountListMode.incompletos && !_incompleteLoaded) {
      await _loadIncomplete();
    }
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
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

  List<ProfileModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _rows.where((p) {
      final role = p.role?.trim().toLowerCase();
      switch (_rol) {
        case AdminUserRolFilter.minorista:
          if (role != 'aliado') return false;
        case AdminUserRolFilter.mayorista:
          if (role != 'importador') return false;
        case AdminUserRolFilter.administracion:
          if (role != 'administrador') return false;
        case AdminUserRolFilter.todos:
          break;
      }
      final access = p.accountAccessStatus?.trim();
      switch (_estado) {
        case AdminUserEstadoFilter.pendiente:
          if (p.isDeactivated ||
              (access != AccountAccessStatus.draft &&
                  access != AccountAccessStatus.pendingReview)) {
            return false;
          }
        case AdminUserEstadoFilter.verificado:
          if (p.isDeactivated ||
              access != AccountAccessStatus.active ||
              (role == 'aliado' && p.kycStatus?.trim() != 'aprobado')) {
            return false;
          }
        case AdminUserEstadoFilter.activo:
          if (p.isDeactivated || access != AccountAccessStatus.active) {
            return false;
          }
        case AdminUserEstadoFilter.bloqueado:
          if (!p.isDeactivated && access != AccountAccessStatus.rejected) {
            return false;
          }
        case AdminUserEstadoFilter.todos:
          break;
      }
      if (p.id == _previewProfileId) return true;
      return ownerAccountMatchesQuery(p, q);
    });
    return sortOwnerAccounts(filtered, sort: _sort);
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
            const SizedBox(height: 12),
            if (_canChangeRole(p)) ...[
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busyId == p.id ? null : () => _changeRole(p),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Corregir rol (minorista / mayorista)'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final changed = await OwnerAccountDossierForm.open(
                  context,
                  existing: p,
                  allowAdminRole: widget.viewer.isOwner,
                  canDeleteAccount: _canOperate(p),
                );
                if (changed == true && mounted) await _load();
              },
              child: const Text('Abrir expediente'),
            ),
            ..._previewDangerActions(p),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<String?> _promptNote({
    required String title,
    required String confirmLabel,
  }) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Motivo (visible en la cuenta)…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null || res.length < 3) return null;
    return res;
  }

  Future<void> _changeRole(ProfileModel p) async {
    final roles = <String>[
      'aliado',
      'importador',
      if (widget.viewer.isOwner) 'administrador',
    ];
    final current = p.role?.trim().toLowerCase();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Corregir rol de la cuenta'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Si se registró como mayorista por error (o al revés), '
                'elija el rol correcto.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final role in roles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ProfileRoleLabels.labelEs(role)),
                  subtitle: role == 'administrador'
                      ? null
                      : Text(
                          role == 'aliado'
                              ? 'Tienda minorista'
                              : 'Importador / mayorista',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                  selected: current == role,
                  trailing: current == role
                      ? Icon(Icons.check, color: AppColors.brand)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(role),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (picked == null || picked == p.role?.trim().toLowerCase()) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cambio de rol'),
        content: Text(
          '¿Asignar «${ProfileRoleLabels.labelEs(picked)}» a '
          '${p.businessName ?? p.email ?? 'esta cuenta'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerSetProfileRole(
        profileId: p.id,
        role: picked,
      );
    });
    if (!mounted || !done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rol actualizado a ${ProfileRoleLabels.labelEs(picked)}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _block(ProfileModel p) async {
    final note = await _promptNote(
      title: 'Bloquear cuenta',
      confirmLabel: 'Bloquear',
    );
    if (note == null) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar bloqueo'),
        content: Text(
          'La cuenta no podrá entrar a la app. El historial se conserva.\n\n'
          '${p.businessName ?? p.email ?? p.id}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerSetAccountAccess(
        profileId: p.id,
        status: AccountAccessStatus.rejected,
        note: note,
      );
    });
    if (!mounted || !done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta bloqueada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reactivate(ProfileModel p) async {
    final firstActivate = OwnerAccountRules.canActivateAccess(
      accountAccessStatus: p.accountAccessStatus,
      deactivatedAt: p.deactivatedAt,
    );
    final who = p.businessName ?? p.email ?? 'esta cuenta';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(firstActivate ? 'Activar cuenta' : 'Reactivar cuenta'),
        content: Text(
          firstActivate
              ? '¿Habilitar $who con el expediente ya cargado? '
                  'Podrá entrar sin repetir el registro inicial.'
              : '¿Restaurar el acceso de $who?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(firstActivate ? 'Activar' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerSetAccountAccess(
        profileId: p.id,
        status: AccountAccessStatus.active,
      );
    });
    if (!mounted || !done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          firstActivate ? 'Cuenta activada.' : 'Cuenta reactivada.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deactivate(ProfileModel p) async {
    final note = await showOwnerAccountDeleteDialog(
      context: context,
      profile: p,
      kind: OwnerAccountDeleteKind.soft,
    );
    if (note == null || !mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerDeactivateProfile(
        profileId: p.id,
        note: note,
      );
    });
    if (!mounted || !done) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta dada de baja. Historial y correo se conservan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _hardDelete(ProfileModel p) async {
    final confirm = await showOwnerAccountDeleteDialog(
      context: context,
      profile: p,
      kind: OwnerAccountDeleteKind.hard,
    );
    if (confirm == null || !mounted) return;
    final done = await _runBusy(p, () async {
      await SupabaseService.ownerHardDeleteProfile(
        profileId: p.id,
        confirm: confirm,
      );
    });
    if (!mounted || !done) return;
    if (_previewProfileId == p.id) {
      setState(() => _previewProfileId = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta borrada. El correo quedó libre para reutilizar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Widget> _previewDangerActions(ProfileModel p) {
    if (!_canOperate(p)) return const [];
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      foregroundColor: Colors.red.shade800,
    );
    return [
      const SizedBox(height: 16),
      Text(
        'Cuenta',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 8),
      if (!p.isDeactivated)
        OutlinedButton.icon(
          style: style,
          onPressed: () => _deactivate(p),
          icon: const Icon(Icons.person_off_outlined, size: 18),
          label: const Text(OwnerAccountRules.softDeleteActionLabel),
        ),
      if (!p.isDeactivated) const SizedBox(height: 8),
      OutlinedButton.icon(
        style: style,
        onPressed: () => _hardDelete(p),
        icon: const Icon(Icons.delete_forever_outlined, size: 18),
        label: const Text(OwnerAccountRules.hardDeleteActionLabel),
      ),
      const SizedBox(height: 4),
      Text(
        p.isDeactivated
            ? 'Borrar libera el correo para un registro nuevo.'
            : 'Dar de baja conserva historial. Borrar libera el correo.',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _AccountListMode.cuentas && _loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    if (_mode == _AccountListMode.cuentas && _error != null && _rows.isEmpty) {
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

    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
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
            AdminUsersFilterBar(
              padding: EdgeInsets.zero,
              searchController: _searchCtrl,
              searchHint: 'Buscar por nombre, RIF, correo o teléfono…',
              estado: _estado,
              rol: _rol,
              sort: _sort,
              includeAdminRol: true,
              onSearchChanged: (_) => setState(() => _pageIndex = 0),
              onEstado: (v) => setState(() {
                _estado = v;
                _pageIndex = 0;
              }),
              onRol: (v) => setState(() {
                _rol = v;
                _pageIndex = 0;
              }),
              onSort: (v) => setState(() {
                _sort = v;
                _pageIndex = 0;
              }),
              extraMenus: [
                AdminFilterDropdown(
                  icon: Icons.folder_outlined,
                  placeholder: 'Vista',
                  valueLabel: 'Cuentas',
                  active: false,
                  options: [
                    AdminFilterOption(
                      label: 'Cuentas',
                      selected: true,
                      onSelect: () {},
                    ),
                    AdminFilterOption(
                      label: 'Registro incompleto',
                      selected: false,
                      onSelect: () => _selectMode(_AccountListMode.incompletos),
                    ),
                  ],
                ),
              ],
              trailing: IconButton(
                tooltip: 'Nueva cuenta',
                onPressed: () async {
                  final changed = await OwnerAccountDossierForm.open(
                    context,
                    allowAdminRole: widget.viewer.isOwner,
                  );
                  if (changed == true && mounted) await _load();
                },
                icon: const Icon(Icons.person_add_outlined),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    _rows.isEmpty
                        ? 'No hay cuentas.'
                        : 'Ninguna cuenta coincide con el filtro.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else ...[
              ListPageBar(
                total: filtered.length,
                pageIndex: _pageIndex,
                pageSize: _pageSize,
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
              if (desktop) ...[
                const SizedBox(height: 8),
                _AccountsDesktopTable(
                  rows: page,
                  viewerId: widget.viewer.id,
                  selectedId: _previewProfileId,
                  onSelect: _openAccountPreview,
                  canOperate: _canOperate,
                  canChangeRole: _canChangeRole,
                  showCatalogFor: (p) =>
                      widget.viewer.isOwner &&
                      p.role?.trim().toLowerCase() == 'importador',
                  busyId: _busyId,
                  onEditDossier: (p) async {
                    final changed = await OwnerAccountDossierForm.open(
                      context,
                      existing: p,
                      allowAdminRole: widget.viewer.isOwner,
                      canDeleteAccount: _canOperate(p),
                    );
                    if (changed == true && mounted) await _load();
                  },
                  onChangeRole: _changeRole,
                  onBlock: _block,
                  onReactivate: _reactivate,
                  onDeactivate: _deactivate,
                  onHardDelete: _hardDelete,
                ),
              ] else
                ...page.map(
                  (p) => Padding(
                    key: ValueKey<String>('cuenta-${p.id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AccountCard(
                      profile: p,
                      viewerId: widget.viewer.id,
                      canOperate: _canOperate(p),
                      canChangeRole: _canChangeRole(p),
                      showCatalog: widget.viewer.isOwner &&
                          p.role?.trim().toLowerCase() == 'importador',
                      busy: _busyId == p.id,
                      onTapHeader: () => _openAccountPreview(p),
                      onEditDossier: () async {
                        final changed = await OwnerAccountDossierForm.open(
                          context,
                          existing: p,
                          allowAdminRole: widget.viewer.isOwner,
                          canDeleteAccount: _canOperate(p),
                        );
                        if (changed == true && mounted) await _load();
                      },
                      onChangeRole: () => _changeRole(p),
                      onBlock: () => _block(p),
                      onReactivate: () => _reactivate(p),
                      onDeactivate: () => _deactivate(p),
                      onHardDelete: () => _hardDelete(p),
                    ),
                  ),
                ),
            ],
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
                color: AppColors.card,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () =>
                              setState(() => _previewProfileId = null),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OwnerAccountDossier(
                      profile: preview,
                      isSelf: preview.id == widget.viewer.id,
                    ),
                    const SizedBox(height: 12),
                    if (_canChangeRole(preview)) ...[
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: _busyId == preview.id
                            ? null
                            : () => _changeRole(preview),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label:
                            const Text('Corregir rol (minorista / mayorista)'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () async {
                        final changed = await OwnerAccountDossierForm.open(
                          context,
                          existing: preview,
                          allowAdminRole: widget.viewer.isOwner,
                          canDeleteAccount: _canOperate(preview),
                        );
                        if (changed == true && mounted) await _load();
                      },
                      child: const Text('Abrir expediente'),
                    ),
                    ..._previewDangerActions(preview),
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
    return [
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
            icon: Icons.folder_outlined,
            placeholder: 'Vista',
            valueLabel: 'Registro incompleto',
            active: true,
            options: [
              AdminFilterOption(
                label: 'Cuentas',
                selected: false,
                onSelect: () => _selectMode(_AccountListMode.cuentas),
              ),
              AdminFilterOption(
                label: 'Registro incompleto',
                selected: true,
                onSelect: () {},
              ),
            ],
          ),
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
      const SizedBox(height: 8),
      if (_incompleteLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
      if (_incompleteError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Text(
                _incompleteError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loadIncomplete,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        )
      else if (!_incompleteLoading && filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              _incomplete.isEmpty
                  ? 'No hay registros incompletos.'
                  : 'Ningún registro coincide con la búsqueda.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        )
      else if (filtered.isNotEmpty) ...[
        ListPageBar(
          total: filtered.length,
          pageIndex: _pageIndex,
          pageSize: _pageSize,
          alwaysShow: true,
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
        ...page.map(
          (row) => Padding(
            key: ValueKey<String>('incompleto-${row.userId}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _IncompleteSignupCard(row: row),
          ),
        ),
      ],
    ];
  }

}

class _AccountsDesktopTable extends StatelessWidget {
  const _AccountsDesktopTable({
    required this.rows,
    required this.viewerId,
    required this.selectedId,
    required this.onSelect,
    required this.canOperate,
    required this.canChangeRole,
    required this.showCatalogFor,
    required this.busyId,
    required this.onEditDossier,
    required this.onChangeRole,
    required this.onBlock,
    required this.onReactivate,
    required this.onDeactivate,
    required this.onHardDelete,
  });

  final List<ProfileModel> rows;
  final String viewerId;
  final String? selectedId;
  final ValueChanged<ProfileModel> onSelect;
  final bool Function(ProfileModel) canOperate;
  final bool Function(ProfileModel) canChangeRole;
  final bool Function(ProfileModel) showCatalogFor;
  final String? busyId;
  final ValueChanged<ProfileModel> onEditDossier;
  final ValueChanged<ProfileModel> onChangeRole;
  final ValueChanged<ProfileModel> onBlock;
  final ValueChanged<ProfileModel> onReactivate;
  final ValueChanged<ProfileModel> onDeactivate;
  final ValueChanged<ProfileModel> onHardDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Material(
              color: selectedId == rows[i].id
                  ? AppColors.brandBlueContainer
                  : Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(rows[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          rows[i].businessName?.trim().isNotEmpty == true
                              ? rows[i].businessName!.trim()
                              : (rows[i].email ?? 'Sin nombre'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          ProfileRoleLabels.labelEs(rows[i].role),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          OwnerAccountRules.statusLabelEs(
                            role: rows[i].role,
                            accountAccessStatus: rows[i].accountAccessStatus,
                            deactivatedAt: rows[i].deactivatedAt,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Expediente',
                        onPressed: canOperate(rows[i])
                            ? () => onEditDossier(rows[i])
                            : null,
                        icon: const Icon(Icons.folder_open_outlined, size: 20),
                      ),
                      if (showCatalogFor(rows[i]))
                        IconButton(
                          tooltip: 'Catálogo',
                          onPressed: () => OwnerImporterCatalogScreen.open(
                            context,
                            importerId: rows[i].id,
                            importerName:
                                rows[i].businessName?.trim().isNotEmpty == true
                                    ? rows[i].businessName!.trim()
                                    : (rows[i].email ?? 'Mayorista'),
                          ),
                          icon: const Icon(Icons.inventory_2_outlined, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.profile,
    required this.viewerId,
    required this.canOperate,
    required this.canChangeRole,
    required this.showCatalog,
    required this.busy,
    required this.onEditDossier,
    required this.onChangeRole,
    required this.onBlock,
    required this.onReactivate,
    required this.onDeactivate,
    required this.onHardDelete,
    this.onTapHeader,
  });

  final ProfileModel profile;
  final String viewerId;
  final bool canOperate;
  final bool canChangeRole;
  final bool showCatalog;
  final bool busy;
  final VoidCallback onEditDossier;
  final VoidCallback onChangeRole;
  final VoidCallback onBlock;
  final VoidCallback onReactivate;
  final VoidCallback onDeactivate;
  final VoidCallback onHardDelete;
  final VoidCallback? onTapHeader;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final status = OwnerAccountRules.statusLabelEs(
      role: profile.role,
      accountAccessStatus: profile.accountAccessStatus,
      deactivatedAt: profile.deactivatedAt,
    );
    final isSelf = profile.id == widget.viewerId;
    final subtitle = [
      ProfileRoleLabels.labelEs(profile.role),
      if (profile.createdAt != null)
        'Alta ${formatEsShortDate(profile.createdAt!)}',
      if (profile.email != null) profile.email,
      if (profile.phone != null) profile.phone,
      if (isSelf) 'Su cuenta',
    ].join(' · ');

    if (widget.onTapHeader != null) {
      return Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTapHeader,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.businessName?.trim().isNotEmpty == true
                            ? profile.businessName!.trim()
                            : (profile.email ?? 'Sin nombre'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: status, deactivated: profile.isDeactivated),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  profile.businessName?.trim().isNotEmpty == true
                      ? profile.businessName!.trim()
                      : (profile.email ?? 'Sin nombre'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(label: status, deactivated: profile.isDeactivated),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          children: [
            OwnerAccountDossier(
              profile: profile,
              isSelf: isSelf,
            ),
            if (widget.canOperate ||
                widget.canChangeRole ||
                widget.showCatalog) ...[
              const SizedBox(height: 12),
              if (widget.busy)
                const LinearProgressIndicator(color: AppColors.brand)
              else
                _AccountActions(
                  showCatalog: widget.showCatalog,
                  canOperate: widget.canOperate,
                  canChangeRole: widget.canChangeRole,
                  blocked: profile.isDeactivated ||
                      profile.accountAccessStatus?.trim() ==
                          AccountAccessStatus.rejected,
                  canActivate: OwnerAccountRules.canActivateAccess(
                    accountAccessStatus: profile.accountAccessStatus,
                    deactivatedAt: profile.deactivatedAt,
                  ),
                  onOpenCatalog: () => OwnerImporterCatalogScreen.open(
                    context,
                    importerId: profile.id,
                    importerName:
                        profile.businessName?.trim().isNotEmpty == true
                            ? profile.businessName!.trim()
                            : (profile.email ?? 'Mayorista'),
                  ),
                  onEditDossier: widget.onEditDossier,
                  onChangeRole: widget.onChangeRole,
                  onBlock: widget.onBlock,
                  onReactivate: widget.onReactivate,
                  onDeactivate: widget.onDeactivate,
                  onHardDelete: widget.onHardDelete,
                  deactivated: profile.isDeactivated,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({
    required this.showCatalog,
    required this.canOperate,
    required this.canChangeRole,
    required this.blocked,
    required this.deactivated,
    required this.canActivate,
    required this.onOpenCatalog,
    required this.onEditDossier,
    required this.onChangeRole,
    required this.onBlock,
    required this.onReactivate,
    required this.onDeactivate,
    required this.onHardDelete,
  });

  final bool showCatalog;
  final bool canOperate;
  final bool canChangeRole;
  final bool blocked;
  final bool deactivated;
  final bool canActivate;
  final VoidCallback onOpenCatalog;
  final VoidCallback onEditDossier;
  final VoidCallback onChangeRole;
  final VoidCallback onBlock;
  final VoidCallback onReactivate;
  final VoidCallback onDeactivate;
  final VoidCallback onHardDelete;

  static ButtonStyle get _wide => OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        visualDensity: VisualDensity.standard,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCatalog)
          OutlinedButton.icon(
            style: _wide,
            onPressed: onOpenCatalog,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Ver catálogo'),
          ),
        if (showCatalog && (canOperate || canChangeRole))
          const SizedBox(height: 8),
        if (canOperate) ...[
          OutlinedButton(
            style: _wide,
            onPressed: onEditDossier,
            child: const Text('Expediente'),
          ),
          const SizedBox(height: 8),
        ],
        if (canChangeRole) ...[
          OutlinedButton(
            style: _wide,
            onPressed: onChangeRole,
            child: const Text('Cambiar rol'),
          ),
          const SizedBox(height: 8),
        ],
        if (canOperate) ...[
          if (canActivate || blocked)
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: onReactivate,
              child: Text(canActivate ? 'Activar' : 'Reactivar'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: _wide,
                    onPressed: onBlock,
                    child: const Text('Bloquear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: _wide.copyWith(
                      foregroundColor: WidgetStatePropertyAll(
                        Colors.red.shade700,
                      ),
                    ),
                    onPressed: onDeactivate,
                    child: const Text(OwnerAccountRules.softDeleteActionLabel),
                  ),
                ),
              ],
            ),
          if (canActivate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: _wide,
                    onPressed: onBlock,
                    child: const Text('Bloquear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: _wide.copyWith(
                      foregroundColor: WidgetStatePropertyAll(
                        Colors.red.shade700,
                      ),
                    ),
                    onPressed: onDeactivate,
                    child: const Text(OwnerAccountRules.softDeleteActionLabel),
                  ),
                ),
              ],
            ),
          ],
          if (blocked && !deactivated) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              style: _wide.copyWith(
                foregroundColor: WidgetStatePropertyAll(
                  Colors.red.shade700,
                ),
              ),
              onPressed: onDeactivate,
              child: const Text(OwnerAccountRules.softDeleteActionLabel),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: _wide.copyWith(
              foregroundColor: WidgetStatePropertyAll(
                Colors.red.shade800,
              ),
            ),
            onPressed: onHardDelete,
            icon: const Icon(Icons.delete_forever_outlined, size: 18),
            label: const Text(OwnerAccountRules.hardDeleteActionLabel),
          ),
        ],
      ],
    );
  }
}

class _IncompleteSignupCard extends StatefulWidget {
  const _IncompleteSignupCard({required this.row});

  final IncompleteSignupRow row;

  @override
  State<_IncompleteSignupCard> createState() => _IncompleteSignupCardState();
}

class _IncompleteSignupCardState extends State<_IncompleteSignupCard> {
  Future<void> _copyEmail() async {
    final email = widget.row.email;
    if (email == null || email.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Correo copiado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final status = row.email == null
        ? 'Sin correo'
        : row.emailConfirmed
            ? 'Sin perfil'
            : 'Correo sin confirmar';
    final subtitle = [
      if (row.displayName != null && row.email != null) row.email,
      if (row.phone != null) row.phone,
      if (row.createdAt != null) 'Registro ${formatEsShortDateTime(row.createdAt)}',
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(label: status, deactivated: false),
            ],
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
          children: [
            _IncompleteLine(label: 'Correo', value: row.email ?? 'No indicado'),
            _IncompleteLine(label: 'Teléfono', value: row.phone ?? 'No indicado'),
            _IncompleteLine(
              label: 'Registro',
              value: formatEsShortDateTime(row.createdAt),
            ),
            _IncompleteLine(
              label: 'Último ingreso',
              value: row.lastSignInAt == null
                  ? 'Nunca ingresó'
                  : formatEsShortDateTime(row.lastSignInAt),
            ),
            _IncompleteLine(
              label: 'Correo confirmado',
              value: row.emailConfirmed
                  ? formatEsShortDateTime(row.emailConfirmedAt)
                  : 'Pendiente',
            ),
            if (row.email != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _copyEmail,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copiar correo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncompleteLine extends StatelessWidget {
  const _IncompleteLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.textPrimary),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.deactivated});

  final String label;
  final bool deactivated;

  @override
  Widget build(BuildContext context) {
    final color = deactivated
        ? Colors.red.shade700
        : label == 'Activa'
            ? AppColors.successGreen
            : AppColors.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

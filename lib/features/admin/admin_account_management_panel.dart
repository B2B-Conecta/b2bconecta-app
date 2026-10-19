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
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';

enum _AccountListMode { cuentas, incompletos }

enum _AccountRoleFilter { todos, aliados, importadores, administracion }

enum _AccountStateFilter { todos, activas, borrador, revision, bloqueadas, eliminadas }

enum _IncompleteFilter { todos, sinConfirmar, confirmados }

/// Administración: alta, expediente, bloqueo, baja lógica y borrado de Auth.
/// Cambiar rol y el catálogo del mayorista siguen reservados al propietario.
class AdminAccountManagementPanel extends StatefulWidget {
  const AdminAccountManagementPanel({
    super.key,
    required this.viewer,
  });

  final ProfileModel viewer;

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
  _AccountRoleFilter _roleFilter = _AccountRoleFilter.todos;
  _AccountStateFilter _stateFilter = _AccountStateFilter.todos;
  final _searchCtrl = TextEditingController();
  final _listScroll = ScrollController();
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _pageIndex = 0));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listScroll.dispose();
    super.dispose();
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
    return _incomplete.where((row) {
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
    }).toList();
  }

  List<ProfileModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _rows.where((p) {
      final role = p.role?.trim().toLowerCase();
      switch (_roleFilter) {
        case _AccountRoleFilter.aliados:
          if (role != 'aliado') return false;
        case _AccountRoleFilter.importadores:
          if (role != 'importador') return false;
        case _AccountRoleFilter.administracion:
          if (role != 'administrador') return false;
        case _AccountRoleFilter.todos:
          break;
      }
      final access = p.accountAccessStatus?.trim();
      switch (_stateFilter) {
        case _AccountStateFilter.activas:
          if (p.isDeactivated || access != AccountAccessStatus.active) {
            return false;
          }
        case _AccountStateFilter.borrador:
          if (p.isDeactivated || access != AccountAccessStatus.draft) {
            return false;
          }
        case _AccountStateFilter.revision:
          if (p.isDeactivated || access != AccountAccessStatus.pendingReview) {
            return false;
          }
        case _AccountStateFilter.bloqueadas:
          if (p.isDeactivated || access != AccountAccessStatus.rejected) {
            return false;
          }
        case _AccountStateFilter.eliminadas:
          if (!p.isDeactivated) return false;
        case _AccountStateFilter.todos:
          break;
      }
      return ownerAccountMatchesQuery(p, q);
    }).toList();
  }

  bool _canChangeRole(ProfileModel p) => OwnerAccountRules.canManageTarget(
        viewerIsOwner: widget.viewer.isOwner,
        viewerId: widget.viewer.id,
        targetId: p.id,
        targetIsOwner: p.isOwner,
      );

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
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Cambiar rol',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            for (final role in ['aliado', 'importador', 'administrador'])
              ListTile(
                title: Text(ProfileRoleLabels.labelEs(role)),
                selected: p.role?.trim().toLowerCase() == role,
                onTap: () => Navigator.of(ctx).pop(role),
              ),
          ],
        ),
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
        content: Text('Cuenta deshabilitada (baja lógica).'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta borrada. El correo quedó libre.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    return RefreshIndicator(
      onRefresh: _mode == _AccountListMode.incompletos ? _loadIncomplete : _load,
      color: AppColors.brand,
      child: ListView(
        controller: _listScroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedFilterBar(
            labels: const ['Cuentas', 'Registro incompleto'],
            selectedIndex: _mode == _AccountListMode.cuentas ? 0 : 1,
            onSelected: (index) => _selectMode(
              index == 0
                  ? _AccountListMode.cuentas
                  : _AccountListMode.incompletos,
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == _AccountListMode.incompletos)
            ..._incompleteSection()
          else ...[
          Text(
            'Ficha completa (correo, teléfono y datos fiscales). '
            'Puede crear cuentas y cargarles el expediente. '
            'Eliminar desactiva la cuenta y conserva el historial. '
            'Borrar definitivo quita la cuenta y libera el correo. '
            'Si tiene pedidos, se avisa antes y puede revisarlos.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () async {
              final changed = await OwnerAccountDossierForm.open(
                context,
                allowAdminRole: widget.viewer.isOwner,
              );
              if (changed == true && mounted) await _load();
            },
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Nueva cuenta'),
          ),
          const SizedBox(height: 12),
          SegmentedFilterBar(
            labels: [
              for (final f in _AccountRoleFilter.values) _roleFilterLabel(f),
            ],
            selectedIndex: _AccountRoleFilter.values.indexOf(_roleFilter),
            onSelected: (index) => setState(() {
              _roleFilter = _AccountRoleFilter.values[index];
              _pageIndex = 0;
            }),
          ),
          SegmentedFilterBar(
            labels: [
              for (final f in _AccountStateFilter.values) _stateFilterLabel(f),
            ],
            selectedIndex: _AccountStateFilter.values.indexOf(_stateFilter),
            onSelected: (index) => setState(() {
              _stateFilter = _AccountStateFilter.values[index];
              _pageIndex = 0;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, RIF, correo o teléfono…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                  onEditDossier: () async {
                    final changed = await OwnerAccountDossierForm.open(
                      context,
                      existing: p,
                      allowAdminRole: widget.viewer.isOwner,
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
  }

  List<Widget> _incompleteSection() {
    final filtered = _incompleteFiltered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    return [
      Text(
        'Personas que crearon la cuenta y no guardaron la ficha del negocio. '
        'El correo sirve para contactarlas. No tienen avisos dentro de la app.',
        style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      SegmentedFilterBar(
        labels: const ['Todos', 'Sin confirmar', 'Confirmados'],
        selectedIndex: _IncompleteFilter.values.indexOf(_incompleteFilter),
        onSelected: (index) => setState(() {
          _incompleteFilter = _IncompleteFilter.values[index];
          _pageIndex = 0;
        }),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, correo o teléfono…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      const SizedBox(height: 12),
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

  static String _roleFilterLabel(_AccountRoleFilter f) {
    return switch (f) {
      _AccountRoleFilter.todos => 'Todos',
      _AccountRoleFilter.aliados => 'Tiendas minoristas',
      _AccountRoleFilter.importadores => 'Importadores',
      _AccountRoleFilter.administracion => 'Administración',
    };
  }

  static String _stateFilterLabel(_AccountStateFilter f) {
    return switch (f) {
      _AccountStateFilter.todos => 'Todos',
      _AccountStateFilter.activas => 'Activas',
      _AccountStateFilter.borrador => 'Borrador',
      _AccountStateFilter.revision => 'Revisión',
      _AccountStateFilter.bloqueadas => 'Bloqueadas',
      _AccountStateFilter.eliminadas => 'Eliminadas',
    };
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
              [
                ProfileRoleLabels.labelEs(profile.role),
                if (profile.email != null) profile.email,
                if (profile.phone != null) profile.phone,
                if (isSelf) 'Su cuenta',
              ].join(' · '),
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
                    child: const Text('Eliminar'),
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
                    child: const Text('Eliminar'),
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
              child: const Text('Eliminar'),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            style: _wide.copyWith(
              foregroundColor: WidgetStatePropertyAll(
                Colors.red.shade800,
              ),
            ),
            onPressed: onHardDelete,
            child: const Text('Borrar definitivo'),
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

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

enum _AccountRoleFilter { todos, aliados, importadores, administracion }

enum _AccountStateFilter { todos, activas, bloqueadas, eliminadas }

/// Solo owner: roles, bloqueo y baja lógica de cuentas.
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
  bool _loading = true;
  String? _error;
  String? _busyId;
  _AccountRoleFilter _roleFilter = _AccountRoleFilter.todos;
  _AccountStateFilter _stateFilter = _AccountStateFilter.todos;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
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
      final rows = await SupabaseService.ownerListProfiles();
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
      switch (_stateFilter) {
        case _AccountStateFilter.activas:
          if (p.isDeactivated ||
              p.accountAccessStatus?.trim() == AccountAccessStatus.rejected) {
            return false;
          }
        case _AccountStateFilter.bloqueadas:
          if (p.isDeactivated) return false;
          if (p.accountAccessStatus?.trim() != AccountAccessStatus.rejected) {
            return false;
          }
        case _AccountStateFilter.eliminadas:
          if (!p.isDeactivated) return false;
        case _AccountStateFilter.todos:
          break;
      }
      if (q.isEmpty) return true;
      final name = (p.businessName ?? '').toLowerCase();
      final rif = (p.rif ?? '').toLowerCase();
      final email = (p.email ?? '').toLowerCase();
      return name.contains(q) || rif.contains(q) || email.contains(q);
    }).toList();
  }

  bool _canManage(ProfileModel p) => OwnerAccountRules.canManageTarget(
        viewerIsOwner: widget.viewer.isOwner,
        viewerId: widget.viewer.id,
        targetId: p.id,
        targetIsOwner: p.isOwner,
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivar cuenta'),
        content: Text(
          '¿Restaurar el acceso de ${p.businessName ?? p.email ?? 'esta cuenta'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reactivar'),
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
      const SnackBar(
        content: Text('Cuenta reactivada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deactivate(ProfileModel p) async {
    final note = await _promptNote(
      title: 'Eliminar cuenta',
      confirmLabel: 'Continuar',
    );
    if (note == null) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar baja'),
        content: Text(
          'Es una baja lógica: la cuenta deja de entrar, no se borra el usuario '
          'ni el historial de pedidos.\n\n'
          '${p.businessName ?? p.email ?? p.id}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    if (_error != null && _rows.isEmpty) {
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
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Roles, bloqueo y baja de cuentas. El historial de pedidos se conserva.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _AccountRoleFilter.values)
                ChoiceChip(
                  label: Text(_roleFilterLabel(f)),
                  selected: _roleFilter == f,
                  onSelected: (_) => setState(() => _roleFilter = f),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _AccountStateFilter.values)
                ChoiceChip(
                  label: Text(_stateFilterLabel(f)),
                  selected: _stateFilter == f,
                  onSelected: (_) => setState(() => _stateFilter = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, RIF o correo…',
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
          else
            ...filtered.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AccountCard(
                  profile: p,
                  viewerId: widget.viewer.id,
                  canManage: _canManage(p),
                  busy: _busyId == p.id,
                  onChangeRole: () => _changeRole(p),
                  onBlock: () => _block(p),
                  onReactivate: () => _reactivate(p),
                  onDeactivate: () => _deactivate(p),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _roleFilterLabel(_AccountRoleFilter f) {
    return switch (f) {
      _AccountRoleFilter.todos => 'Todos',
      _AccountRoleFilter.aliados => 'Aliados',
      _AccountRoleFilter.importadores => 'Importadores',
      _AccountRoleFilter.administracion => 'Administración',
    };
  }

  static String _stateFilterLabel(_AccountStateFilter f) {
    return switch (f) {
      _AccountStateFilter.todos => 'Todos los estados',
      _AccountStateFilter.activas => 'Activas',
      _AccountStateFilter.bloqueadas => 'Bloqueadas',
      _AccountStateFilter.eliminadas => 'Eliminadas',
    };
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.profile,
    required this.viewerId,
    required this.canManage,
    required this.busy,
    required this.onChangeRole,
    required this.onBlock,
    required this.onReactivate,
    required this.onDeactivate,
  });

  final ProfileModel profile;
  final String viewerId;
  final bool canManage;
  final bool busy;
  final VoidCallback onChangeRole;
  final VoidCallback onBlock;
  final VoidCallback onReactivate;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final status = OwnerAccountRules.statusLabelEs(
      role: profile.role,
      accountAccessStatus: profile.accountAccessStatus,
      deactivatedAt: profile.deactivatedAt,
    );
    final isSelf = profile.id == viewerId;
    final note = profile.accountReviewNote?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 6),
            Text(
              [
                ProfileRoleLabels.labelEs(profile.role),
                if (profile.email != null) profile.email,
                if (profile.rif != null) profile.rif,
                if (isSelf) 'Su cuenta',
              ].join(' · '),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
            if (canManage) ...[
              const SizedBox(height: 12),
              if (busy)
                const LinearProgressIndicator(color: AppColors.brand)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: onChangeRole,
                      child: const Text('Cambiar rol'),
                    ),
                    if (profile.isDeactivated ||
                        profile.accountAccessStatus?.trim() ==
                            AccountAccessStatus.rejected)
                      FilledButton(
                        onPressed: onReactivate,
                        child: const Text('Reactivar'),
                      )
                    else ...[
                      OutlinedButton(
                        onPressed: onBlock,
                        child: const Text('Bloquear'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        onPressed: onDeactivate,
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ],
                ),
            ],
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

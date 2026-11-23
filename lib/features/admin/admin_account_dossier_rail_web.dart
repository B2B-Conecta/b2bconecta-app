import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/admin/admin_entrepreneur_badge.dart';
import 'package:motolink_pro_app/features/admin/admin_published_catalogs_section.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier.dart';
import 'package:motolink_pro_app/features/admin/owner_account_kyc_dossier_section.dart';
import 'package:motolink_pro_app/features/admin/owner_entrepreneur_control_panel.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

/// Expediente de Cuentas solo en el panel de escritorio.
class AdminAccountDossierRailWeb extends StatelessWidget {
  const AdminAccountDossierRailWeb({
    super.key,
    required this.profile,
    required this.isSelf,
    required this.viewerRole,
    required this.canChangeRole,
    required this.busy,
    required this.onClose,
    required this.onSetRole,
    required this.onChanged,
    this.onDeactivate,
    this.onHardDelete,
    this.onEnable,
  });

  final ProfileModel profile;
  final bool isSelf;
  final String? viewerRole;
  final bool canChangeRole;
  final bool busy;
  final VoidCallback onClose;
  final Future<void> Function(String role) onSetRole;
  final VoidCallback onChanged;
  final VoidCallback? onDeactivate;
  final VoidCallback? onHardDelete;
  final VoidCallback? onEnable;

  bool get _isB2b {
    final role = profile.role?.trim().toLowerCase();
    return role == 'aliado' || role == 'importador';
  }

  String get _listRoleLabel {
    if (profile.isAdministrador) {
      return profile.isOwner ? 'Super Admin' : 'Admin';
    }
    if (profile.isImportador) return 'Proveedor';
    return 'Tienda minorista';
  }

  String get _dossierRoleLabel {
    if (profile.isEntrepreneurRetailer) {
      return 'Tienda minorista · Emprendedor';
    }
    if (profile.isImportador) return 'Proveedor';
    if (profile.isAliado) return 'Tienda minorista';
    return ProfileRoleLabels.labelEs(profile.role);
  }

  String get _statusLabel {
    if (profile.accountAccessStatus == AccountAccessStatus.pendingReview) {
      return 'En revisión';
    }
    if (profile.deactivatedAt != null) return 'Inactivo';
    final status = profile.accountAccessStatus?.trim();
    if (status == null ||
        status.isEmpty ||
        status == AccountAccessStatus.active) {
      return 'Activo';
    }
    return 'Inactivo';
  }

  bool get _statusActive =>
      _statusLabel == 'Activo' &&
      profile.accountAccessStatus != AccountAccessStatus.pendingReview;

  bool get _accessEnabled {
    if (profile.deactivatedAt != null) return false;
    final access = profile.accountAccessStatus?.trim();
    return access == null ||
        access.isEmpty ||
        access == AccountAccessStatus.active;
  }

  bool get _readyToEnable {
    if (profile.deactivatedAt != null || _accessEnabled) return false;
    final access = profile.accountAccessStatus?.trim();
    return access == AccountAccessStatus.draft ||
        access == AccountAccessStatus.pendingReview;
  }

  String get _help {
    if (profile.isEntrepreneurRetailer) {
      return 'Programa Minorista-Emprendedor: plazos de primera compra y documentación diferida. En el listado se ve como Tienda minorista con el sello Emprendedor.';
    }
    if (profile.isImportador) {
      return 'Proveedor con catálogo propio. En el listado se muestra como Proveedor.';
    }
    return 'Tienda que compra en el catálogo. En el listado se muestra como Tienda minorista.';
  }

  Future<void> _openCatalog(BuildContext context) async {
    final theme = B2BThemeExtension.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = size.width >= 1008 ? 960.0 : size.width - 48;
    final name = profile.businessName?.trim().isNotEmpty == true
        ? profile.businessName!.trim()
        : (profile.email ?? 'Proveedor');
    await showDialog<void>(
      context: context,
      builder: (ctx) {
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
                focusImporter: ImporterOption(
                  id: profile.id,
                  businessName: name,
                  estado: profile.estado,
                  ciudad: profile.ciudad,
                ),
                onCloseFocus: () => Navigator.pop(ctx),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _accountName {
    final business = profile.businessName?.trim();
    if (business != null && business.isNotEmpty) return business;
    final email = profile.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'esta cuenta';
  }

  Future<void> _explain(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String body,
    required LucideGlyph glyph,
  }) {
    final theme = B2BThemeExtension.of(context);
    return UnifiedActionDialog.show<void>(
      context: context,
      builder: (ctx) => UnifiedActionDialog(
        title: title,
        subtitle: subtitle,
        glyph: glyph,
        tone: UnifiedActionTone.info,
        profile: profile,
        primaryLabel: 'Entendido',
        cancelLabel: 'Cerrar',
        onPrimary: () => Navigator.of(ctx).pop(),
        body: Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: theme.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmRoleChange(
    BuildContext context, {
    required String nextLabel,
    required String role,
  }) async {
    final theme = B2BThemeExtension.of(context);
    final who = _accountName;
    final from = _dossierRoleLabel;
    final ok = await UnifiedActionDialog.show<bool>(
      context: context,
      builder: (ctx) => UnifiedActionDialog(
        title: 'Cambiar rol de la cuenta',
        subtitle: '«$who» pasará de $from a $nextLabel.',
        glyph: LucideGlyph.arrowLeftRight,
        tone: UnifiedActionTone.warning,
        profile: profile,
        primaryLabel: 'Cambiar a $nextLabel',
        onPrimary: () => Navigator.of(ctx).pop(true),
        body: Text(
          profile.isEntrepreneurRetailer
              ? 'El listado y los permisos pasan al nuevo rol. El historial de pedidos se conserva. Esta cuenta sigue marcada en el programa Minorista-Emprendedor hasta completar la verificación.'
              : 'El listado, el catálogo y los permisos pasan al nuevo rol. El historial de pedidos se conserva.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: theme.textSecondary,
          ),
        ),
      ),
    );
    if (ok == true) {
      await onSetRole(role);
      return true;
    }
    return false;
  }

  Future<void> _onSegment(BuildContext context, _AccountSegment segment) async {
    if (busy) return;
    final who = _accountName;
    if (segment == _AccountSegment.entrepreneur) {
      if (profile.isEntrepreneurRetailer) return;
      await _explain(
        context,
        title: 'Programa solo en el alta',
        subtitle: '«$who» no está en Minorista-Emprendedor.',
        glyph: LucideGlyph.rocket,
        body:
            'Este programa se asigna al crear la cuenta, con plazos de primera compra y documentación diferida. No se puede agregar después. Desde este expediente puedes cambiar el rol entre tienda minorista y proveedor.',
      );
      return;
    }
    if (segment == _AccountSegment.minorista) {
      if (profile.isEntrepreneurRetailer && profile.isAliado) {
        await _explain(
          context,
          title: 'Sigue en el programa',
          subtitle: '«$who» ya es Minorista-Emprendedor.',
          glyph: LucideGlyph.rocket,
          body:
              'El sello del listado se mantiene hasta completar la verificación. Desde aquí no se quita el programa; solo puedes confirmar el rol de tienda minorista o pasarlo a proveedor.',
        );
        return;
      }
      if (profile.isAliado) return;
      await _confirmRoleChange(
        context,
        nextLabel: 'Tienda minorista',
        role: 'aliado',
      );
      return;
    }
    if (profile.isImportador) return;
    await _confirmRoleChange(
      context,
      nextLabel: 'Proveedor',
      role: 'importador',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final name = profile.businessName?.trim().isNotEmpty == true
        ? profile.businessName!.trim()
        : (profile.email ?? 'Sin nombre');
    final showRole = _isB2b && canChangeRole;
    final pending =
        profile.accountAccessStatus == AccountAccessStatus.pendingReview;

    return Material(
      color: AdminUsersChrome.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            theme: theme,
            name: name,
            roleLabel: _listRoleLabel,
            entrepreneur: profile.isEntrepreneurRetailer,
            statusLabel: _statusLabel,
            statusActive: _statusActive,
            pending: pending,
            onClose: onClose,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                OwnerAccountDossier(
                  profile: profile,
                  isSelf: isSelf,
                  roleLabel: _dossierRoleLabel,
                ),
                OwnerEntrepreneurControlPanel(
                  profile: profile,
                  onChanged: onChanged,
                  showDocuments: false,
                  showAccountActions: false,
                ),
                OwnerAccountKycDossierSection(
                  profile: profile,
                  viewerRole: viewerRole,
                  onChanged: onChanged,
                  entrepreneurRequirements: profile.isEntrepreneurRetailer,
                ),
                if (profile.isImportador) ...[
                  const SizedBox(height: 16),
                  _CatalogLink(onPressed: () => _openCatalog(context)),
                ],
                if (showRole)
                  _RoleSelector(
                    theme: theme,
                    entrepreneur: profile.isEntrepreneurRetailer,
                    importador: profile.isImportador,
                    busy: busy,
                    help: _help,
                    onSelect: (segment) => _onSegment(context, segment),
                  ),
                if (_isB2b) ...[
                  const SizedBox(height: 18),
                  _EnableAccountBar(
                    theme: theme,
                    ready: _readyToEnable,
                    enabled: _accessEnabled,
                    busy: busy,
                    onEnable: onEnable,
                  ),
                ],
                if (onDeactivate != null || onHardDelete != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Cuenta',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onDeactivate != null)
                        OutlinedButton.icon(
                          onPressed: busy ? null : onDeactivate,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.textPrimary,
                            side: BorderSide(color: theme.borderStrong),
                          ),
                          icon: LucideIcon(
                            LucideGlyph.userMinus,
                            size: 16,
                            color: theme.textSecondary,
                          ),
                          label: const Text('Desactivar'),
                        ),
                      if (onHardDelete != null)
                        OutlinedButton.icon(
                          onPressed: busy ? null : onHardDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withOpacity(0.45),
                            ),
                          ),
                          icon: LucideIcon(
                            LucideGlyph.trash2,
                            size: 16,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          label: const Text('Purgar cuenta'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnableAccountBar extends StatelessWidget {
  const _EnableAccountBar({
    required this.theme,
    required this.ready,
    required this.enabled,
    required this.busy,
    required this.onEnable,
  });

  final B2BThemeExtension theme;
  final bool ready;
  final bool enabled;
  final bool busy;
  final VoidCallback? onEnable;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.successBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.successFg.withOpacity(0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              LucideIcon(LucideGlyph.circleCheck, size: 16, color: theme.successFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cuenta habilitada',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.successFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canTap = ready && !busy && onEnable != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: canTap ? onEnable : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.brand,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            disabledBackgroundColor: theme.surfaceSubtle,
            disabledForegroundColor: theme.textMuted,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : LucideIcon(
                  LucideGlyph.circlePlay,
                  size: 16,
                  color: canTap
                      ? Theme.of(context).colorScheme.onPrimary
                      : theme.textMuted,
                ),
          label: const Text(
            'Habilitar cuenta',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          canTap
              ? 'Activa el acceso de esta cuenta ya aprobada. El estado se actualiza al confirmar.'
              : 'Disponible cuando la cuenta está aprobada y aún no tiene acceso.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: theme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CatalogLink extends StatelessWidget {
  const _CatalogLink({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: B2BBrandHero.start,
        backgroundColor: theme.inputFill,
        minimumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(color: theme.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(theme.brandContainer),
      ),
      icon: const LucideIcon(
        LucideGlyph.store,
        size: 15,
        color: B2BBrandHero.start,
      ),
      label: const Text('Ver catálogo del proveedor'),
    );
  }
}

enum _AccountSegment { minorista, entrepreneur, mayorista }

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.name,
    required this.roleLabel,
    required this.entrepreneur,
    required this.statusLabel,
    required this.statusActive,
    required this.pending,
    required this.onClose,
  });

  final B2BThemeExtension theme;
  final String name;
  final String roleLabel;
  final bool entrepreneur;
  final String statusLabel;
  final bool statusActive;
  final bool pending;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final statusBg = pending
        ? theme.warningBg
        : (statusActive ? theme.successBg : theme.surfaceSubtle);
    final statusFg = pending
        ? theme.warningFg
        : (statusActive ? theme.successFg : theme.textSecondary);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onClose,
                  icon: LucideIcon(
                    LucideGlyph.close,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Chip(label: roleLabel, bg: theme.surfaceSubtle, fg: theme.textPrimary),
                if (entrepreneur) const AdminEntrepreneurBadge(compact: true),
                _Chip(label: statusLabel, bg: statusBg, fg: statusFg),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.theme,
    required this.entrepreneur,
    required this.importador,
    required this.busy,
    required this.help,
    required this.onSelect,
  });

  final B2BThemeExtension theme;
  final bool entrepreneur;
  final bool importador;
  final bool busy;
  final String help;
  final ValueChanged<_AccountSegment> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = entrepreneur
        ? _AccountSegment.entrepreneur
        : (importador ? _AccountSegment.mayorista : _AccountSegment.minorista);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.borderSubtle)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Rol de la cuenta',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Segment(
                label: 'Minorista',
                selected: selected == _AccountSegment.minorista,
                enabled: !busy,
                onTap: () => onSelect(_AccountSegment.minorista),
              ),
              _Segment(
                label: 'Minorista-Emprendedor',
                selected: selected == _AccountSegment.entrepreneur,
                enabled: !busy,
                onTap: () => onSelect(_AccountSegment.entrepreneur),
              ),
              _Segment(
                label: 'Mayorista',
                selected: selected == _AccountSegment.mayorista,
                enabled: !busy,
                onTap: () => onSelect(_AccountSegment.mayorista),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            help,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: theme.textSecondary,
            ),
          ),
          if (busy) ...[
            const SizedBox(height: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: B2BBrandHero.start,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
    final theme = B2BThemeExtension.of(context);
    final bg = selected ? B2BBrandHero.start : theme.inputFill;
    final fg = selected ? B2BBrandHero.foreground : theme.textPrimary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? B2BBrandHero.start : theme.borderStrong,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: enabled ? fg : theme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

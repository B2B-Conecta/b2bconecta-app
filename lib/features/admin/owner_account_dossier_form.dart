import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/owner_account_create_rules.dart';
import 'package:motolink_pro_app/features/admin/account_action_dialogs.dart';
import 'package:motolink_pro_app/features/admin/delete_user_dialog.dart';
import 'package:motolink_pro_app/features/admin/owner_account_docs_section.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

/// Alta de cuenta o edición del expediente fiscal y documentos.
/// Crear otra cuenta de administración solo si [allowAdminRole] (propietario).
class OwnerAccountDossierForm extends StatefulWidget {
  const OwnerAccountDossierForm({
    super.key,
    this.existing,
    this.allowAdminRole = false,
    this.canDeleteAccount = false,
    this.embeddedInSheet = false,
    this.scrollController,
  });

  final ProfileModel? existing;

  /// Solo el propietario puede dar de alta otra cuenta de administración.
  final bool allowAdminRole;

  /// Baja lógica y borrado que libera el correo (mismo alcance que Cuentas).
  final bool canDeleteAccount;

  /// Contenido embebido en [showAdaptiveAdminSheet] (sin Scaffold propio).
  final bool embeddedInSheet;
  final ScrollController? scrollController;

  /// Modal / sheet moderno (16px) con validación en vivo.
  static Future<bool?> open(
    BuildContext context, {
    ProfileModel? existing,
    bool allowAdminRole = false,
    bool canDeleteAccount = false,
  }) {
    return showAdaptiveAdminSheet<bool>(
      context: context,
      draggable: true,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      desktopMaxWidth: AppBreakpoints.formMaxWidth,
      builder: (ctx, scroll) => OwnerAccountDossierForm(
        existing: existing,
        allowAdminRole: allowAdminRole,
        canDeleteAccount: canDeleteAccount,
        embeddedInSheet: true,
        scrollController: scroll,
      ),
    );
  }

  @override
  State<OwnerAccountDossierForm> createState() =>
      _OwnerAccountDossierFormState();
}

class _OwnerAccountDossierFormState extends State<OwnerAccountDossierForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _rifCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _legalEmailCtrl = TextEditingController();
  final _legalPhoneCtrl = TextEditingController();

  String _role = 'aliado';
  bool _activate = true;
  bool _busy = false;
  bool _hidePassword = true;
  bool _changed = false;
  bool _touched = false;
  String? _createdId;

  bool get _isCreate => widget.existing == null && _createdId == null;

  String? get _profileId => widget.existing?.id ?? _createdId;

  bool get _showLegal => _role == 'importador';

  /// Solo en alta. La revisión (aprobar / rechazar / adjuntar) vive en Cuentas.
  bool get _showDocs =>
      _role == 'aliado' && _profileId != null && widget.existing == null;

  bool get _canActivateNow {
    if (_profileId == null || _isCreate) return false;
    if (_createdId != null && !_activate) return true;
    return OwnerAccountRules.canActivateAccess(
      accountAccessStatus: widget.existing?.accountAccessStatus,
      deactivatedAt: widget.existing?.deactivatedAt,
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _emailCtrl.text = p.email ?? '';
      _nameCtrl.text = p.businessName ?? '';
      _rifCtrl.text = p.rif ?? '';
      _phoneCtrl.text = p.phone ?? '';
      _estadoCtrl.text = p.estado ?? '';
      _ciudadCtrl.text = p.ciudad ?? '';
      _direccionCtrl.text = p.direccion ?? '';
      _mapsCtrl.text = p.fiscalMapsUrl ?? '';
      _legalNameCtrl.text = p.legalContactName ?? '';
      _legalEmailCtrl.text = p.legalContactEmail ?? '';
      _legalPhoneCtrl.text = p.legalContactPhone ?? '';
      final r = p.role?.trim().toLowerCase();
      if (r == 'aliado' || r == 'importador' || r == 'administrador') {
        _role = r!;
      }
    }
    for (final c in [
      _emailCtrl,
      _passwordCtrl,
      _password2Ctrl,
      _nameCtrl,
      _rifCtrl,
      _phoneCtrl,
      _legalEmailCtrl,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (!_touched) return;
    setState(() {});
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    _nameCtrl.dispose();
    _rifCtrl.dispose();
    _phoneCtrl.dispose();
    _estadoCtrl.dispose();
    _ciudadCtrl.dispose();
    _direccionCtrl.dispose();
    _mapsCtrl.dispose();
    _legalNameCtrl.dispose();
    _legalEmailCtrl.dispose();
    _legalPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (_isCreate) {
      final err = OwnerAccountCreateRules.validateCreate(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        passwordConfirm: _password2Ctrl.text,
        businessName: _nameCtrl.text,
        role: _role,
        allowAdminRole: widget.allowAdminRole,
        rif: _rifCtrl.text,
        phone: _phoneCtrl.text,
      );
      if (err != null) {
        _snack(err, error: true);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Crear cuenta'),
          content: Text(
            '¿Crear ${ProfileRoleLabels.labelEs(_role).toLowerCase()} '
            'para ${_emailCtrl.text.trim()}?\n\n'
            '${_activate ? 'Podrá entrar de inmediato.' : 'Quedará en borrador hasta completar el registro.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _busy = true);
      try {
        final id = await SupabaseService.ownerCreateAccount(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          role: _role,
          businessName: _nameCtrl.text,
          rif: _rifCtrl.text,
          phone: _phoneCtrl.text,
          estado: _estadoCtrl.text,
          ciudad: _ciudadCtrl.text,
          direccion: _direccionCtrl.text,
          fiscalMapsUrl: _mapsCtrl.text,
          legalContactName: _legalNameCtrl.text,
          legalContactEmail: _legalEmailCtrl.text,
          legalContactPhone: _legalPhoneCtrl.text,
          activate: _activate,
        );
        if (!mounted) return;
        setState(() {
          _createdId = id;
          _changed = true;
          _passwordCtrl.clear();
          _password2Ctrl.clear();
        });
        _snack(
          _activate
              ? 'Cuenta creada. El correo ya puede entrar.'
              : 'Expediente guardado en borrador. Pulse Activar para habilitarla.',
        );
      } catch (e) {
        if (!mounted) return;
        _snack('No se pudo crear: $e', error: true);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final err = OwnerAccountCreateRules.validateDossier(
      businessName: _nameCtrl.text,
      rif: _rifCtrl.text,
      phone: _phoneCtrl.text,
      legalEmail: _legalEmailCtrl.text,
    );
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.ownerUpdateAccountDossier(
        profileId: _profileId!,
        businessName: _nameCtrl.text,
        rif: _rifCtrl.text,
        phone: _phoneCtrl.text,
        estado: _estadoCtrl.text,
        ciudad: _ciudadCtrl.text,
        direccion: _direccionCtrl.text,
        fiscalMapsUrl: _mapsCtrl.text,
        legalContactName: _legalNameCtrl.text,
        legalContactEmail: _legalEmailCtrl.text,
        legalContactPhone: _legalPhoneCtrl.text,
      );
      if (!mounted) return;
      setState(() => _changed = true);
      _snack('Expediente guardado.');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo guardar: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activateAccount() async {
    final id = _profileId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.ownerSetAccountAccess(
        profileId: id,
        status: AccountAccessStatus.active,
      );
      if (!mounted) return;
      setState(() {
        _activate = true;
        _changed = true;
      });
      _snack('Cuenta activada. Ya puede entrar con el expediente cargado.');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo activar: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  InputDecoration _dec(String label, {String? errorText, Widget? suffixIcon}) =>
      AdminUsersChrome.field(
        label: label,
        errorText: _touched ? errorText : null,
        suffixIcon: suffixIcon,
      );

  void _close([bool? result]) {
    Navigator.of(context).pop(result ?? _changed);
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AdminUsersChrome.brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _busy ? null : onPressed,
      child: _busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: B2BThemeExtension.of(context).surfaceCard,
              ),
            )
          : Text(label),
    );
  }

  List<Widget> _formChildren() {
    return [
      Text(
        _isCreate
            ? 'Crea el usuario de Auth y carga el expediente. '
                'Si activa la cuenta, puede entrar de inmediato.'
            : 'Actualiza los datos fiscales. Los documentos se revisan '
                'en Usuarios → Cuentas.',
        style: TextStyle(fontSize: 13, color: AdminUsersChrome.muted),
      ),
      const SizedBox(height: 14),
      if (_isCreate) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in [
              'aliado',
              'importador',
              if (widget.allowAdminRole) 'administrador',
            ])
              ChoiceChip(
                label: Text(ProfileRoleLabels.labelEs(role)),
                selected: _role == role,
                onSelected: _busy ? null : (_) => setState(() => _role = role),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: _emailCtrl,
        enabled: _isCreate && !_busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        onTap: () => setState(() => _touched = true),
        decoration: _dec(
          'Correo de login',
          errorText: _isCreate
              ? OwnerAccountCreateRules.emailError(_emailCtrl.text)
              : null,
        ),
      ),
      if (_isCreate) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          enabled: !_busy,
          obscureText: _hidePassword,
          onTap: () => setState(() => _touched = true),
          decoration: _dec(
            'Contraseña temporal',
            errorText: OwnerAccountCreateRules.passwordError(_passwordCtrl.text),
            suffixIcon: TextButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              child: Text(
                _hidePassword ? 'Ver' : 'Ocultar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminUsersChrome.brand,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password2Ctrl,
          enabled: !_busy,
          obscureText: _hidePassword,
          onTap: () => setState(() => _touched = true),
          decoration: _dec(
            'Confirmar contraseña',
            errorText: OwnerAccountCreateRules.passwordConfirmError(
              _passwordCtrl.text,
              _password2Ctrl.text,
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      TextField(
        controller: _nameCtrl,
        enabled: !_busy,
        onTap: () => setState(() => _touched = true),
        decoration: _dec(
          'Nombre comercial',
          errorText: OwnerAccountCreateRules.businessNameError(_nameCtrl.text),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _rifCtrl,
        enabled: !_busy,
        onTap: () => setState(() => _touched = true),
        decoration: _dec(
          'RIF',
          errorText: OwnerAccountCreateRules.rifError(_rifCtrl.text),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _phoneCtrl,
        enabled: !_busy,
        keyboardType: TextInputType.phone,
        onTap: () => setState(() => _touched = true),
        decoration: _dec(
          'Teléfono',
          errorText: OwnerAccountCreateRules.phoneError(_phoneCtrl.text),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _estadoCtrl,
        enabled: !_busy,
        decoration: _dec('Estado'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ciudadCtrl,
        enabled: !_busy,
        decoration: _dec('Ciudad'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _direccionCtrl,
        enabled: !_busy,
        maxLines: 2,
        decoration: _dec('Dirección fiscal'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _mapsCtrl,
        enabled: !_busy,
        decoration: _dec('Enlace de Maps (opcional)'),
      ),
      if (_showLegal) ...[
        const SizedBox(height: 16),
        Text(
          'Contacto legal',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AdminUsersChrome.titleColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _legalNameCtrl,
          enabled: !_busy,
          decoration: _dec('Nombre'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _legalEmailCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          onTap: () => setState(() => _touched = true),
          decoration: _dec(
            'Correo',
            errorText: OwnerAccountCreateRules.emailError(
              _legalEmailCtrl.text,
              required: false,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _legalPhoneCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          decoration: _dec('Teléfono'),
        ),
      ],
      if (_isCreate) ...[
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _activate,
          onChanged: _busy ? null : (v) => setState(() => _activate = v),
          title: const Text('Activar ahora'),
          subtitle: const Text(
            'Puede entrar de inmediato con este expediente. '
            'Si no, queda en borrador y luego lo activa en Cuentas.',
          ),
        ),
      ],
      if (_canActivateNow && !_busy) ...[
        const SizedBox(height: 8),
        Text(
          'El expediente ya está guardado. Actívela para que entre '
          'sin repetir el registro inicial.',
          style: TextStyle(fontSize: 13, color: AdminUsersChrome.muted),
        ),
        const SizedBox(height: 8),
        _primaryButton(label: 'Activar cuenta', onPressed: _activateAccount),
      ],
      const SizedBox(height: 12),
      _primaryButton(
        label: _isCreate ? 'Crear cuenta' : 'Guardar expediente',
        onPressed: _submit,
      ),
      if (_showDocs) ...[
        const SizedBox(height: 20),
        OwnerAccountDocsSection(
          profileId: _profileId!,
          markApproved: _activate,
        ),
        const SizedBox(height: 8),
        Text(
          'Tras el alta, la revisión de documentos se hace en '
          'Usuarios → Cuentas.',
          style: TextStyle(fontSize: 12.5, color: AdminUsersChrome.muted),
        ),
      ],
      if (widget.canDeleteAccount && widget.existing != null) ...[
        const SizedBox(height: 28),
        Text(
          'Acceso y eliminación',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AdminUsersChrome.titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Desactivar congela el acceso y conserva historial y correo. '
          'Eliminar borra el registro por completo y libera el correo.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: AdminUsersChrome.muted,
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.existing!.isDeactivated) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFFD97706),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _busy ? null : _softDelete,
            icon: const LucideIcon(
              LucideGlyph.userMinus,
              size: 18,
              color: Color(0xFFD97706),
            ),
            label: const Text('Desactivar cuenta (conservar historial)'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: const Color(0xFFDC2626),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _busy ? null : _hardDelete,
          icon: const LucideIcon(
            LucideGlyph.trash2,
            size: 18,
            color: Color(0xFFDC2626),
          ),
          label: const Text('Eliminar y liberar correo'),
        ),
      ],
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInSheet) {
      final theme = B2BThemeExtension.of(context);
      return Material(
        color: theme.dialogSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminUsersChrome.sheetRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isCreate ? 'Crear / Invitar usuario' : 'Editar expediente',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AdminUsersChrome.titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => _close(),
                    icon: LucideIcon(
                      LucideGlyph.close,
                      size: 20,
                      color: AdminUsersChrome.muted,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AdminUsersChrome.border),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: _formChildren(),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isCreate ? 'Nueva cuenta' : 'Expediente'),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.formMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: _formChildren(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _softDelete() async {
    final p = widget.existing;
    if (p == null) return;
    final note = await showDeactivateAccountDialog(
      context: context,
      profile: p,
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.ownerDeactivateProfile(
        profileId: p.id,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta desactivada. Historial y correo se conservan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo dar de baja: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _hardDelete() async {
    final p = widget.existing;
    if (p == null) return;
    final ok = await showDeleteUserDialog(
      context: context,
      profile: p,
      onDelete: (confirm) => SupabaseService.ownerHardDeleteProfile(
        profileId: p.id,
        confirm: confirm,
      ),
    );
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta borrada. El correo quedó libre para reutilizar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop(true);
  }
}

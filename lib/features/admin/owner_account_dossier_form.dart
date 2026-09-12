import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/features/admin/owner_account_create_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_account_docs_section.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

/// Owner: alta de cuenta o edición del expediente fiscal y documentos.
class OwnerAccountDossierForm extends StatefulWidget {
  const OwnerAccountDossierForm({
    super.key,
    this.existing,
  });

  final ProfileModel? existing;

  static Future<bool?> open(
    BuildContext context, {
    ProfileModel? existing,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OwnerAccountDossierForm(existing: existing),
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
  String? _createdId;

  bool get _isCreate => widget.existing == null && _createdId == null;

  String? get _profileId => widget.existing?.id ?? _createdId;

  bool get _showLegal => _role == 'importador';

  bool get _showDocs =>
      _role == 'aliado' &&
      _profileId != null &&
      (widget.existing != null || _activate);

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
    if (_isCreate) {
      final err = OwnerAccountCreateRules.validateCreate(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        passwordConfirm: _password2Ctrl.text,
        businessName: _nameCtrl.text,
        role: _role,
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

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
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
            children: [
              Text(
                _isCreate
                    ? 'Crea el usuario de Auth y carga el expediente. '
                        'Si activa la cuenta, puede entrar de inmediato.'
                    : 'Actualiza los datos fiscales. En tiendas también puede '
                        'cargar documentos.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              if (_isCreate) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in const [
                      'aliado',
                      'importador',
                      'administrador',
                    ])
                      ChoiceChip(
                        label: Text(ProfileRoleLabels.labelEs(role)),
                        selected: _role == role,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _role = role),
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
                decoration: _dec('Correo de login'),
              ),
              if (_isCreate) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  enabled: !_busy,
                  obscureText: _hidePassword,
                  decoration: _dec('Contraseña temporal').copyWith(
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password2Ctrl,
                  enabled: !_busy,
                  obscureText: _hidePassword,
                  decoration: _dec('Confirmar contraseña'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                enabled: !_busy,
                decoration: _dec('Nombre comercial'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _rifCtrl,
                enabled: !_busy,
                decoration: _dec('RIF'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: _dec('Teléfono'),
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
                    color: AppColors.textPrimary,
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
                  decoration: _dec('Correo'),
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
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _activate = v),
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
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: _activateAccount,
                  child: const Text('Activar cuenta'),
                ),
              ],
              const SizedBox(height: 12),
              if (_busy)
                const LinearProgressIndicator(color: AppColors.brand)
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: _submit,
                  child: Text(_isCreate ? 'Crear cuenta' : 'Guardar expediente'),
                ),
              if (_showDocs) ...[
                const SizedBox(height: 20),
                OwnerAccountDocsSection(
                  profileId: _profileId!,
                  markApproved: _activate ||
                      widget.existing?.hasActiveAccountAccess == true,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}

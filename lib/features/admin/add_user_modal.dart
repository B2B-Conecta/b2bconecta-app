import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/admin/owner_account_create_rules.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';

/// Alias de producto del modal de alta (`CreateUserModal`).
typedef CreateUserModal = AddUserModal;

/// Tipo de usuario B2B (selector principal).
enum AddUserType {
  minorista,
  mayorista,
  admin,
}

extension on AddUserType {
  String get labelEs => switch (this) {
        AddUserType.minorista => 'Tienda minorista',
        AddUserType.mayorista => 'Importador',
        AddUserType.admin => 'Administración',
      };

  LucideGlyph get glyph => switch (this) {
        AddUserType.minorista => LucideGlyph.store,
        AddUserType.mayorista => LucideGlyph.landmark,
        AddUserType.admin => LucideGlyph.shieldCheck,
      };

  bool get needsFiscal =>
      this == AddUserType.mayorista || this == AddUserType.minorista;

  bool get isMinorista => this == AddUserType.minorista;

  String get platformRole => switch (this) {
        AddUserType.admin => 'administrador',
        AddUserType.mayorista => 'importador',
        AddUserType.minorista => 'aliado',
      };
}

class _PendingKycFile {
  const _PendingKycFile({
    required this.docType,
    required this.bytes,
    required this.fileName,
  });

  final String docType;
  final Uint8List bytes;
  final String fileName;
}

/// Modal flotante «Crear / Invitar Usuario» (max 640px, grid 2 cols).
class AddUserModal extends StatefulWidget {
  const AddUserModal({
    super.key,
    this.allowAdminRole = false,
  });

  final bool allowAdminRole;

  /// Abre el diálogo; `true` si se creó la cuenta.
  static Future<bool?> open(
    BuildContext context, {
    bool allowAdminRole = false,
  }) {
    final theme = B2BThemeExtension.of(context);
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: theme.textPrimary.withOpacity(0.45),
      builder: (ctx) => AddUserModal(allowAdminRole: allowAdminRole),
    );
  }

  @override
  State<AddUserModal> createState() => _AddUserModalState();
}

class _AddUserModalState extends State<AddUserModal> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  final _rifCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  AddUserType _type = AddUserType.minorista;
  bool _active = true;
  bool _busy = false;
  bool _touched = false;
  bool _hidePassword = true;
  bool _loadKycNow = false;

  final Map<String, _PendingKycFile> _kycFiles = {};

  List<AddUserType> get _types {
    if (widget.allowAdminRole) {
      return const [
        AddUserType.minorista,
        AddUserType.mayorista,
        AddUserType.admin,
      ];
    }
    return const [AddUserType.minorista, AddUserType.mayorista];
  }

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _password2Ctrl,
      _rifCtrl,
      _phoneCtrl,
    ]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    _rifCtrl.dispose();
    _phoneCtrl.dispose();
    _estadoCtrl.dispose();
    _ciudadCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_touched) setState(() {});
  }

  String? get _nameError =>
      OwnerAccountCreateRules.businessNameError(_nameCtrl.text);

  String? get _emailError =>
      OwnerAccountCreateRules.emailError(_emailCtrl.text);

  String? get _passwordError =>
      OwnerAccountCreateRules.passwordError(_passwordCtrl.text);

  String? get _password2Error =>
      OwnerAccountCreateRules.passwordConfirmError(
        _passwordCtrl.text,
        _password2Ctrl.text,
      );

  String? get _rifError =>
      _type.needsFiscal ? OwnerAccountCreateRules.rifError(_rifCtrl.text) : null;

  String? get _phoneError => _type.needsFiscal
      ? OwnerAccountCreateRules.phoneError(_phoneCtrl.text)
      : null;

  void _cancel() {
    if (_busy) return;
    Navigator.of(context).pop(false);
  }

  void _generatePassword() {
    const chars =
        'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#';
    final r = Random.secure();
    final pwd = List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
    setState(() {
      _passwordCtrl.text = pwd;
      _password2Ctrl.text = pwd;
      _hidePassword = false;
      _touched = true;
    });
  }

  Future<void> _pickKyc(String docType) async {
    final picked = await pickKycDocument(channel: DocumentPickChannel.file);
    if (picked == null || !mounted) return;
    setState(() {
      _kycFiles[docType] = _PendingKycFile(
        docType: docType,
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
    });
  }

  void _clearKyc(String docType) {
    setState(() => _kycFiles.remove(docType));
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    final err = OwnerAccountCreateRules.validateCreate(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      passwordConfirm: _password2Ctrl.text,
      businessName: _nameCtrl.text,
      role: _type.platformRole,
      allowAdminRole: widget.allowAdminRole,
      rif: _type.needsFiscal ? _rifCtrl.text : '',
      phone: _type.needsFiscal ? _phoneCtrl.text : '',
    );
    if (err != null) {
      _snack(err, error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final id = await SupabaseService.ownerCreateAccount(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        role: _type.platformRole,
        businessName: _nameCtrl.text,
        rif: _type.needsFiscal ? _rifCtrl.text : null,
        phone: _type.needsFiscal ? _phoneCtrl.text : null,
        estado: _type.needsFiscal ? _estadoCtrl.text : null,
        ciudad: _type.needsFiscal ? _ciudadCtrl.text : null,
        direccion: _type.needsFiscal ? _direccionCtrl.text : null,
        activate: _active,
      );

      if (_type.isMinorista && _loadKycNow && _kycFiles.isNotEmpty) {
        for (final file in _kycFiles.values) {
          await SupabaseService.ownerUploadProfileDocument(
            profileId: id,
            docType: file.docType,
            bytes: file.bytes,
            fileName: file.fileName,
            markApproved: false,
          );
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final msg = _active
          ? 'Usuario creado. Cuenta activa e invitación lista.'
          : 'Usuario creado en pendiente. Podrá activarse desde Cuentas.';
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('No se pudo crear: $e', error: true);
    }
  }

  void _snack(String text, {bool error = false}) {
    final theme = B2BThemeExtension.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? Theme.of(context).colorScheme.error : theme.textPrimary,
      ),
    );
  }

  InputDecoration _field(String label, {String? errorText, Widget? suffix}) =>
      AdminUsersChrome.field(
        label: label,
        errorText: _touched ? errorText : null,
        suffixIcon: suffix,
      );

  Widget _row2(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: 12),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final selectedType = _types.contains(_type) ? _type : _types.first;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Focus(
          autofocus: true,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 640, maxHeight: maxH),
              child: Material(
                color: theme.dialogSurface,
                elevation: 24,
                shadowColor: theme.textPrimary.withOpacity(0.35),
                borderRadius:
                    BorderRadius.circular(AdminUsersChrome.sheetRadius),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(busy: _busy, onClose: _cancel),
                    Divider(height: 1, color: theme.borderSubtle),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tipo de cuenta',
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
                                for (final t in _types)
                                  _RoleChip(
                                    type: t,
                                    selected: selectedType == t,
                                    enabled: !_busy,
                                    onTap: () => setState(() {
                                      _type = t;
                                      if (!t.isMinorista) {
                                        _loadKycNow = false;
                                        _kycFiles.clear();
                                      }
                                    }),
                                  ),
                              ],
                            ),
                            _sectionTitle('Credenciales de acceso'),
                            TextField(
                              controller: _emailCtrl,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              onTap: () => setState(() => _touched = true),
                              decoration: _field(
                                'Correo de login',
                                errorText: _emailError,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _row2(
                              TextField(
                                controller: _passwordCtrl,
                                enabled: !_busy,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.next,
                                onTap: () => setState(() => _touched = true),
                                decoration: _field(
                                  'Contraseña temporal',
                                  errorText: _passwordError,
                                  suffix: TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                              () => _hidePassword =
                                                  !_hidePassword,
                                            ),
                                    child: Text(
                                      _hidePassword ? 'Ver' : 'Ocultar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: theme.brand,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              TextField(
                                controller: _password2Ctrl,
                                enabled: !_busy,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.next,
                                onTap: () => setState(() => _touched = true),
                                decoration: _field(
                                  'Confirmar contraseña',
                                  errorText: _password2Error,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _busy ? null : _generatePassword,
                                icon: LucideIcon(
                                  LucideGlyph.refreshCw,
                                  size: 14,
                                  color: theme.brand,
                                ),
                                label: const Text('Generar contraseña'),
                              ),
                            ),
                            if (selectedType.needsFiscal) ...[
                              _sectionTitle('Datos comerciales y fiscales'),
                              TextField(
                                controller: _nameCtrl,
                                enabled: !_busy,
                                textInputAction: TextInputAction.next,
                                onTap: () => setState(() => _touched = true),
                                decoration: _field(
                                  'Nombre comercial / Razón social',
                                  errorText: _nameError,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _row2(
                                TextField(
                                  controller: _rifCtrl,
                                  enabled: !_busy,
                                  textInputAction: TextInputAction.next,
                                  onTap: () =>
                                      setState(() => _touched = true),
                                  decoration: _field(
                                    'RIF',
                                    errorText: _rifError,
                                  ),
                                ),
                                TextField(
                                  controller: _phoneCtrl,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  onTap: () =>
                                      setState(() => _touched = true),
                                  decoration: _field(
                                    'Teléfono / WhatsApp',
                                    errorText: _phoneError,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _row2(
                                TextField(
                                  controller: _estadoCtrl,
                                  enabled: !_busy,
                                  textInputAction: TextInputAction.next,
                                  decoration: _field('Estado'),
                                ),
                                TextField(
                                  controller: _ciudadCtrl,
                                  enabled: !_busy,
                                  textInputAction: TextInputAction.next,
                                  decoration: _field('Ciudad'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _direccionCtrl,
                                enabled: !_busy,
                                maxLines: 2,
                                decoration: _field('Dirección fiscal'),
                              ),
                            ] else ...[
                              _sectionTitle('Identificación'),
                              TextField(
                                controller: _nameCtrl,
                                enabled: !_busy,
                                textInputAction: TextInputAction.next,
                                onTap: () => setState(() => _touched = true),
                                decoration: _field(
                                  'Nombre completo',
                                  errorText: _nameError,
                                ),
                              ),
                            ],
                            if (selectedType.isMinorista) ...[
                              const SizedBox(height: 14),
                              _KycToggleCard(
                                value: _loadKycNow,
                                enabled: !_busy,
                                onChanged: (v) => setState(() {
                                  _loadKycNow = v;
                                  if (!v) _kycFiles.clear();
                                }),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _loadKycNow
                                    ? _KycUploadBlock(
                                        files: _kycFiles,
                                        busy: _busy,
                                        onPick: _pickKyc,
                                        onClear: _clearKyc,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: theme.borderSubtle),
                    _Footer(
                      busy: _busy,
                      activate: _active,
                      onActivateChanged: (v) => setState(() => _active = v),
                      onCancel: _cancel,
                      onSubmit: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.busy, required this.onClose});

  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.brandContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              LucideGlyph.userPlus,
              size: 20,
              color: theme.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear / Invitar usuario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Crea el usuario de Auth y carga el expediente. '
                  'Si activa la cuenta, puede entrar de inmediato.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: busy ? null : onClose,
            icon: LucideIcon(
              LucideGlyph.close,
              size: 18,
              color: theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AddUserType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = selected ? theme.brandContainer : theme.surfaceCard;
    final fg = selected ? theme.brand : theme.textPrimary;
    final border = selected ? theme.brand : theme.borderStrong;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(
                selected ? LucideGlyph.circleCheck : type.glyph,
                size: 15,
                color: fg,
              ),
              const SizedBox(width: 7),
              Text(
                type.labelEs,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycToggleCard extends StatelessWidget {
  const _KycToggleCard({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: theme.brand,
        title: Text(
          '¿Cargar expediente de documentos y fotos ahora?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        subtitle: Text(
          'Activa esta opción si ya tienes a mano el RIF, registro y fotos '
          'del local. Si lo dejas apagado, podrás subirlos luego desde Cuentas.',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: theme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _KycUploadBlock extends StatelessWidget {
  const _KycUploadBlock({
    required this.files,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final Map<String, _PendingKycFile> files;
  final bool busy;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onClear;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PickRow(
            label: 'Documento RIF / Registro mercantil',
            hint: 'PDF o imagen',
            docType: AliadoDocType.registroMercantil,
            file: files[AliadoDocType.registroMercantil],
            busy: busy,
            onPick: onPick,
            onClear: onClear,
          ),
          const SizedBox(height: 8),
          _PickRow(
            label: 'Cédula del representante',
            hint: 'PDF o imagen',
            docType: AliadoDocType.cedulaPropietario,
            file: files[AliadoDocType.cedulaPropietario],
            busy: busy,
            onPick: onPick,
            onClear: onClear,
          ),
          const SizedBox(height: 10),
          Text(
            'Fotos del local / fachada (hasta 3)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in [
                AliadoDocType.fotoTienda,
                AliadoDocType.fotoTienda2,
                AliadoDocType.fotoTienda3,
              ])
                _PhotoSlot(
                  docType: slot,
                  file: files[slot],
                  busy: busy,
                  onPick: onPick,
                  onClear: onClear,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.hint,
    required this.docType,
    required this.file,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String hint;
  final String docType;
  final _PendingKycFile? file;
  final bool busy;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onClear;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          LucideIcon(
            LucideGlyph.fileText,
            size: 16,
            color: theme.brand,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  file?.fileName ?? hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: file == null ? theme.textMuted : theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (file != null)
            IconButton(
              tooltip: 'Quitar',
              onPressed: busy ? null : () => onClear(docType),
              icon: LucideIcon(
                LucideGlyph.close,
                size: 14,
                color: theme.textMuted,
              ),
            ),
          OutlinedButton(
            onPressed: busy ? null : () => onPick(docType),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.brand,
              side: BorderSide(color: theme.borderStrong),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(file == null ? 'Adjuntar' : 'Cambiar'),
          ),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.docType,
    required this.file,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final String docType;
  final _PendingKycFile? file;
  final bool busy;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onClear;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.inputFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: busy ? null : () => onPick(docType),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 96,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LucideIcon(
                      LucideGlyph.image,
                      size: 18,
                      color: theme.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Foto',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(file!.bytes, fit: BoxFit.cover),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Material(
                        color: theme.dialogSurface.withOpacity(0.9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: busy ? null : () => onClear(docType),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: LucideIcon(
                              LucideGlyph.close,
                              size: 12,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.busy,
    required this.activate,
    required this.onActivateChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool busy;
  final bool activate;
  final ValueChanged<bool> onActivateChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 520;
          final toggle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: activate,
                onChanged: busy ? null : onActivateChanged,
                activeColor: theme.brand,
              ),
              Flexible(
                child: Text(
                  'Activar cuenta inmediatamente',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
              ),
            ],
          );
          final cancelBtn = SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: busy ? null : onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(108, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                foregroundColor: theme.textPrimary,
                side: BorderSide(color: theme.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                alignment: Alignment.center,
              ),
              child: Text(
                'Cancelar',
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                  color: theme.textPrimary,
                ),
              ),
            ),
          );
          final createBtn = SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: theme.brand,
                foregroundColor: theme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                alignment: Alignment.center,
              ),
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: theme.surfaceCard,
                      ),
                    )
                  : Text(
                      'Crear usuario',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                        color: theme.surfaceCard,
                      ),
                    ),
            ),
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toggle,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: cancelBtn),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: createBtn),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: toggle),
              const SizedBox(width: 12),
              cancelBtn,
              const SizedBox(width: 10),
              createBtn,
            ],
          );
        },
      ),
    );
  }
}

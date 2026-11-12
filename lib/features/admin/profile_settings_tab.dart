import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_service.dart';

/// Datos de cuenta admin: logo, nombre comercial, correo RO y teléfono.
class ProfileSettingsTab extends StatefulWidget {
  const ProfileSettingsTab({
    super.key,
    this.onSaved,
  });

  /// Tras guardar (p. ej. refrescar perfil del shell).
  final VoidCallback? onSaved;

  @override
  State<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends State<ProfileSettingsTab>
    with AutomaticKeepAliveClientMixin {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _rifCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  ProfileModel? _profile;
  String? _logoUrl;
  Uint8List? _previewBytes;
  String? _previewExt;
  bool _clearLogo = false;
  bool _loading = true;
  bool _saving = false;
  bool _touched = false;
  bool _fiscalExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _rifCtrl.dispose();
    _estadoCtrl.dispose();
    _ciudadCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await ProfileService.fetchMyProfile();
      final email = Supabase.instance.client.auth.currentUser?.email ??
          p?.email ??
          '';
      String? url;
      final path = p?.logoStoragePath?.trim();
      if (path != null && path.isNotEmpty) {
        try {
          url = await ProfileService.createSignedUrlForProfileLogo(path);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nameCtrl.text = p?.businessName?.trim() ?? '';
        _phoneCtrl.text = p?.phone?.trim() ?? '';
        _emailCtrl.text = email;
        _rifCtrl.text = p?.rif?.trim() ?? '';
        _estadoCtrl.text = p?.estado?.trim() ?? '';
        _ciudadCtrl.text = p?.ciudad?.trim() ?? '';
        _direccionCtrl.text = p?.direccion?.trim() ?? '';
        _logoUrl = url;
        _previewBytes = null;
        _previewExt = null;
        _clearLogo = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String? get _nameError {
    if (!_touched) return null;
    if (_nameCtrl.text.trim().isEmpty) return 'El nombre comercial es obligatorio.';
    return null;
  }

  String get _initials {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _pickLogo() async {
    final picked = await pickProfileImageBytes(context);
    if (!mounted || picked == null) return;
    final n = picked.fileName.toLowerCase();
    if (n.endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El logo debe ser una imagen (JPG, PNG, WEBP).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    var ext = 'png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) ext = 'jpg';
    if (n.endsWith('.webp')) ext = 'webp';
    setState(() {
      _previewBytes = picked.bytes;
      _previewExt = ext;
      _clearLogo = false;
    });
  }

  void _restoreInitials() {
    setState(() {
      _previewBytes = null;
      _previewExt = null;
      _clearLogo = true;
    });
  }

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_nameError != null) return;

    setState(() => _saving = true);
    try {
      await ProfileService.updateMyAccountBasics(
        businessName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        rif: _rifCtrl.text,
        estado: _estadoCtrl.text,
        ciudad: _ciudadCtrl.text,
        direccion: _direccionCtrl.text,
      );
      if (_clearLogo) {
        await ProfileService.clearMyProfileLogo();
      } else if (_previewBytes != null && _previewExt != null) {
        await ProfileService.uploadMyProfileLogo(
          bytes: _previewBytes!,
          fileExtension: _previewExt!,
        );
      }
      if (!mounted) return;
      widget.onSaved?.call();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios guardados.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _logoPreview() {
    final showInitials = _clearLogo ||
        (_previewBytes == null && (_logoUrl == null || _logoUrl!.isEmpty));
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AdminUsersChrome.zebra,
        shape: BoxShape.circle,
        border: Border.all(color: AdminUsersChrome.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: showInitials
          ? Text(
              _initials,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AdminUsersChrome.brand,
              ),
            )
          : _previewBytes != null
              ? Image.memory(_previewBytes!, fit: BoxFit.cover, width: 72, height: 72)
              : Image.network(
                  _logoUrl!,
                  fit: BoxFit.cover,
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) => Text(
                    _initials,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AdminUsersChrome.brand,
                    ),
                  ),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = B2BThemeExtension.of(context);
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AdminUsersChrome.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminUsersChrome.sectionHeader(
                  title: 'Perfil de cuenta',
                  subtitle:
                      'Nombre comercial, logo y contacto para alertas del sistema.',
                  glyph: LucideGlyph.user,
                ),
                Row(
                  children: [
                    _logoPreview(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: _saving ? null : _pickLogo,
                            icon: LucideIcon(
                              LucideGlyph.image,
                              size: 16,
                              color: AdminUsersChrome.brand,
                            ),
                            label: Text(
                              'Cambiar foto',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AdminUsersChrome.brand,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _restoreInitials,
                            child: Text(
                              'Restaurar iniciales',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminUsersChrome.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _touched = true),
                  decoration: AdminUsersChrome.field(
                    label: 'Nombre comercial',
                    hint: 'Ej. B2B Conecta Owner',
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  readOnly: true,
                  enableInteractiveSelection: true,
                  decoration: AdminUsersChrome.field(
                    label: 'Correo electrónico',
                  ).copyWith(
                    fillColor: AdminUsersChrome.zebra,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'El correo de la sesión no se puede cambiar desde aquí.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminUsersChrome.muted,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: AdminUsersChrome.field(
                    label: 'Teléfono de contacto',
                    hint: 'Para alertas críticas del sistema',
                  ),
                ),
                if (_profile?.role != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rol: ${_profile!.role}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminUsersChrome.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _fiscalExpanded,
                    onExpansionChanged: (v) =>
                        setState(() => _fiscalExpanded = v),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: Text(
                      'Datos fiscales y dirección',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AdminUsersChrome.titleColor,
                      ),
                    ),
                    subtitle: Text(
                      'RIF, estado, ciudad y domicilio fiscal',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminUsersChrome.muted,
                      ),
                    ),
                    children: [
                      TextField(
                        controller: _rifCtrl,
                        enabled: !_saving,
                        decoration: AdminUsersChrome.field(
                          label: 'RIF',
                          hint: 'J-XXXXXXXXX',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _estadoCtrl,
                        enabled: !_saving,
                        decoration: AdminUsersChrome.field(label: 'Estado'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ciudadCtrl,
                        enabled: !_saving,
                        decoration: AdminUsersChrome.field(label: 'Ciudad'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _direccionCtrl,
                        enabled: !_saving,
                        maxLines: 2,
                        decoration: AdminUsersChrome.field(
                          label: 'Dirección fiscal',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AdminUsersChrome.border),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brand,
                      foregroundColor: theme.surfaceCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.surfaceCard,
                            ),
                          )
                        : const Text(
                            'Guardar cambios',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

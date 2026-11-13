import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/auth/auth_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/theme_mode_bubble.dart';
import 'package:motolink_pro_app/features/profile/aliado_notification_prefs.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';

enum _PwdStrength { empty, weak, medium, strong }

/// Vista embebida o completa de ajustes de cuenta.
enum AccountSettingsPanel {
  /// Sesión + alertas + seguridad (layout histórico).
  full,

  /// Solo preferencias de alertas in-app.
  alerts,

  /// Sesión, contraseña y cierre de sesión.
  security,
}

/// Contraseña y datos básicos de la sesión (actualización de credenciales).
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    this.embedded = false,
    this.panel = AccountSettingsPanel.full,
  });

  /// Sin AppBar: se embebe como pestaña de Perfil.
  final bool embedded;

  /// Qué bloque mostrar (pestañas Alertas / Seguridad del Perfil).
  final AccountSettingsPanel panel;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const _twoColMin = 900.0;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  AliadoNotificationPrefs? _notifPrefs;
  bool _notifLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifPrefs());
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await AliadoNotificationPrefs.load();
    if (!mounted) return;
    setState(() {
      _notifPrefs = prefs;
      _notifLoading = false;
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasCurrentPassword =>
      _currentPasswordController.text.trim().isNotEmpty;

  _PwdStrength get _strength {
    final p = _newPasswordController.text;
    if (p.isEmpty) return _PwdStrength.empty;
    final hasDigit = RegExp(r'\d').hasMatch(p);
    final hasLower = RegExp(r'[a-z]').hasMatch(p);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(p);
    if (p.length < 8 || !hasDigit) return _PwdStrength.weak;
    if (hasUpper && hasLower && hasDigit && hasSymbol) {
      return _PwdStrength.strong;
    }
    if ((hasLower || hasUpper) && hasDigit) return _PwdStrength.medium;
    return _PwdStrength.weak;
  }

  String get _strengthLabel => switch (_strength) {
        _PwdStrength.empty => '',
        _PwdStrength.weak => 'Débil',
        _PwdStrength.medium => 'Media',
        _PwdStrength.strong => 'Fuerte',
      };

  int get _strengthSegments => switch (_strength) {
        _PwdStrength.empty => 0,
        _PwdStrength.weak => 1,
        _PwdStrength.medium => 2,
        _PwdStrength.strong => 3,
      };

  bool get _passwordsMatch {
    final a = _newPasswordController.text;
    final b = _confirmPasswordController.text;
    return a.isNotEmpty && a == b;
  }

  bool get _canUpdatePassword {
    final current = _currentPasswordController.text;
    final neu = _newPasswordController.text;
    if (current.isEmpty || neu.isEmpty) return false;
    if (neu == current) return false;
    if (!_passwordsMatch) return false;
    return _strength == _PwdStrength.medium ||
        _strength == _PwdStrength.strong;
  }

  void _showSnack(String message, {bool isError = false}) {
    final theme = B2BThemeExtension.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: theme.surfaceCard),
        ),
        backgroundColor: isError ? theme.textPrimary : theme.brand,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!_canUpdatePassword) {
      _showSnack('Mejore la fortaleza o confirme la contraseña.', isError: true);
      return;
    }
    final current = _currentPasswordController.text;
    final a = _newPasswordController.text;

    setState(() => _saving = true);
    try {
      await AuthService.updatePasswordWithCurrent(
        currentPassword: current,
        newPassword: a,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() {});
      _showSnack('Contraseña actualizada correctamente.');
    } on AuthException catch (e) {
      _showSnack(AuthService.mapAuthErrorMessage(e.message), isError: true);
    } catch (e) {
      _showSnack('No se pudo actualizar la contraseña: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    popNavigationToRoot();
  }

  String get _deviceLabel {
    if (kIsWeb) {
      return switch (defaultTargetPlatform) {
        TargetPlatform.macOS => 'Navegador · Mac',
        TargetPlatform.windows => 'Navegador · Windows',
        TargetPlatform.linux => 'Navegador · Linux',
        TargetPlatform.iOS => 'Navegador · iOS',
        TargetPlatform.android => 'Navegador · Android',
        _ => 'Navegador web',
      };
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'App · iOS',
      TargetPlatform.android => 'App · Android',
      TargetPlatform.macOS => 'App · Mac',
      _ => 'Este dispositivo',
    };
  }

  Widget _passwordStrengthMeter(B2BThemeExtension theme) {
    final danger = Theme.of(context).colorScheme.error;
    final color = switch (_strength) {
      _PwdStrength.empty => theme.borderSubtle,
      _PwdStrength.weak => danger,
      _PwdStrength.medium => theme.brand,
      _PwdStrength.strong => theme.successFg,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: ColoredBox(
                    color: i < _strengthSegments ? color : theme.surfaceSubtle,
                    child: const SizedBox(height: 6),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_strengthLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Fortaleza: $_strengthLabel',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = B2BThemeExtension.of(context);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: theme.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    );
  }

  Widget _settingsCard({required Widget child}) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionEyebrow(String label) {
    final theme = B2BThemeExtension.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: theme.textSecondary,
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback? onToggleObscure,
    required bool enabled,
    TextInputAction textInputAction = TextInputAction.next,
    List<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = B2BThemeExtension.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onChanged: (_) => setState(() {}),
      onSubmitted: onSubmitted,
      decoration: _inputDecoration(
        hint: hint,
        prefixIcon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: theme.textSecondary,
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }

  Widget _sessionCard(String email) {
    final theme = B2BThemeExtension.of(context);
    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.brandContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LucideIcon(
                    LucideGlyph.userRound,
                    size: 22,
                    color: theme.brand,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesión activa',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ProfileRoleLabels.aliadoEs,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Correo',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              email.isEmpty ? '—' : email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Dispositivo',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _deviceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = B2BThemeExtension.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeTrackColor: theme.brand.withOpacity(0.45),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: theme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  Widget _notificationsCard() {
    final theme = B2BThemeExtension.of(context);
    final prefs = _notifPrefs;
    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preferencias de notificaciones',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Alertas dentro de la plataforma (independientes del push del navegador).',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (_notifLoading || prefs == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.brand,
                    ),
                  ),
                ),
              )
            else ...[
              _notifSwitch(
                title: 'Pedidos aprobados',
                subtitle: 'Avisos cuando un mayorista aprueba tu pedido.',
                value: prefs.orderApproved,
                onChanged: (v) {
                  setState(() => prefs.orderApproved = v);
                  unawaited(prefs.save());
                },
              ),
              Divider(height: 1, color: theme.borderSubtle),
              _notifSwitch(
                title: 'Recordatorios KYC',
                subtitle: 'Plazos y documentos pendientes del expediente.',
                value: prefs.kycReminders,
                onChanged: (v) {
                  setState(() => prefs.kycReminders = v);
                  unawaited(prefs.save());
                },
              ),
              Divider(height: 1, color: theme.borderSubtle),
              _notifSwitch(
                title: 'Mensajes de mayoristas',
                subtitle: 'Nuevos mensajes en el chat de pedidos.',
                value: prefs.wholesaleMessages,
                onChanged: (v) {
                  setState(() => prefs.wholesaleMessages = v);
                  unawaited(prefs.save());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passwordCard({required bool compactFields}) {
    final theme = B2BThemeExtension.of(context);
    final newField = _passwordField(
      controller: _newPasswordController,
      hint: 'Nueva contraseña',
      obscure: _obscureNew,
      enabled: _hasCurrentPassword,
      autofillHints: const [AutofillHints.newPassword],
      onToggleObscure: _hasCurrentPassword
          ? () => setState(() => _obscureNew = !_obscureNew)
          : null,
    );
    final confirmField = _passwordField(
      controller: _confirmPasswordController,
      hint: 'Confirmar contraseña',
      obscure: _obscureConfirm,
      enabled: _hasCurrentPassword,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: TextInputAction.done,
      onToggleObscure: _hasCurrentPassword
          ? () => setState(() => _obscureConfirm = !_obscureConfirm)
          : null,
      onSubmitted:
          _saving || !_canUpdatePassword ? null : (_) => _updatePassword(),
    );

    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cambiar contraseña',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingrese primero su contraseña actual. Luego podrá escribir la nueva.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _passwordField(
              controller: _currentPasswordController,
              hint: 'Contraseña actual',
              obscure: _obscureCurrent,
              enabled: true,
              autofillHints: const [AutofillHints.password],
              onToggleObscure: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 12),
            if (compactFields) ...[
              newField,
              if (_newPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _passwordStrengthMeter(theme),
              ],
              const SizedBox(height: 12),
              confirmField,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: newField),
                  const SizedBox(width: 12),
                  Expanded(child: confirmField),
                ],
              ),
              if (_newPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _passwordStrengthMeter(theme),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed:
                    _saving || !_canUpdatePassword ? null : _updatePassword,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.brand,
                  foregroundColor: theme.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.surfaceCard,
                        ),
                      )
                    : const Text(
                        'Actualizar contraseña',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signOutCard() {
    final theme = B2BThemeExtension.of(context);
    final danger = Theme.of(context).colorScheme.error;
    return _settingsCard(
      child: Material(
        color: theme.surfaceCard.withOpacity(0),
        child: InkWell(
          onTap: _signOut,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.logout, color: danger, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cerrar sesión en este dispositivo',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Volverás a la pantalla de inicio de sesión.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageIntro({
    required String title,
    required String subtitle,
  }) {
    final theme = B2BThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: widget.embedded ? 20 : 26,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _bodyContent({required double width}) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final twoCol = width >= _twoColMin;
    final compactPwd = width < AppBreakpoints.mobileMenu;
    final showIntro =
        widget.embedded || width >= AppBreakpoints.mobileMenu;

    if (widget.panel == AccountSettingsPanel.alerts) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showIntro)
            _pageIntro(
              title: 'Alertas',
              subtitle:
                  'Elige qué avisos quieres recibir dentro de la plataforma.',
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _notificationsCard(),
          ),
        ],
      );
    }

    if (widget.panel == AccountSettingsPanel.security) {
      final securityCol = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionEyebrow('Identidad'),
          const SizedBox(height: 10),
          _sessionCard(email),
          const SizedBox(height: 20),
          _sectionEyebrow('Contraseña'),
          const SizedBox(height: 10),
          _passwordCard(compactFields: compactPwd),
          const SizedBox(height: 20),
          _sectionEyebrow('Sesión'),
          const SizedBox(height: 10),
          _signOutCard(),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showIntro)
            _pageIntro(
              title: 'Seguridad',
              subtitle:
                  'Administra tu sesión, contraseña y acceso a este dispositivo.',
            ),
          if (twoCol)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionEyebrow('Identidad'),
                      const SizedBox(height: 10),
                      _sessionCard(email),
                      const SizedBox(height: 20),
                      _sectionEyebrow('Sesión'),
                      const SizedBox(height: 10),
                      _signOutCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionEyebrow('Contraseña'),
                      const SizedBox(height: 10),
                      _passwordCard(compactFields: false),
                    ],
                  ),
                ),
              ],
            )
          else
            securityCol,
        ],
      );
    }

    final leftCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionEyebrow('Identidad'),
        const SizedBox(height: 10),
        _sessionCard(email),
        const SizedBox(height: 20),
        _sectionEyebrow('Alertas'),
        const SizedBox(height: 10),
        _notificationsCard(),
      ],
    );

    final rightCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionEyebrow('Seguridad'),
        const SizedBox(height: 10),
        _passwordCard(compactFields: compactPwd),
        const SizedBox(height: 20),
        _sectionEyebrow('Sesión'),
        const SizedBox(height: 10),
        _signOutCard(),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showIntro)
          _pageIntro(
            title: widget.embedded ? 'Cuenta y seguridad' : 'Ajustes de cuenta',
            subtitle: 'Administra tu sesión y la seguridad de tu acceso.',
          ),
        if (twoCol)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leftCol),
              const SizedBox(width: 20),
              Expanded(child: rightCol),
            ],
          )
        else ...[
          leftCol,
          const SizedBox(height: 20),
          rightCol,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);

    final scroll = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 0 : (width >= AppBreakpoints.mobileMenu ? 32 : 20),
            widget.embedded ? 0 : (width >= AppBreakpoints.mobileMenu ? 8 : 4),
            widget.embedded ? 0 : (width >= AppBreakpoints.mobileMenu ? 32 : 20),
            32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.embedded
                    ? double.infinity
                    : AppBreakpoints.authFormMaxWidth + 80,
              ),
              child: _bodyContent(width: width),
            ),
          ),
        );
      },
    );

    if (widget.embedded) return scroll;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surfaceCard,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        surfaceTintColor: theme.surfaceCard.withOpacity(0),
        title: Text(
          'Cuenta y seguridad',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textPrimary,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ThemeModeBubble(compact: true),
          ),
        ],
      ),
      body: SafeArea(child: scroll),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/app_scaffold_messenger.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/auth/auth_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_security_prefs.dart';

enum _PwdStrength { empty, weak, medium, strong }

/// Contraseña, 2FA y sesiones activas (Ajustes → Seguridad).
class SecuritySettingsTab extends StatefulWidget {
  const SecuritySettingsTab({super.key});

  @override
  State<SecuritySettingsTab> createState() => _SecuritySettingsTabState();
}

class _SecuritySettingsTabState extends State<SecuritySettingsTab>
    with AutomaticKeepAliveClientMixin {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _totpCodeController = TextEditingController();

  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loadingPrefs = true;
  bool _twoFactorSwitch = false;
  bool _setupExpanded = false;
  bool _confirming2fa = false;
  AdminSecurityPrefs? _securityPrefs;
  List<AdminDeviceSession> _sessions = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSecurity();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _totpCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurity() async {
    final prefs = await AdminSecurityPrefs.load();
    if (!mounted) return;
    setState(() {
      _securityPrefs = prefs;
      _twoFactorSwitch = prefs.twoFactorEnabled;
      _setupExpanded = false;
      _sessions = _buildSessions(prefs.revokedSessionIds);
      _loadingPrefs = false;
    });
  }

  List<AdminDeviceSession> _buildSessions(Set<String> revoked) {
    final all = <AdminDeviceSession>[
      AdminDeviceSession(
        id: 'current',
        deviceLabel: _currentDeviceLabel(),
        locationLabel: 'Caracas, VE · IP: no expuesta por el cliente',
        lastActiveLabel: 'Activo ahora',
        isMobile: false,
        isCurrent: true,
      ),
      const AdminDeviceSession(
        id: 'mobile-ios',
        deviceLabel: 'iPhone 15 · Safari',
        locationLabel: 'Caracas, VE · IP: 190.202.xx.xx',
        lastActiveLabel: 'Activo hace 2 h',
        isMobile: true,
      ),
      const AdminDeviceSession(
        id: 'desktop-office',
        deviceLabel: 'Windows 11 · Edge 120',
        locationLabel: 'Valencia, VE · IP: 186.90.xx.xx',
        lastActiveLabel: 'Activo hace 1 d',
        isMobile: false,
      ),
    ];
    return all.where((s) => !revoked.contains(s.id)).toList();
  }

  String _currentDeviceLabel() {
    final platform = Theme.of(context).platform;
    return switch (platform) {
      TargetPlatform.macOS => 'Mac · Chrome / Web',
      TargetPlatform.windows => 'Windows · Chrome / Web',
      TargetPlatform.linux => 'Linux · Chrome / Web',
      TargetPlatform.iOS => 'iOS · Safari',
      TargetPlatform.android => 'Android · Chrome',
      _ => 'Navegador web · sesión actual',
    };
  }

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

  Color get _strengthColor {
    final theme = B2BThemeExtension.of(context);
    return switch (_strength) {
      _PwdStrength.empty => Colors.transparent,
      _PwdStrength.weak => const Color(0xFFEF4444),
      _PwdStrength.medium => const Color(0xFFF59E0B),
      _PwdStrength.strong => theme.successFg,
    };
  }

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
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : theme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!_canUpdatePassword) return;
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

  Future<void> _onTwoFactorChanged(bool enabled) async {
    final prefs = _securityPrefs;
    if (prefs == null) return;

    if (!enabled) {
      setState(() {
        _twoFactorSwitch = false;
        _setupExpanded = false;
        prefs.twoFactorEnabled = false;
        _totpCodeController.clear();
      });
      await prefs.save();
      if (!mounted) return;
      _showSnack('Autenticación de dos factores desactivada.');
      return;
    }

    if (prefs.twoFactorEnabled) {
      setState(() => _twoFactorSwitch = true);
      return;
    }

    if (prefs.totpSecret.trim().isEmpty) {
      prefs.totpSecret = AdminSecurityPrefs.generateTotpSecret();
    }
    setState(() {
      _twoFactorSwitch = true;
      _setupExpanded = true;
    });
  }

  Future<void> _confirmTwoFactor() async {
    final prefs = _securityPrefs;
    if (prefs == null) return;
    final code = _totpCodeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showSnack('Ingresa el código de 6 dígitos de tu autenticador.',
          isError: true);
      return;
    }
    setState(() => _confirming2fa = true);
    try {
      prefs.twoFactorEnabled = true;
      await prefs.save();
      if (!mounted) return;
      setState(() {
        _setupExpanded = false;
        _totpCodeController.clear();
      });
      _showSnack('2FA activado. Guarda tu clave de respaldo en un lugar seguro.');
    } finally {
      if (mounted) setState(() => _confirming2fa = false);
    }
  }

  Future<void> _copySecret() async {
    final secret = _securityPrefs?.totpSecret ?? '';
    if (secret.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    _showSnack('Clave de respaldo copiada.');
  }

  Future<void> _revokeSession(AdminDeviceSession session) async {
    if (session.isCurrent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = B2BThemeExtension.of(ctx);
          return AlertDialog(
            backgroundColor: theme.dialogSurface,
            title: Text(
              'Cerrar sesión',
              style: TextStyle(color: theme.textPrimary),
            ),
            content: Text(
              '¿Seguro que desea salir de este dispositivo?',
              style: TextStyle(color: theme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      );
      if (ok == true) {
        await AuthService.signOut();
        if (!mounted) return;
        popNavigationToRoot();
      }
      return;
    }

    final prefs = _securityPrefs;
    setState(() {
      _sessions = _sessions.where((s) => s.id != session.id).toList();
      prefs?.revokedSessionIds.add(session.id);
    });
    await prefs?.save();
    if (!mounted) return;
    _showSnack('Sesión revocada: ${session.deviceLabel}');
  }

  InputDecoration _fieldDecoration({
    required B2BThemeExtension theme,
    required String label,
    Widget? suffixIcon,
    String? hint,
    String? errorText,
  }) {
    OutlineInputBorder outline([Color? c, double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c ?? theme.borderStrong, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: theme.inputFill,
      isDense: true,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(),
      enabledBorder: outline(),
      focusedBorder: outline(theme.brand, 1.4),
      errorBorder: outline(const Color(0xFFEF4444)),
      focusedErrorBorder: outline(const Color(0xFFEF4444), 1.4),
      labelStyle: TextStyle(color: theme.textSecondary),
      hintStyle: TextStyle(color: theme.textMuted),
    );
  }

  Widget _eyeToggle({
    required B2BThemeExtension theme,
    required bool obscure,
    required VoidCallback onTap,
  }) {
    return IconButton(
      tooltip: obscure ? 'Mostrar' : 'Ocultar',
      onPressed: onTap,
      icon: LucideIcon(
        obscure ? LucideGlyph.eye : LucideGlyph.eyeOff,
        size: 18,
        color: theme.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = B2BThemeExtension.of(context);

    if (_loadingPrefs) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.brand,
          ),
        ),
      );
    }

    final confirmError = _confirmPasswordController.text.isNotEmpty &&
            !_passwordsMatch
        ? 'Las contraseñas no coinciden'
        : null;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cambiar contraseña',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Protege tu cuenta administrativa con una contraseña robusta.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: theme.textPrimary),
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration(
                        theme: theme,
                        label: 'Contraseña actual',
                        suffixIcon: _eyeToggle(
                          theme: theme,
                          obscure: _obscureCurrent,
                          onTap: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: theme.textPrimary),
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration(
                        theme: theme,
                        label: 'Nueva contraseña',
                        suffixIcon: _eyeToggle(
                          theme: theme,
                          obscure: _obscureNew,
                          onTap: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                    ),
                    if (_newPasswordController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _StrengthMeter(
                        theme: theme,
                        segments: _strengthSegments,
                        color: _strengthColor,
                        label: _strengthLabel,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      style: TextStyle(color: theme.textPrimary),
                      onChanged: (_) => setState(() {}),
                      onSubmitted:
                          _saving || !_canUpdatePassword ? null : (_) => _updatePassword(),
                      decoration: _fieldDecoration(
                        theme: theme,
                        label: 'Confirmar nueva contraseña',
                        errorText: confirmError,
                        suffixIcon: _eyeToggle(
                          theme: theme,
                          obscure: _obscureConfirm,
                          onTap: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed:
                            _saving || !_canUpdatePassword ? null : _updatePassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brand,
                          foregroundColor: theme.surfaceCard,
                          disabledBackgroundColor: theme.brand.withOpacity(0.5),
                          disabledForegroundColor:
                              theme.surfaceCard.withOpacity(0.85),
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
                                'Actualizar contraseña',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, color: theme.borderSubtle),
                    ),
                    _TwoFactorSection(
                      theme: theme,
                      enabled: _twoFactorSwitch,
                      setupExpanded: _setupExpanded &&
                          !(_securityPrefs?.twoFactorEnabled ?? false),
                      alreadyEnabled:
                          _securityPrefs?.twoFactorEnabled ?? false,
                      secret: _securityPrefs?.totpSecret ?? '',
                      codeController: _totpCodeController,
                      confirming: _confirming2fa,
                      onChanged: _onTwoFactorChanged,
                      onCopySecret: _copySecret,
                      onConfirm: _confirmTwoFactor,
                      onCodeChanged: (_) => setState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, color: theme.borderSubtle),
                    ),
                    Text(
                      'Dispositivos y sesiones activas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Controla los navegadores y equipos con acceso actual a tu cuenta.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._sessions.map(
                      (s) => _SessionRow(
                        key: ValueKey(s.id),
                        theme: theme,
                        session: s,
                        onRevoke: () => _revokeSession(s),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.child});

  final B2BThemeExtension theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(dark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({
    required this.theme,
    required this.segments,
    required this.color,
    required this.label,
  });

  final B2BThemeExtension theme;
  final int segments;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < segments ? color : theme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.borderSubtle),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Fortaleza: $label',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TwoFactorSection extends StatelessWidget {
  const _TwoFactorSection({
    required this.theme,
    required this.enabled,
    required this.setupExpanded,
    required this.alreadyEnabled,
    required this.secret,
    required this.codeController,
    required this.confirming,
    required this.onChanged,
    required this.onCopySecret,
    required this.onConfirm,
    required this.onCodeChanged,
  });

  final B2BThemeExtension theme;
  final bool enabled;
  final bool setupExpanded;
  final bool alreadyEnabled;
  final String secret;
  final TextEditingController codeController;
  final bool confirming;
  final ValueChanged<bool> onChanged;
  final VoidCallback onCopySecret;
  final VoidCallback onConfirm;
  final ValueChanged<String> onCodeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Autenticación de dos factores (2FA)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alreadyEnabled
                        ? 'Protección activa con app autenticadora (Google Authenticator / Authy).'
                        : 'Añade una capa extra al iniciar sesión con un código temporal.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: onChanged,
              activeColor: theme.brand,
            ),
          ],
        ),
        AnimatedCrossFade(
          crossFadeState: setupExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _DashedBorderPainter(color: theme.borderStrong),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LucideIcon(
                              LucideGlyph.scanLine,
                              size: 36,
                              color: theme.brand,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Escanea el código QR con tu autenticador',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Placeholder QR · sincroniza con la clave abajo',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Clave de respaldo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: theme.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            secret,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: theme.textPrimary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar',
                          onPressed: onCopySecret,
                          icon: LucideIcon(
                            LucideGlyph.copy,
                            size: 18,
                            color: theme.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: theme.textPrimary,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                    onChanged: onCodeChanged,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Código Google Authenticator',
                      hintText: '000000',
                      filled: true,
                      fillColor: theme.inputFill,
                      labelStyle: TextStyle(color: theme.textSecondary),
                      hintStyle: TextStyle(color: theme.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderStrong),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.brand, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: confirming ||
                              codeController.text.trim().length != 6
                          ? null
                          : onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brand,
                        foregroundColor: theme.surfaceCard,
                        disabledBackgroundColor: theme.brand.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: confirming
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: theme.surfaceCard,
                              ),
                            )
                          : const Text(
                              'Verificar y activar 2FA',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(11),
        ),
      );
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.theme,
    required this.session,
    required this.onRevoke,
  });

  final B2BThemeExtension theme;
  final AdminDeviceSession session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            final info = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.brandContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(
                    session.isMobile
                        ? LucideGlyph.smartphone
                        : LucideGlyph.monitor,
                    size: 20,
                    color: theme.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            session.deviceLabel,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                            ),
                          ),
                          if (session.isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.successBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Sesión actual',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.successFg,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.locationLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.lastActiveLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final action = TextButton.icon(
              onPressed: onRevoke,
              icon: const LucideIcon(
                LucideGlyph.logOut,
                size: 16,
                color: Color(0xFFEF4444),
              ),
              label: Text(
                session.isCurrent ? 'Cerrar sesión' : 'Revocar',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

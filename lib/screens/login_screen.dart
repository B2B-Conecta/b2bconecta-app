import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_scaffold_messenger.dart';
import '../auth/referral_invite_storage.dart';
import '../config/public_legal_route.dart';
import '../config/referral_invite_config.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import '../utils/open_public_legal.dart';
import '../widgets/login_forgot_password_dialog.dart';
import '../widgets/motolink_pro_logo.dart';
import '../widgets/referral_qr_scan_sheet.dart';
import '../widgets/theme_mode_bubble.dart';

enum _AuthMode { login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialErrorMessage});

  /// Mensaje de error tras abrir un enlace Auth inválido o expirado.
  final String? initialErrorMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final msg = widget.initialErrorMessage?.trim();
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSnackBar(msg, isError: true);
      });
    }
    _bootstrapReferralFromUrl();
  }

  Future<void> _bootstrapReferralFromUrl() async {
    final fromUrl = ReferralInviteConfig.codeFromUri(Uri.base);
    final pending = await ReferralInviteStorage.peekPendingCode();
    final code = fromUrl ?? pending;
    if (code == null || code.isEmpty) return;
    await ReferralInviteStorage.savePendingCode(code);
    if (!mounted) return;
    setState(() {
      _referralController.text = code;
      if (fromUrl != null) _mode = _AuthMode.register;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final messenger =
        scaffoldMessengerKey.currentState ?? ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor, completa todos los campos', isError: true);
      return;
    }
    if (!_validateEmail(email)) {
      _showSnackBar('Ingresa un correo electrónico válido', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      debugPrint('[signIn] ${e.message}');
      _showSnackBar(AuthService.mapAuthErrorMessage(e.message), isError: true);
    } catch (e, stackTrace) {
      debugPrint('[signIn] $e\n$stackTrace');
      _showSnackBar('Ocurrió un error inesperado.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnackBar('Completa todos los campos', isError: true);
      return;
    }
    if (!_validateEmail(email)) {
      _showSnackBar('Ingresa un correo electrónico válido', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres',
          isError: true);
      return;
    }
    if (password != confirm) {
      _showSnackBar('Las contraseñas no coinciden', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final referral =
          ReferralInviteConfig.normalizeCode(_referralController.text);
      if (referral.isNotEmpty) {
        await ReferralInviteStorage.savePendingCode(referral);
      }
      final res = await AuthService.signUpWithPassword(
        email: email,
        password: password,
        referralCode: referral.isEmpty ? null : referral,
      );
      if (!mounted) return;
      if (res.session != null) {
        _showSnackBar('Cuenta creada. Bienvenido.');
      } else {
        _showSnackBar(
          'Revisa tu correo para confirmar la cuenta antes de iniciar sesión.',
          isError: false,
        );
      }
    } on AuthException catch (e) {
      debugPrint('[signUp] ${e.message}');
      _showSnackBar(AuthService.mapAuthErrorMessage(e.message), isError: true);
    } catch (e, stackTrace) {
      debugPrint('[signUp] $e\n$stackTrace');
      _showSnackBar('No se pudo completar el registro.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final result = await showLoginForgotPasswordDialog(
      context,
      initialEmail: _emailController.text.trim(),
    );
    if (!mounted || result == null) return;
    _showSnackBar(result.message, isError: result.isError);
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    );
  }

  Widget _buildAuthHeader({required bool compact}) {
    final logoHeight = compact ? 88.0 : MotoLinkProLogoHeights.login;
    return Column(
      children: [
        // El PNG ya incluye «B2B CONECTA»; no repetir el nombre en texto.
        MotoLinkProLogo(height: logoHeight),
        SizedBox(height: compact ? 18 : 22),
        Text(
          _mode == _AuthMode.login
              ? 'Ingrese a su cuenta'
              : 'Cree su cuenta B2B',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: 'Correo electrónico',
              prefixIcon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: _mode == _AuthMode.login
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            textInputAction: _mode == _AuthMode.login
                ? TextInputAction.done
                : TextInputAction.next,
            onSubmitted: _mode == _AuthMode.login && !_isLoading ? (_) => _login() : null,
            decoration: _inputDecoration(
              hint: 'Contraseña',
              prefixIcon: Icons.lock_outlined,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          if (_mode == _AuthMode.register) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: 'Confirmar contraseña',
                prefixIcon: Icons.lock_outlined,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _referralController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: !_isLoading ? (_) => _register() : null,
              decoration: _inputDecoration(
                hint: 'Código de vendedor / referido (opcional)',
                prefixIcon: Icons.qr_code_2_outlined,
                suffixIcon: IconButton(
                  tooltip: 'Escanear QR',
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final code = await ReferralQrScanSheet.scan(context);
                          if (!mounted || code == null) return;
                          setState(() {
                            _referralController.text = code;
                          });
                        },
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                if (_mode == _AuthMode.login) {
                  _login();
                } else {
                  _register();
                }
              },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                _mode == _AuthMode.login ? 'Iniciar sesión' : 'Crear cuenta',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        if (_mode == _AuthMode.login) ...[
          TextButton(
            onPressed: _isLoading ? null : _showForgotPasswordDialog,
            child: Text(
              '¿Olvidó su contraseña?',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        _mode == _AuthMode.login
            ? Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '¿No tiene cuenta? ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _mode = _AuthMode.register),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Regístrese',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              )
            : Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '¿Ya tiene cuenta? ',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _mode = _AuthMode.login),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Inicie sesión',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => openPublicLegal(context, PublicLegalKind.terms),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Términos',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '·',
              style: TextStyle(color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: () =>
                  openPublicLegal(context, PublicLegalKind.privacy),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Privacidad',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthCard({required bool showHeader}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.surfaceTinted : AppColors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader) ...[
                // Desktop: logo va en el panel izquierdo; aquí solo el subtítulo.
                Text(
                  _mode == _AuthMode.login
                      ? 'Ingrese a su cuenta'
                      : 'Cree su cuenta B2B',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 28),
              ],
              _buildFormFields(),
              const SizedBox(height: 24),
              _buildPrimaryButton(),
              const SizedBox(height: 8),
              _buildFooterLinks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingPanel() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.black,
            AppColors.brandBlue,
            AppColors.brandAccent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MotoLinkProLogo(height: 64, forceWhite: true),
              const SizedBox(height: 28),
              const Text(
                'Marketplace B2B\npara repuestos',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Conecte importadores y aliados en un solo lugar: '
                'catálogo, pedidos, reputación y operaciones.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: AppColors.white.withOpacity(0.88),
                ),
              ),
              const SizedBox(height: 32),
              const _BrandingBullet(
                icon: Icons.inventory_2_outlined,
                label: 'Inventario y catálogo centralizado',
              ),
              const SizedBox(height: 12),
              const _BrandingBullet(
                icon: Icons.local_shipping_outlined,
                label: 'Seguimiento de encomiendas en tiempo real',
              ),
              const SizedBox(height: 12),
              const _BrandingBullet(
                icon: Icons.verified_user_outlined,
                label: 'KYC y operaciones seguras',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= AppBreakpoints.authDesktop;

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _buildBrandingPanel()),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppBreakpoints.authFormMaxWidth,
                            ),
                            child: _buildAuthCard(showHeader: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.authFormMaxWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAuthHeader(compact: false),
                        const SizedBox(height: 28),
                        _buildAuthCard(showHeader: false),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: const ThemeModeBubble(compact: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandingBullet extends StatelessWidget {
  const _BrandingBullet({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ),
      ],
    );
  }
}

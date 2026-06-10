import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_scaffold_messenger.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/login_forgot_password_dialog.dart';
import '../widgets/motolink_pro_logo.dart';

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      final res = await AuthService.signUpWithPassword(
        email: email,
        password: password,
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
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandOrange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: MotoLinkProLogo(height: MotoLinkProLogoHeights.login),
              ),
              const SizedBox(height: 20),
              const Text(
                'MotoLink',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == _AuthMode.login
                    ? 'Ingrese a su cuenta'
                    : 'Cree su cuenta B2B',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
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
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_mode == _AuthMode.login) {
                          _login();
                        } else {
                          _register();
                        }
                      },
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
                        _mode == _AuthMode.login
                            ? 'Iniciar Sesión'
                            : 'Crear Cuenta',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              if (_mode == _AuthMode.login) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: const Text(
                      '¿Olvidó su contraseña?',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Center(
                child: _mode == _AuthMode.login
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            '¿No tiene cuenta? ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(
                                    () => _mode = _AuthMode.register,
                                  ),
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
                          const Text(
                            '¿Ya tiene cuenta? ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(
                                    () => _mode = _AuthMode.login,
                                  ),
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
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

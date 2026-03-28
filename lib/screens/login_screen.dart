import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

const _kCorporateRed = Color(0xFFE31B23);

enum _AuthMode { login, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
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
    final ctrl = TextEditingController(text: _emailController.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kCorporateRed),
              onPressed: () async {
                final e = ctrl.text.trim();
                if (e.isEmpty || !_validateEmail(e)) {
                  Navigator.of(ctx).pop();
                  _showSnackBar('Introduce un correo válido.', isError: true);
                  return;
                }
                try {
                  await AuthService.resetPasswordForEmail(e);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    _showSnackBar(
                      'Si existe una cuenta con ese correo, recibirás un enlace para restablecer la contraseña.',
                      isError: false,
                    );
                  }
                } on AuthException catch (ex) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _showSnackBar(
                    AuthService.mapAuthErrorMessage(ex.message),
                    isError: true,
                  );
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Image.asset(
                'assets/logo_motoboxes.png',
                width: 180,
                height: 180,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.motorcycle,
                    size: 100,
                    color: Colors.black),
              ),
              const SizedBox(height: 36),
              const Text(
                'MotoLink Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == _AuthMode.login
                    ? 'Inicia sesión para continuar'
                    : 'Crea tu cuenta B2B',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 28),
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(
                    value: _AuthMode.login,
                    label: Text('Entrar'),
                    icon: Icon(Icons.login, size: 18),
                  ),
                  ButtonSegment(
                    value: _AuthMode.register,
                    label: Text('Registrarse'),
                    icon: Icon(Icons.person_add_outlined, size: 18),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _isLoading
                    ? null
                    : (Set<_AuthMode> next) {
                        setState(() {
                          _mode = next.first;
                        });
                      },
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: inputDecoration.copyWith(
                  labelText: 'Correo',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: _mode == _AuthMode.login
                    ? const [AutofillHints.password]
                    : const [AutofillHints.newPassword],
                decoration: inputDecoration.copyWith(
                  labelText: _mode == _AuthMode.login
                      ? 'Contraseña'
                      : 'Contraseña (mín. 6 caracteres)',
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              if (_mode == _AuthMode.register) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: inputDecoration.copyWith(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
              if (_mode == _AuthMode.login) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
              ] else
                const SizedBox(height: 8),
              const SizedBox(height: 16),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCorporateRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        _mode == _AuthMode.login ? 'INGRESAR' : 'CREAR CUENTA',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordDialogResult {
  const ForgotPasswordDialogResult({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;
}

/// Diálogo de recuperación de contraseña (controllers en el State, sin SnackBar interno).
Future<ForgotPasswordDialogResult?> showLoginForgotPasswordDialog(
  BuildContext context, {
  String initialEmail = '',
}) {
  return showDialog<ForgotPasswordDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _LoginForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _LoginForgotPasswordDialog extends StatefulWidget {
  const _LoginForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_LoginForgotPasswordDialog> createState() =>
      _LoginForgotPasswordDialogState();
}

class _LoginForgotPasswordDialogState extends State<_LoginForgotPasswordDialog> {
  late final TextEditingController _emailController;
  String? _inlineError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_validateEmail(email)) {
      setState(() => _inlineError = 'Introduce un correo válido.');
      return;
    }

    setState(() {
      _inlineError = null;
      _busy = true;
    });

    try {
      await AuthService.resetPasswordForEmail(email);
      if (!mounted) return;
      Navigator.of(context).pop(
        const ForgotPasswordDialogResult(
          message:
              'Si existe una cuenta con ese correo, recibirás un enlace para '
              'restablecer la contraseña. Ábrelo en el mismo navegador donde '
              'lo solicitaste.',
          isError: false,
        ),
      );
    } on AuthException catch (ex) {
      if (!mounted) return;
      Navigator.of(context).pop(
        ForgotPasswordDialogResult(
          message: AuthService.mapAuthErrorMessage(ex.message),
          isError: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(
        const ForgotPasswordDialogResult(
          message: 'No se pudo enviar el correo de recuperación.',
          isError: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Recuperar contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Correo',
              border: OutlineInputBorder(),
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 8),
            Text(
              _inlineError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
